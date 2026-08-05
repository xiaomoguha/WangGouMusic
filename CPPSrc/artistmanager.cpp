#include "artistmanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QUrl>
#include <QUrlQuery>

namespace
{
const char *const kApiRoot = "https://xjt-togethertracks.top/api";

// 秒 → "m:ss"
QString secondsToMinutesSeconds(int seconds)
{
    if (seconds <= 0)
        return QStringLiteral("--:--");
    const int m = seconds / 60;
    const int s = seconds % 60;
    return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
}
} // namespace

ArtistManager::ArtistManager(QObject *parent) : QObject(parent)
{
    connect(&m_detailRequester, &HttpGetRequester::dataReceived, this, &ArtistManager::onDetailData);
    connect(&m_audiosRequester, &HttpGetRequester::dataReceived, this, &ArtistManager::onAudiosData);
    connect(&m_albumsRequester, &HttpGetRequester::dataReceived, this, &ArtistManager::onAlbumsData);
    connect(&m_searchRequester, &HttpGetRequester::dataReceived, this, &ArtistManager::onSearchData);

    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_detailRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_detailRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_audiosRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_audiosRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_albumsRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_albumsRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_searchRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_searchRequester, &HttpGetRequester::requestTimeout, this, timeout);
}

bool ArtistManager::fetchArtist(const QString &id)
{
    if (id.isEmpty() || m_isLoading)
        return false;
    m_isLoading = true;
    emit isLoadingChanged();

    m_artistId    = id;
    m_pendingCount = 3;   // detail + audios + albums
    m_songPage    = 0;
    m_albumPage   = 0;
    m_hasMoreSongs  = false;
    m_hasMoreAlbums = false;
    m_artist.clear();
    m_songsModel.clear();
    m_albumsModel.clear();
    emit artistChanged();

    // 详情 + 两个列表第一页并行
    m_detailRequester.fetchData(QStringLiteral("%1/artist/detail?id=%2").arg(kApiRoot, id));
    fetchMoreSongs();
    fetchMoreAlbums();
    return true;
}

void ArtistManager::fetchMoreSongs()
{
    if (m_artistId.isEmpty() || m_loadingSongs)
        return;
    m_loadingSongs = true;
    emit songsLoadingChanged();
    m_songPage++;
    // sort=hot：歌手页默认最热排序（不传默认最新）
    m_audiosRequester.fetchData(QStringLiteral("%1/artist/audios?id=%2&page=%3&pagesize=30&sort=hot")
                                    .arg(kApiRoot, m_artistId).arg(m_songPage));
}

void ArtistManager::fetchMoreAlbums()
{
    if (m_artistId.isEmpty() || m_loadingAlbums)
        return;
    m_loadingAlbums = true;
    emit albumsLoadingChanged();
    m_albumPage++;
    m_albumsRequester.fetchData(QStringLiteral("%1/artist/albums?id=%2&page=%3&pagesize=30")
                                    .arg(kApiRoot, m_artistId).arg(m_albumPage));
}

void ArtistManager::searchSinger(const QString &name)
{
    QUrl url(QStringLiteral("%1/search").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("keywords", name);
    query.addQueryItem("type", "author");
    query.addQueryItem("page", "1");
    query.addQueryItem("pagesize", "1");
    url.setQuery(query);
    m_searchRequester.fetchData(url.toString());
}

void ArtistManager::onDetailData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonObject d = doc.object()["data"].toObject();
    QString avatar = d["sizable_avatar"].toString();
    avatar.replace("{size}", "480");

    QVariantMap a;
    a["name"]       = d["author_name"].toString();
    a["avatar"]     = avatar;
    a["fans"]       = d["fansnums"].toInt();
    a["albumCount"] = d["album_count"].toInt();
    a["audioCount"] = d["song_count"].toInt();
    // long_intro 是 {content} 数组，拼成一段纯文本
    QStringList introParts;
    const QJsonArray intro = d["long_intro"].toArray();
    for (const QJsonValue &v : intro)
    {
        const QString t = v.toObject()["content"].toString();
        if (!t.isEmpty())
            introParts << t;
    }
    a["intro"] = introParts.join(QLatin1Char('\n'));
    m_artist = a;
    emit artistChanged();
    finishOne();
}

void ArtistManager::onAudiosData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonObject root = doc.object();
    const int total        = root["total"].toInt(0);
    const int loaded       = m_songsModel.count() + root["data"].toArray().size();
    const bool newHasMore  = total > loaded;
    if (newHasMore != m_hasMoreSongs)
    {
        m_hasMoreSongs = newHasMore;
        emit hasMoreSongsChanged();
    }

    QVariantList newSongs;
    const QJsonArray list = root["data"].toArray();
    for (const QJsonValue &val : list)
    {
        const QJsonObject o    = val.toObject();
        const QJsonObject tp   = o["trans_param"].toObject();
        QString cover = tp["union_cover"].toString();
        cover.replace("{size}", "720");

        QVariantMap song;
        song["songname"]   = o["audio_name"].toString();
        song["singername"] = o["author_name"].toString();
        song["songhash"]   = o["hash"].toString();
        song["album_name"] = o["album_name"].toString();
        song["duration"]   = secondsToMinutesSeconds(o["timelength"].toInt() / 1000);
        song["union_cover"] = cover;
        newSongs.append(song);
    }
    m_songsModel.appendList(newSongs);
    m_loadingSongs = false;
    emit songsLoadingChanged();
    finishOne();
}

void ArtistManager::onAlbumsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonObject root  = doc.object();
    const int total         = root["total"].toInt(0);
    const int loaded        = m_albumsModel.count() + root["data"].toArray().size();
    const bool newHasMore   = total > loaded;
    if (newHasMore != m_hasMoreAlbums)
    {
        m_hasMoreAlbums = newHasMore;
        emit hasMoreAlbumsChanged();
    }

    QVariantList newAlbums;
    const QJsonArray list = root["data"].toArray();
    for (const QJsonValue &val : list)
    {
        const QJsonObject o = val.toObject();
        QString cover = o["sizable_cover"].toString();
        if (cover.isEmpty())
            cover = o["cover"].toString();
        cover.replace("{size}", "720");

        QVariantMap a;
        // album_id 响应里是数字，toString() 对数字返回空 → 用 toInt（QML 侧 String() 转回）
        a["album_id"]  = o["album_id"].toInt();
        a["album_name"] = o["album_name"].toString();
        a["intro"]     = o["intro"].toString();
        a["cover"]     = cover;
        a["publish_date"] = o["publish_date"].toString();
        newAlbums.append(a);
    }
    m_albumsModel.appendList(newAlbums);
    m_loadingAlbums = false;
    emit albumsLoadingChanged();
    finishOne();
}

void ArtistManager::onSearchData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return;
    const QJsonArray lists = doc.object()["data"].toObject()["lists"].toArray();

    QVariantMap result;
    if (!lists.isEmpty())
    {
        const QJsonObject s = lists.first().toObject();
        QString avatar = s["Avatar"].toString();
        avatar.replace("{size}", "480");
        result["id"]       = QString::number(s["AuthorId"].toInt());
        result["name"]     = s["AuthorName"].toString();
        result["avatar"]   = avatar;
        result["fans"]     = s["FansNum"].toInt();
        result["audioCount"] = s["AudioCount"].toInt();
        result["albumCount"] = s["AlbumCount"].toInt();
    }
    emit singerFound(result);
}

void ArtistManager::onFailed(const QString &err)
{
    qWarning() << "[ArtistManager] request error:" << err;
    m_loadingSongs = false;
    m_loadingAlbums = false;
    emit songsLoadingChanged();
    emit albumsLoadingChanged();
    finishOne();
}

void ArtistManager::finishOne()
{
    if (m_pendingCount > 0)
        m_pendingCount--;
    if (m_pendingCount == 0 && m_isLoading)
    {
        m_isLoading = false;
        emit isLoadingChanged();
    }
}
