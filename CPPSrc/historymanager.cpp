#include "historymanager.h"
#include "PlaylistCacheStore.h"
#include "usermanager.h"

#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QList>
#include <QUrl>
#include <QUrlQuery>

namespace
{
const char *const kApiRoot = "https://xjt-togethertracks.top/api";

QString secondsToMinutesSeconds(int seconds)
{
    if (seconds <= 0)
        return QStringLiteral("--:--");
    const int m = seconds / 60;
    const int s = seconds % 60;
    return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
}
} // namespace

HistoryManager::HistoryManager(QObject *parent) : QObject(parent)
{
    connect(&m_privilegeRequester, &HttpGetRequester::dataReceived, this, &HistoryManager::onPrivilegeData);
    connect(&m_historyRequester, &HttpGetRequester::dataReceived, this, &HistoryManager::onPlayhistoryData);
    connect(&m_uploadRequester, &HttpGetRequester::dataReceived, this, &HistoryManager::onUploadDone);

    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_privilegeRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_privilegeRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_historyRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_historyRequester, &HttpGetRequester::requestTimeout, this, timeout);

    // 播放后 8 秒批量处理队列（避免切歌瞬间连发请求）
    m_flushTimer.setSingleShot(true);
    m_flushTimer.setInterval(8000);
    connect(&m_flushTimer, &QTimer::timeout, this, &HistoryManager::flushQueue);

    // 启动即加载本地缓存：听歌历史页点进去前先展示，再同步云端
    loadHistoryFromCache();
}

void HistoryManager::setUserManager(UserManager *um)
{
    m_userManager = um;
}

// 拼接 userid+token 鉴权参数：酷狗历史接口强制鉴权，不带会返回 error_code:20010
QString HistoryManager::authQuery() const
{
    if (!m_userManager)
        return QString();
    QUrlQuery q;
    if (!m_userManager->userid().isEmpty())
        q.addQueryItem("userid", m_userManager->userid());
    if (!m_userManager->token().isEmpty())
        q.addQueryItem("token", m_userManager->token());
    return q.isEmpty() ? QString() : q.toString();
}

void HistoryManager::reportPlayed(const QString &title, const QString &hash)
{
    Q_UNUSED(title)
    if (hash.isEmpty())
        return;
    const QString upperHash = hash.toUpper();
    // 30 秒窗口内同歌不重复上报：单曲循环每圈间隔 >30s 可再报，实现播放次数累加
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    const qint64 last = m_lastReport.value(upperHash, 0);
    if (now - last < 30)
        return;
    m_lastReport[upperHash] = now;
    m_sessionCount[upperHash] = m_sessionCount.value(upperHash, 0) + 1;  // 本次会话该歌播放次数

    QVariantMap song;
    song["hash"] = upperHash;
    // 记录真实播放开始时间（批量上传时每首歌保持各自的播放时刻，而不是统一用上传时刻）
    song["time"] = QDateTime::currentSecsSinceEpoch();
    m_pending.append(song);
    m_flushTimer.start();
}

void HistoryManager::fetchHistory()
{
    if (m_isLoading)
        return;
    m_isLoading = true;
    emit isLoadingChanged();
    m_playSongs.clear();
    m_bpList.clear();
    m_total = 0;
    m_loadedPages = 0;
    m_loadingMore = false;
    m_hasMore = false;
    // playhistory 接口顺序乱序（酷狗不保证时间序），需全量拉取后按 ot 倒序排序；
    // 全量仅存内存（约 1MB），展示按批追加（首屏 100 首，下拉从内存秒加载）
    fetchPlayhistoryPage(QStringLiteral("0"));
}

// 下拉加载更多：从已排序的全量内存数据取下一批（无网络请求）
void HistoryManager::fetchMoreHistory()
{
    if (m_isLoading || m_loadedPages >= m_loadedTotalPages())
        return;
    const int start = m_playSongs.size();
    const QVariantList batch = m_history.mid(start, kPageSize);
    if (batch.isEmpty())
        return;
    m_playSongs.append(batch);
    m_loadedPages = m_playSongs.size() / kPageSize;
    m_hasMore = m_playSongs.size() < m_history.size();
    emit historyAppended(batch);
    emit historyChanged();
}

int HistoryManager::m_loadedTotalPages() const
{
    return (m_history.size() + kPageSize - 1) / kPageSize;
}

void HistoryManager::fetchPlayhistoryPage(const QString &bp)
{
    QString url = QStringLiteral("%1/user/history?bp=%2").arg(kApiRoot).arg(bp);
    const QString auth = authQuery();
    if (!auth.isEmpty())
        url += "&" + auth;
    m_historyRequester.fetchData(url);
}

void HistoryManager::flushQueue()
{
    if (m_pending.isEmpty() || m_uploadWorking)
        return;
    // pc 基线缓存未就绪：先拉 playhistory 全量（构建 mxid→pc 缓存）再上传。
    // pc 是覆盖语义，不先取基线会把云端已有次数清零（如溯流光 38→3 事故）
    if (!m_pcReady)
    {
        fetchHistory();
        return;
    }
    // 批量用 hash 查 album_audio_id（mxid）：privilege/lite 支持逗号分隔多 hash，
    // 一次请求解析全部，比逐首按歌名搜索更准（不会因版本不同而 hash 对不上）
    QStringList hashes;
    for (const QVariant &v : m_pending)
    {
        const QString h = v.toMap()["hash"].toString();
        if (!h.isEmpty())
            hashes << h;
    }
    if (hashes.isEmpty())
    {
        m_pending.clear();
        return;
    }
    QString url = QStringLiteral("%1/privilege/lite?hash=%2").arg(kApiRoot).arg(hashes.join(","));
    const QString auth = authQuery();
    if (!auth.isEmpty())
        url += "&" + auth;
    m_privilegeRequester.fetchData(url);
}

// privilege/lite 响应：data[] 每项 {hash, album_audio_id}，匹配回 pending 攒批上传
void HistoryManager::onPrivilegeData(const QByteArray &data)
{
    QHash<QString, QString> hashToMxid;
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error == QJsonParseError::NoError && doc.isObject())
    {
        const QJsonArray arr = doc.object()["data"].toArray();
        for (const QJsonValue &v : arr)
        {
            const QJsonObject o = v.toObject();
            const QString h     = o["hash"].toString().toUpper();
            const QString mxid  = QString::number(o["album_audio_id"].toVariant().toLongLong());
            if (!h.isEmpty() && o["album_audio_id"].toVariant().toLongLong() > 0)
                hashToMxid[h] = mxid;
        }
    }

    QVariantList batch;
    for (const QVariant &v : m_pending)
    {
        const QVariantMap s = v.toMap();
        const QString hash  = s["hash"].toString();
        const QString mxid  = hashToMxid.value(hash);
        if (!mxid.isEmpty())
        {
            QVariantMap b;
            b["mxid"]    = mxid;
            b["time"]    = s["time"];
            b["hash"]    = hash;   // 酷狗记录新歌历史必须带 hash（小写），否则不写入
            b["session"] = m_sessionCount.value(hash, 1);  // 本次会话该歌播放次数
            batch.append(b);
        }
    }
    m_pending.clear();
    if (!batch.isEmpty())
        doUpload(batch);
}

void HistoryManager::doUpload(const QVariantList &songs)
{
    m_uploadWorking = true;
    emit uploadWorkingChanged();

    // 批量上传：{songs: [{mxid, time(→ot 播放时间戳), pc, hash]}]
    // 路由是 /playhistory/upload（不是 /user/history/upload —— 那个是查询接口，会静默假成功）。
    // pc = 云端基线 + 本次会话播放次数（覆盖语义，先取基线再覆盖，避免清零已有次数）
    QJsonArray arr;
    for (const QVariant &v : songs)
    {
        const QVariantMap m = v.toMap();
        const qint64 mxid   = m["mxid"].toLongLong();
        const int session   = m["session"].toInt();
        const int pc        = m_pcCache.value(mxid, 0) + session;
        QJsonObject o;
        o["mxid"] = mxid;
        o["time"] = m["time"].toLongLong();
        o["pc"]   = pc;
        const QString hash = m["hash"].toString();
        if (!hash.isEmpty())
            o["hash"] = hash.toLower();
        arr.append(o);
        m_pcCache[mxid] = pc;  // 本地基线同步，后续上报在本次基础上累加
    }
    QUrl url(QStringLiteral("%1/playhistory/upload").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("songs", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    // 上传同样需要 userid+token 鉴权，否则上报到空账户
    if (m_userManager)
    {
        if (!m_userManager->userid().isEmpty())
            query.addQueryItem("userid", m_userManager->userid());
        if (!m_userManager->token().isEmpty())
            query.addQueryItem("token", m_userManager->token());
    }
    url.setQuery(query);
    m_uploadRequester.fetchData(url.toString());
}

// playhistory 响应：data.songs[]（info 嵌套），has_more + bp 游标链式翻页
// 全量拉取（构建 pc 基线缓存）→ 按 ot 倒序排序 → 展示前 100 首，下拉从内存取下一批
void HistoryManager::onPlayhistoryData(const QByteArray &data)
{
    bool hasMore = false;
    QString nextBp;
    QVariantList songs;
    if (!parsePlayhistoryData(data, songs, hasMore, nextBp))
    {
        m_isLoading = false;
        m_loadingMore = false;
        emit isLoadingChanged();
        return;
    }
    m_playSongs.append(songs);   // 全量累积（含 ot，稍后排序）
    if (hasMore && !nextBp.isEmpty())
    {
        fetchPlayhistoryPage(nextBp);
        return;
    }
    // 全量拉完：按 ot（播放时间）倒序排序，接口顺序是乱序的
    std::sort(m_playSongs.begin(), m_playSongs.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["ot"].toLongLong() > b.toMap()["ot"].toLongLong();
    });
    m_isLoading = false;
    emit isLoadingChanged();
    m_history = m_playSongs;
    m_total = m_playSongs.size();
    m_pcReady = true;   // pc 基线缓存随翻页构建完毕
    // 展示第一批（前 100 首）
    m_loadedPages = 1;
    const QVariantList firstBatch = m_history.mid(0, kPageSize);
    m_playSongs = firstBatch;
    m_hasMore = m_history.size() > kPageSize;
    if (!firstBatch.isEmpty())
        saveHistoryToCache();
    emit historyReset(firstBatch);
    emit totalChanged();
    emit historyChanged();
    // pc 基线就绪后，补发之前因未就绪而挂起的上报队列
    if (!m_pending.isEmpty() && !m_uploadWorking)
        flushQueue();
}

// 解析 playhistory 响应（data.songs[]，info 嵌套），填 outSongs；失败返回 false
bool HistoryManager::parsePlayhistoryData(const QByteArray &data, QVariantList &outSongs, bool &hasMore, QString &nextBp)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[HistoryManager] playhistory parse error:" << perr.errorString();
        return false;
    }
    const QJsonObject dataObj = doc.object()["data"].toObject();
    hasMore = dataObj["has_more"].toInt() > 0;
    nextBp  = dataObj["bp"].toString();
    m_hasMore = hasMore;

    QVariantList songs;
    for (const QJsonValue &val : dataObj["songs"].toArray())
    {
        const QJsonObject o    = val.toObject();
        const QJsonObject info = o["info"].toObject();
        const qint64 mxid      = o["mxid"].toVariant().toLongLong();
        const int pc           = o["pc"].toInt();
        // 构建 mxid→pc 基线缓存（上传前必须就绪，pc 覆盖语义防清零）
        if (mxid > 0)
            m_pcCache[mxid] = pc;
        QVariantMap s;
        s["songname"]    = info["name"].toString();
        s["singername"]  = info["singername"].toString();
        s["songhash"]    = info["hash"].toString();
        s["album_name"]  = info["albuminfo"].toObject()["name"].toString();
        s["duration"]    = secondsToMinutesSeconds(info["timelen"].toInt() / 1000);
        QString cover    = info["cover"].toString();
        cover.replace(QStringLiteral("{size}"), QStringLiteral("400"));
        s["union_cover"] = cover;
        s["play_count"]  = pc;
        s["ot"]          = o["ot"].toVariant().toLongLong();  // 播放时间戳（客户端按 ot 倒序排序）
        songs.append(s);
    }
    outSongs = songs;
    return true;
}

// playhistory upload 响应：忽略内容，仅复位上传状态
void HistoryManager::onUploadDone(const QByteArray &)
{
    if (m_uploadWorking)
    {
        m_uploadWorking = false;
        emit uploadWorkingChanged();
    }
}

// ── 本地缓存：启动时先展示缓存，点进去同步云端后覆盖 ──

void HistoryManager::loadHistoryFromCache()
{
    QFile file(PlaylistCacheStore::cacheDir() + "/history_cache.json");
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    if (!doc.isArray())
        return;
    QVariantList songs;
    for (const QJsonValue &v : doc.array())
    {
        const QJsonObject o = v.toObject();
        QVariantMap s;
        s["songname"]    = o["songname"].toString();
        s["singername"]  = o["singername"].toString();
        s["songhash"]    = o["songhash"].toString();
        s["album_name"]  = o["album_name"].toString();
        s["duration"]    = o["duration"].toString();
        s["union_cover"] = o["union_cover"].toString();
        s["play_count"]  = o["play_count"].toInt();
        songs.append(s);
    }
    if (!songs.isEmpty())
    {
        m_history = songs;
        emit historyChanged();
    }
}

void HistoryManager::saveHistoryToCache()
{
    PlaylistCacheStore::ensureCacheDir();
    QJsonArray arr;
    for (const QVariant &v : m_history)
    {
        const QVariantMap s = v.toMap();
        QJsonObject o;
        o["songname"]    = s["songname"].toString();
        o["singername"]  = s["singername"].toString();
        o["songhash"]    = s["songhash"].toString();
        o["album_name"]  = s["album_name"].toString();
        o["duration"]    = s["duration"].toString();
        o["union_cover"] = s["union_cover"].toString();
        o["play_count"]  = s["play_count"].toInt();
        arr.append(o);
    }
    QFile file(PlaylistCacheStore::cacheDir() + "/history_cache.json");
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
        file.close();
    }
}

void HistoryManager::onFailed(const QString &err)
{
    qWarning() << "[HistoryManager] request error:" << err;
    // privilege 批量查询失败：清空队列（下次播放重新攒），不逐个重试
    m_pending.clear();
    if (m_isLoading)
    {
        m_isLoading = false;
        emit isLoadingChanged();
    }
    m_loadingMore = false;
    if (m_uploadWorking)
    {
        m_uploadWorking = false;
        emit uploadWorkingChanged();
    }
}
