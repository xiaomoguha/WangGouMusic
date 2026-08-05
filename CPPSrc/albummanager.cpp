#include "albummanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>

namespace
{
const char *const kApiRoot = "https://xjt-togethertracks.top/api";

QString secondsToMinutesSeconds(int ms)
{
    if (ms <= 0)
        return QStringLiteral("--:--");
    const int seconds = ms / 1000;
    return QStringLiteral("%1:%2").arg(seconds / 60).arg(seconds % 60, 2, 10, QLatin1Char('0'));
}
} // namespace

AlbumManager::AlbumManager(QObject *parent) : QObject(parent)
{
    connect(&m_detailRequester, &HttpGetRequester::dataReceived, this, &AlbumManager::onDetailData);
    connect(&m_songsRequester, &HttpGetRequester::dataReceived, this, &AlbumManager::onSongsData);

    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_detailRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_detailRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_songsRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_songsRequester, &HttpGetRequester::requestTimeout, this, timeout);
}

bool AlbumManager::fetchAlbum(const QString &id)
{
    if (id.isEmpty() || m_isLoading)
        return false;
    m_isLoading = true;
    emit isLoadingChanged();

    m_albumId    = id;
    m_pendingCount = 2;   // detail + songs
    m_page       = 0;
    m_hasMore    = false;
    m_album.clear();
    m_songs.clear();
    emit albumChanged();
    emit songsChanged();

    m_detailRequester.fetchData(QStringLiteral("%1/album/detail?id=%2").arg(kApiRoot, id));
    fetchMoreSongs();
    return true;
}

void AlbumManager::fetchMoreSongs()
{
    if (m_albumId.isEmpty())
        return;
    m_page++;
    m_songsRequester.fetchData(QStringLiteral("%1/album/songs?id=%2&page=%3&pagesize=30")
                                   .arg(kApiRoot, m_albumId).arg(m_page));
}

void AlbumManager::onDetailData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonArray arr = doc.object()["data"].toArray();
    if (arr.isEmpty())
    {
        onFailed(QStringLiteral("empty detail"));
        return;
    }
    const QJsonObject d = arr.first().toObject();
    QString cover = d["sizable_cover"].toString();
    if (cover.isEmpty())
        cover = d["cover"].toString();
    cover.replace("{size}", "720");

    QVariantMap a;
    a["name"]        = d["album_name"].toString();
    a["cover"]       = cover;
    a["intro"]       = d["intro"].toString();
    a["publish_date"] = d["publish_date"].toString();
    a["author"]      = d["author_name"].toString();
    a["language"]    = d["language"].toString();
    m_album = a;
    emit albumChanged();
    finishOne();
}

void AlbumManager::onSongsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonObject root = doc.object()["data"].toObject();
    const int total        = root["total"].toInt(0);
    const QJsonArray list  = root["songs"].toArray();
    m_hasMore              = total > m_songs.size() + list.size();

    for (const QJsonValue &val : list)
    {
        const QJsonObject s = val.toObject();
        const QJsonObject base  = s["base"].toObject();
        const QJsonObject audio = s["audio_info"].toObject();
        const QJsonObject alb   = s["album_info"].toObject();

        QString cover = alb["cover"].toString();
        if (cover.isEmpty())
            cover = s["trans_param"].toObject()["union_cover"].toString();
        cover.replace("{size}", "720");

        QVariantMap song;
        song["songname"]   = base["audio_name"].toString();
        song["singername"] = base["author_name"].toString();
        song["songhash"]   = audio["hash"].toString();
        song["album_name"] = alb["album_name"].toString();
        song["duration"]   = secondsToMinutesSeconds(audio["duration"].toInt());
        song["union_cover"] = cover;
        m_songs.append(song);
    }
    emit songsChanged();
    finishOne();
}

void AlbumManager::onFailed(const QString &err)
{
    qWarning() << "[AlbumManager] request error:" << err;
    finishOne();
}

void AlbumManager::finishOne()
{
    if (m_pendingCount > 0)
        m_pendingCount--;
    if (m_pendingCount == 0 && m_isLoading)
    {
        m_isLoading = false;
        emit isLoadingChanged();
    }
}
