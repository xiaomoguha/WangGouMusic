#include "historymanager.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRegularExpression>
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
    connect(&m_searchRequester, &HttpGetRequester::dataReceived, this, &HistoryManager::onSearchData);
    connect(&m_historyRequester, &HttpGetRequester::dataReceived, this, &HistoryManager::onHistoryData);

    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_searchRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_searchRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_historyRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_historyRequester, &HttpGetRequester::requestTimeout, this, timeout);

    // 停止播放后 8 秒批量处理队列（避免切歌瞬间连发请求）
    m_flushTimer.setSingleShot(true);
    m_flushTimer.setInterval(8000);
    connect(&m_flushTimer, &QTimer::timeout, this, &HistoryManager::flushQueue);
}

void HistoryManager::reportPlayed(const QString &title, const QString &hash)
{
    if (title.isEmpty() || hash.isEmpty())
        return;
    // 同一首歌只上报一次（本次会话）
    for (const QVariant &v : m_pending)
        if (v.toMap()["hash"] == hash)
            return;
    for (const QVariant &v : m_uploadBatch)
        if (v.toMap()["hash"] == hash)
            return;

    QVariantMap song;
    song["title"] = title;
    song["hash"]  = hash.toUpper();
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
    m_page = 0;
    m_hasMore = false;
    m_historyRequester.fetchData(QStringLiteral("%1/user/history?bp=0").arg(kApiRoot));
}

void HistoryManager::fetchMoreHistory()
{
    if (m_isLoading || !m_hasMore)
        return;
    m_isLoading = true;
    emit isLoadingChanged();
    m_historyRequester.fetchData(QStringLiteral("%1/user/history?bp=%2").arg(kApiRoot).arg(m_page));
}

void HistoryManager::flushQueue()
{
    if (m_pending.isEmpty() || m_uploadWorking)
        return;
    processQueue();
}

// 逐个解析 mxid：取队首 → 按歌名搜索 → hash 匹配 album_audio_id → 攒批 → 下一首
void HistoryManager::processQueue()
{
    if (m_pending.isEmpty())
    {
        // 全部解析完：批量上传
        if (!m_uploadBatch.isEmpty())
            doUpload(m_uploadBatch);
        return;
    }

    const QVariantMap song = m_pending.first().toMap();
    m_searchHash = song["hash"].toString();

    QString keyword = song["title"].toString();
    keyword.replace(QRegularExpression(QStringLiteral(R"(\s*\([^)]*\)\s*$)")), QString());
    QUrl url(QStringLiteral("%1/search").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("keywords", keyword);
    query.addQueryItem("page", "1");
    query.addQueryItem("pagesize", "10");
    url.setQuery(query);
    m_searchRequester.fetchData(url.toString());
}

void HistoryManager::onSearchData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error == QJsonParseError::NoError && doc.isObject())
    {
        const QJsonArray songs = doc.object()["data"].toObject()["info"].toArray();
        QString mxid;
        for (const QJsonValue &val : songs)
        {
            const QJsonObject s  = val.toObject();
            const QString    h   = s["hash"].toString().toUpper();
            const int        aid = s["album_audio_id"].toInt();
            if (aid <= 0)
                continue;
            if (h == m_searchHash)
            {
                mxid = QString::number(aid);
                break;
            }
        }
        if (!mxid.isEmpty())
        {
            QVariantMap song = m_pending.first().toMap();
            song["mxid"] = mxid;
            m_uploadBatch.append(song);
        }
    }

    if (!m_pending.isEmpty())
        m_pending.removeFirst();
    processQueue();
}

void HistoryManager::doUpload(const QVariantList &songs)
{
    m_uploadWorking = true;
    emit uploadWorkingChanged();

    // 批量上传：{songs: [{mxid, time(→ot 播放时间戳), pc(播放次数)]}
    QJsonArray arr;
    for (const QVariant &v : songs)
    {
        QJsonObject o;
        o["mxid"] = v.toMap()["mxid"].toInt();
        o["time"] = v.toMap()["time"].toLongLong();
        o["pc"]   = 1;
        arr.append(o);
    }
    QUrl url(QStringLiteral("%1/user/history/upload").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("songs", QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    url.setQuery(query);
    m_uploadRequester.fetchData(url.toString());

    m_uploadBatch.clear();
}

void HistoryManager::onHistoryData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    m_isLoading = false;
    emit isLoadingChanged();
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[HistoryManager] history parse error:" << perr.errorString();
        return;
    }
    const QJsonObject root  = doc.object();
    const QJsonArray  list  = root["list"].toArray();
    const int         total = root["total"].toInt(0);

    QVariantList songs;
    for (const QJsonValue &val : list)
    {
        const QJsonObject o = val.toObject();
        QVariantMap s;
        s["songname"]   = o["songname"].toString();
        s["singername"] = o["singername"].toString();
        s["songhash"]   = o["hash"].toString();
        s["album_name"] = o["album_name"].toString();
        s["duration"]   = secondsToMinutesSeconds(o["duration"].toInt());
        s["union_cover"] = o["cover"].toString();
        s["play_count"] = o["play_count"].toInt();
        songs.append(s);
    }

    if (m_page == 0)
        m_history = songs;
    else
        m_history.append(songs);

    m_hasMore = m_history.size() < total;
    if (m_hasMore)
        m_page++;   // 酷狗 bp 分页：下一批
    emit historyChanged();
}

void HistoryManager::onFailed(const QString &err)
{
    qWarning() << "[HistoryManager] request error:" << err;
    // 搜索失败：跳过当前歌曲继续处理
    if (!m_pending.isEmpty())
    {
        m_pending.removeFirst();
        processQueue();
    }
    if (m_isLoading)
    {
        m_isLoading = false;
        emit isLoadingChanged();
    }
    if (m_uploadWorking)
    {
        m_uploadWorking = false;
        emit uploadWorkingChanged();
    }
}
