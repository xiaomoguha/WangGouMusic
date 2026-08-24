#include "playlistcollection.h"
#include "ApiClient.h"
#include "PlaylistCacheStore.h"
#include "usermanager.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QUrlQuery>

static const QString API_BASE = "https://api.special520.com";

PlaylistCollection::PlaylistCollection(QObject *parent) : QObject(parent)
{
    connect(&m_favRequester, &HttpGetRequester::dataReceived, this, &PlaylistCollection::onFavoriteHashesData);
    connect(&m_favRequester, &HttpGetRequester::requestFailed, this, [](const QString &) {});
    connect(&m_favRequester, &HttpGetRequester::requestTimeout, this, []() {});
    // 启动即从缓存恢复红心（无需等网络），网络刷新成功后更新
    loadFavoriteHashesFromCache();
}

void PlaylistCollection::setUserManager(UserManager *um)
{
    m_userManager = um;
    if (um)
    {
        // 红心缓存未命中 → 现场拉歌单列表 → 到达后（缓存已落盘）自动重试一次
        connect(um, &UserManager::userPlaylistReceived, this, &PlaylistCollection::onUserPlaylistsForRetry);
    }
}

bool PlaylistCollection::findFavorite(QString &listid, QString &gid, const QVariantList &freshPlaylists) const
{
    if (!m_userManager)
        return false;
    // 优先用调用方带来的现场数据（重试路径：接口刚返回的歌单列表，缓存文件可能
    // 没写成功或陈旧）；否则退回缓存文件 {data: {info: [...]}}（兼容无 data 包裹）
    QVariantList infos = freshPlaylists;
    if (infos.isEmpty())
    {
        const QVariantMap cached = m_userManager->loadCachedPlaylists();
        infos = cached["data"].toMap()["info"].toList();
        if (infos.isEmpty())
            return false;
    }
    const QString uid        = m_userManager->userid();
    const QString gidFav     = QStringLiteral("collection_3_%1_2_0").arg(uid);  // 「我喜欢」系统位
    const QString gidDefault = QStringLiteral("collection_3_%1_1_0").arg(uid);  // 「默认收藏」系统位（老账号）
    // 多级匹配：精确名 → 系统 gid → 包含名 → 默认收藏 gid → 默认收藏名。
    // 顺序保证用户自建的「我喜欢的XX」不会被排在真「我喜欢」前面。
    for (int pass = 0; pass < 5; ++pass)
    {
        for (const QVariant &v : infos)
        {
            const QVariantMap p    = v.toMap();
            const QString    name  = p["name"].toString();
            const QString    g     = p["global_collection_id"].toString();
            const QString    l     = p["listid"].toString();
            bool hit = false;
            switch (pass)
            {
            case 0: hit = (name == QStringLiteral("我喜欢")); break;
            case 1: hit = (g == gidFav); break;
            case 2: hit = name.contains(QStringLiteral("我喜欢")); break;
            case 3: hit = (g == gidDefault); break;
            case 4: hit = name.contains(QStringLiteral("默认收藏")); break;
            }
            if (hit && !l.isEmpty())
            {
                listid = l;
                gid    = g;
                return true;
            }
        }
    }
    return false;
}

void PlaylistCollection::onUserPlaylistsForRetry(const QVariantMap &data)
{
    if (!m_favRetryPending)
        return;
    const QString name = m_favPendingName, hash = m_favPendingHash, singer = m_favPendingSinger;
    m_favPendingName.clear();
    m_favPendingHash.clear();
    m_favPendingSinger.clear();
    // 直接用本次响应里的歌单列表重试（缓存文件可能没写成功/陈旧，读它会一直 miss）
    const QVariantList fresh = data.value("data").toMap().value("info").toList();
    // 注意：m_favRetryPending 故意在这一轮保持 true——重试的 addToFavorite 若仍然
    // 找不到「我喜欢」就不会再发起拉取（否则 fetch→信号→addToFavorite→fetch 死循环，
    // 曾把服务器打出每秒十几个 /user/playlist）。本轮结束才清标志，下次点击可再重试。
    addToFavorite(name, hash, singer, fresh);
    m_favRetryPending = false;
}

QVariantList PlaylistCollection::favoriteHashes() const
{
    QVariantList list;
    list.reserve(m_favoriteHashes.size());
    for (const QString &h : m_favoriteHashes)
        list << h;
    return list;
}

void PlaylistCollection::setWorking(bool working)
{
    if (m_isWorking != working)
    {
        m_isWorking = working;
        emit isWorkingChanged();
    }
}

QString PlaylistCollection::createUserIdFromGid(const QString &gid)
{
    // collection_3_1439409719_4_0 → [collection,3,1439409719,4,0]
    const QStringList parts = gid.split('_');
    return parts.size() >= 3 ? parts.at(2) : QString();
}

QString PlaylistCollection::createListIdFromGid(const QString &gid)
{
    const QStringList parts = gid.split('_');
    return parts.size() >= 4 ? parts.at(3) : QString();
}

void PlaylistCollection::postForm(
    const QString &path, const QList<QPair<QString, QString>> &params, std::function<void(QJsonObject)> onSuccess,
    std::function<void(QString, int)> onError, int timeoutMs
)
{
    QUrlQuery query;
    // 统一注入登录态（cloudlist 接口必须显式传 token + userid）
    if (m_userManager)
    {
        query.addQueryItem("token", m_userManager->token());
        query.addQueryItem("userid", m_userManager->userid());
    }
    for (const auto &p : params)
    {
        query.addQueryItem(p.first, p.second);
    }
    const QJsonObject body; // 空 body，参数全部走 query（与 UserManager::postForm 一致）
    const QString url = API_BASE + path + "?" + query.toString();
    ApiClient::instance().postJson(url, body, std::move(onSuccess), std::move(onError), timeoutMs);
}

void PlaylistCollection::parseResult(QJsonObject root, const QString &successMsg)
{
    setWorking(false);
    const int status  = root["status"].toInt();
    const int errCode = root["error_code"].toInt();
    if (status == 1 || errCode == 0)
    {
        emit operationFinished(true, successMsg);
    }
    else
    {
        QString msg = root["message"].toString();
        if (msg.isEmpty())
            msg = root["errmsg"].toString();
        if (msg.isEmpty())
            msg = QString("操作失败 (错误码: %1)").arg(errCode);
        emit operationFinished(false, msg);
    }
}

void PlaylistCollection::collectPlaylist(
    const QString &name, const QString &createUserid, const QString &createListid, const QString &createGid
)
{
    if (name.isEmpty() || createGid.isEmpty())
    {
        emit operationFinished(false, "歌单信息不完整");
        return;
    }
    setWorking(true);
    postForm(
        "/playlist/add",
        {
            {"type", "1"}, // 1 = 收藏他人歌单
            {"name", name},
            {"list_create_userid", createUserid},
            {"list_create_listid", createListid},
            {"list_create_gid", createGid},
        },
        [this, name](QJsonObject root) { parseResult(root, "已收藏歌单: " + name); },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}

void PlaylistCollection::uncollectPlaylist(const QString &listid)
{
    if (listid.isEmpty())
    {
        emit operationFinished(false, "歌单信息不完整");
        return;
    }
    setWorking(true);
    postForm(
        "/playlist/del", {{"listid", listid}},
        [this](QJsonObject root) { parseResult(root, "已取消收藏"); },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}

void PlaylistCollection::createPlaylist(const QString &name)
{
    if (name.trimmed().isEmpty())
    {
        emit operationFinished(false, "歌单名不能为空");
        return;
    }
    setWorking(true);
    postForm(
        "/playlist/add", {{"type", "0"}, {"name", name.trimmed()}},
        [this, name](QJsonObject root)
        {
            setWorking(false);
            const int status  = root["status"].toInt();
            const int errCode = root["error_code"].toInt();
            if (status == 1 || errCode == 0)
            {
                emit operationFinished(true, "已创建歌单: " + name.trimmed());
            }
            else
            {
                QString msg = root["message"].toString();
                if (msg.isEmpty())
                    msg = QString("创建失败 (错误码: %1)").arg(errCode);
                emit operationFinished(false, msg);
            }
        },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}

void PlaylistCollection::addTracks(const QString &listid, const QVariantList &songs, const QString &successMsg)
{
    if (listid.isEmpty() || songs.isEmpty())
    {
        emit operationFinished(false, "歌单或歌曲信息不完整");
        return;
    }
    // 拼 data：name|hash[|album_id][|mixsongid]，逗号分隔多首；可选段缺失时省略
    QStringList parts;
    for (const QVariant &v : songs)
    {
        const QVariantMap s  = v.toMap();
        const QString name   = s["songname"].toString();
        const QString hash   = s["songhash"].toString();
        if (name.isEmpty() || hash.isEmpty())
            continue;
        QString part = name + "|" + hash;
        const QString albumId = s["album_id"].toString();
        const QString mixsong = s["mixsongid"].toString();
        if (!albumId.isEmpty())
            part += "|" + albumId;
        if (!mixsong.isEmpty())
            part += "|" + mixsong;
        parts << part;
    }
    if (parts.isEmpty())
    {
        emit operationFinished(false, "歌曲信息不完整");
        return;
    }
    setWorking(true);
    postForm(
        "/playlist/tracks/add", {{"listid", listid}, {"data", parts.join(',')}},
        [this, successMsg](QJsonObject root)
        { parseResult(root, successMsg.isEmpty() ? QStringLiteral("已添加到歌单") : successMsg); },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}

void PlaylistCollection::addToFavorite(
    const QString &songname, const QString &songhash, const QString &singername, const QVariantList &freshPlaylists
)
{
    if (songname.isEmpty() || songhash.isEmpty())
    {
        emit operationFinished(false, "当前歌曲信息不完整");
        return;
    }
    // 「我喜欢」定位：多级匹配（名字/系统 gid/默认收藏兜底），见 findFavorite
    QString listid, gid;
    if (!findFavorite(listid, gid, freshPlaylists))
    {
        // 缓存里没有：登录状态下现场拉一次歌单列表，到达后自动重试本方法（防循环只试一轮）
        if (m_userManager && m_userManager->isLoggedIn() && !m_favRetryPending)
        {
            m_favRetryPending  = true;
            m_favPendingName   = songname;
            m_favPendingHash   = songhash;
            m_favPendingSinger = singername;
            m_userManager->fetchUserPlaylist(1, 50);
            return;
        }
        emit operationFinished(false, "未找到「我喜欢」歌单，请先刷新歌单");
        return;
    }

    QVariantMap song;
    song["songname"]   = songname;
    song["songhash"]   = songhash;
    song["singername"] = singername;
    QVariantList songs;
    songs.append(song);
    // 专属成功文案（弹「已添加到我喜欢」弹窗，与加入一起听同款）：带歌名，超长截断
    QString display = songname;
    if (display.size() > 18)
        display = display.left(18) + QStringLiteral("…");
    addTracks(listid, songs, QStringLiteral("已添加到我喜欢 ♥ ") + display);
}

void PlaylistCollection::refreshFavoriteHashes()
{
    // 找「我喜欢」歌单 gid：与 addToFavorite 同一套多级定位，保证红心状态与收藏目标一致
    QString listid, gid;
    if (findFavorite(listid, gid) && m_favGid != gid)
    {
        m_favGid = gid;
        emit favGidChanged();  // 详情页据此隐藏红心按钮
    }
    if (m_favGid.isEmpty())
        return;
    // 接口单页上限 300：分页拉全，避免红心漏判
    m_favPage  = 0;
    m_favTotal = 0;
    m_favoriteHashes.clear();
    m_favSongsAccum = QJsonArray();
    requestFavPage(1);
}

void PlaylistCollection::requestFavPage(int page)
{
    m_favPage = page;
    m_favRequester.fetchData(QString("https://api.special520.com/playlist/track/all?id=%1&page=%2&pagesize=300").arg(m_favGid).arg(page));
}

void PlaylistCollection::onFavoriteHashesData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError)
    {
        qWarning() << "[PlaylistCollection] favorite hashes parse error";
        emit favoriteHashesChanged();
        return;
    }
    const QJsonObject dataObj = doc.object()["data"].toObject();
    const QJsonArray  songs   = dataObj["songs"].toArray();
    for (const QJsonValue &val : songs)
    {
        m_favSongsAccum.append(val.toObject()); // 全量歌曲顺带累积，完成后落盘复用
        const QString h = val.toObject()["hash"].toString().toUpper();
        if (!h.isEmpty())
            m_favoriteHashes << h;
    }
    const int total = dataObj["count"].toInt(0);
    if (total > 0)
        m_favTotal = total;
    // 还有下一页（单页上限 300）
    if (m_favPage * 300 < m_favTotal)
    {
        requestFavPage(m_favPage + 1);
        return;
    }
    qDebug() << "[PlaylistCollection] 我喜欢 hash 集合更新，共" << m_favoriteHashes.size() << "个 / 总量" << m_favTotal;
    // 同步已拿到全量歌曲：落盘成歌单详情缓存（与 fetchPlaylistDetail 同格式），
    // 进「我喜欢」页面直接展示完整列表，不再重复拉接口
    QJsonObject full;
    full["count"] = m_favTotal;
    full["songs"] = m_favSongsAccum;
    QJsonObject root;
    root["status"] = 1;
    root["data"]   = full;
    QFile cacheFile(PlaylistCacheStore::configPath("playlist_" + m_favGid + ".json"));
    if (cacheFile.open(QIODevice::WriteOnly))
    {
        cacheFile.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        cacheFile.close();
    }
    emit favoriteHashesChanged();
    saveFavoriteHashesToCache();
}

void PlaylistCollection::loadFavoriteHashesFromCache()
{
    const QString path = PlaylistCacheStore::configPath("favorite_hashes.json");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray())
        return;
    QStringList hashes;
    for (const QJsonValue &v : doc.array())
    {
        const QString h = v.toString().toUpper();
        if (!h.isEmpty())
            hashes << h;
    }
    if (hashes.isEmpty())
        return;
    m_favoriteHashes = hashes;
    qDebug() << "[PlaylistCollection] 从缓存加载我喜欢 hash" << m_favoriteHashes.size() << "个";
    emit favoriteHashesChanged();
}

void PlaylistCollection::saveFavoriteHashesToCache()
{
    PlaylistCacheStore::ensureCacheDir();
    QJsonArray arr;
    for (const QString &h : m_favoriteHashes)
        arr.append(h);
    QFile f(PlaylistCacheStore::configPath("favorite_hashes.json"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
}

bool PlaylistCollection::containsHash(const QString &songhash) const
{
    return m_favoriteHashes.contains(songhash.toUpper());
}

void PlaylistCollection::removeTracks(const QString &listid, const QVariantList &fileids)
{
    if (listid.isEmpty() || fileids.isEmpty())
    {
        emit operationFinished(false, "歌单或歌曲信息不完整");
        return;
    }
    QStringList ids;
    for (const QVariant &v : fileids)
    {
        const QString id = v.toString();
        if (!id.isEmpty())
            ids << id;
    }
    if (ids.isEmpty())
    {
        emit operationFinished(false, "歌曲信息不完整");
        return;
    }
    setWorking(true);
    postForm(
        "/playlist/tracks/del", {{"listid", listid}, {"fileids", ids.join(',')}},
        [this](QJsonObject root) { parseResult(root, "已从歌单移除"); },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}
