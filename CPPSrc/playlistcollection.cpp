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

void PlaylistCollection::addTracks(const QString &listid, const QVariantList &songs)
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
        [this](QJsonObject root) { parseResult(root, "已添加到歌单"); },
        [this](QString err, int) { setWorking(false); emit operationFinished(false, "网络错误: " + err); }
    );
}

void PlaylistCollection::addToFavorite(const QString &songname, const QString &songhash, const QString &singername)
{
    if (songname.isEmpty() || songhash.isEmpty())
    {
        emit operationFinished(false, "当前歌曲信息不完整");
        return;
    }
    // 「我喜欢」是普通歌单：从歌单缓存按名字匹配取 listid
    QString listid;
    if (m_userManager)
    {
        const QVariantMap cached = m_userManager->loadCachedPlaylists();
        // 缓存根结构 {data: {info: [...]}}，兼容无 data 包裹的情况
        const QVariantList infos = cached["data"].toMap()["info"].toList();
        for (const QVariant &v : infos)
        {
            const QString name = v.toMap()["name"].toString();
            if (name.contains(QStringLiteral("我喜欢")))
            {
                listid = v.toMap()["listid"].toString();
                break;
            }
        }
    }
    if (listid.isEmpty())
    {
        emit operationFinished(false, "未找到「我喜欢」歌单，请先刷新歌单");
        return;
    }

    QVariantMap song;
    song["songname"]   = songname;
    song["songhash"]   = songhash;
    song["singername"] = singername;
    QVariantList songs;
    songs.append(song);
    addTracks(listid, songs);
}

void PlaylistCollection::refreshFavoriteHashes()
{
    // 找「我喜欢」歌单 gid（缓存）
    if (m_userManager)
    {
        const QVariantMap cached = m_userManager->loadCachedPlaylists();
        // 缓存根结构 {data: {info: [...]}}，兼容无 data 包裹的情况
        const QVariantList infos = cached["data"].toMap()["info"].toList();
        for (const QVariant &v : infos)
        {
            const QVariantMap p  = v.toMap();
            const QString    gid = p["global_collection_id"].toString();
            if (!gid.isEmpty() && p["name"].toString().contains(QStringLiteral("我喜欢")))
            {
                m_favGid = gid;
                break;
            }
        }
    }
    if (m_favGid.isEmpty())
        return;
    // 接口单页上限 300：分页拉全，避免红心漏判
    m_favPage  = 0;
    m_favTotal = 0;
    m_favoriteHashes.clear();
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
