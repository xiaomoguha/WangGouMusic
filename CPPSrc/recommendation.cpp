#include "recommendation.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonParseError>
#include <QDebug>
#include <QTime>
#include <QRandomGenerator>

Recommendation::Recommendation(QObject *parent)
    : QObject(parent)
    , m_topSongsRequester(10000, this)
    , m_topPlaylistsRequester(10000, this)
    , m_playlistTracksRequester(10000, this)
{
    connect(&m_topSongsRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onTopSongsData);
    connect(&m_topPlaylistsRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onTopPlaylistsData);
    connect(&m_playlistTracksRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onPlaylistTracksData);
}

void Recommendation::fetchTopSongs()
{
    m_topSongsRequester.fetchData("https://xjt-togethertracks.top/api/top/song");
}

void Recommendation::fetchTopPlaylists()
{
    m_topPlaylistsRequester.fetchData("https://xjt-togethertracks.top/api/top/playlist?pagesize=6");
}

void Recommendation::refreshTopPlaylists()
{
    QStringList categories = {"0", "587", "583", "20", "577", "12", "35"};
    QString categoryId = categories[QRandomGenerator::global()->bounded(categories.size())];
    QString url = QString("https://xjt-togethertracks.top/api/top/playlist?pagesize=6&category_id=%1").arg(categoryId);
    m_topPlaylistsRequester.fetchData(url);
    qDebug() << "刷新歌单，分类 ID:" << categoryId;
}

void Recommendation::onTopSongsData(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "Top songs JSON parse error:" << error.errorString();
        return;
    }

    QJsonArray songs = doc.object()["data"].toArray();
    m_topSongs.clear();

    for (const QJsonValue &val : songs) {
        QJsonObject s = val.toObject();
        QString hash = s["hash"].toString();
        QString songname = s["songname"].toString();
        QString albumName = s["album_name"].toString();

        // authors 数组拼接歌手名
        QJsonArray authors = s["authors"].toArray();
        QStringList names;
        for (const QJsonValue &a : authors)
            names << a.toObject()["author_name"].toString();
        QString singername = names.join(", ");

        QString cover = s["trans_param"].toObject()["union_cover"].toString();
        cover.replace("{size}", "720");

        int durationMs = s["timelength_128"].toInt();
        QString duration = secondsToMinutesSeconds(durationMs / 1000);

        QVariantMap item;
        item["songname"] = songname;
        item["singername"] = singername;
        item["songhash"] = hash;
        item["union_cover"] = cover;
        item["album_name"] = albumName;
        item["duration"] = duration;
        m_topSongs.append(item);
    }
    emit topSongsChanged();
    qDebug() << "热门推荐加载完成，共" << m_topSongs.size() << "首";
}

void Recommendation::onTopPlaylistsData(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "Top playlists JSON parse error:" << error.errorString();
        return;
    }

    QJsonArray list = doc.object()["data"].toObject()["special_list"].toArray();
    m_topPlaylists.clear();

    for (const QJsonValue &val : list) {
        QJsonObject pl = val.toObject();
        QString imgurl = pl["imgurl"].toString();
        imgurl.replace("{size}", "400");

        // 拼接标签
        QJsonArray tags = pl["tags"].toArray();
        QStringList tagNames;
        for (const QJsonValue &t : tags)
            tagNames << t.toObject()["tag_name"].toString();

        QVariantMap item;
        item["specialname"] = pl["specialname"].toString();
        item["imgurl"] = imgurl;
        item["intro"] = pl["intro"].toString();
        item["play_count"] = pl["play_count"].toInt();
        item["global_collection_id"] = pl["global_collection_id"].toString();
        item["specialid"] = pl["specialid"].toInt();
        item["tags"] = tagNames.join(" / ");
        m_topPlaylists.append(item);
    }
    emit topPlaylistsChanged();
    qDebug() << "精选歌单加载完成，共" << m_topPlaylists.size() << "个";
}

QVariantList Recommendation::getTopSongsQml() const { return m_topSongs; }
QVariantList Recommendation::getTopPlaylistsQml() const { return m_topPlaylists; }
QVariantList Recommendation::getPlaylistTracksQml() const { return m_playlistTracks; }

void Recommendation::fetchPlaylistTracks(const QString &globalCollectionId)
{
    QString url = QString("https://xjt-togethertracks.top/api/playlist/track/all?id=%1&pagesize=50").arg(globalCollectionId);
    m_playlistTracksRequester.fetchData(url);
}

void Recommendation::onPlaylistTracksData(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "Playlist tracks JSON parse error:" << error.errorString();
        return;
    }

    QJsonArray songs = doc.object()["data"].toObject()["songs"].toArray();
    m_playlistTracks.clear();

    for (const QJsonValue &val : songs) {
        QJsonObject s = val.toObject();
        QString hash = s["hash"].toString();
        QString name = s["name"].toString();

        // name 格式通常为 "歌手 - 歌名"
        QStringList parts = name.split(" - ");
        QString songname = parts.size() > 1 ? parts.mid(1).join(" - ") : name;
        QString singername = parts.size() > 1 ? parts[0] : QString();

        // 优先从 singerinfo 取歌手名
        QJsonArray singerinfo = s["singerinfo"].toArray();
        if (!singerinfo.isEmpty()) {
            QStringList singers;
            for (const QJsonValue &si : singerinfo)
                singers << si.toObject()["name"].toString();
            singername = singers.join(", ");
        }

        QString cover = s["trans_param"].toObject()["union_cover"].toString();
        if (cover.isEmpty()) cover = s["cover"].toString();
        cover.replace("{size}", "720");

        int durationSec = s["timelen"].toInt(0) / 1000;
        QString albumName = s["albuminfo"].toObject()["name"].toString();

        QVariantMap item;
        item["songname"] = songname;
        item["singername"] = singername;
        item["songhash"] = hash;
        item["union_cover"] = cover;
        item["album_name"] = albumName;
        item["duration"] = secondsToMinutesSeconds(durationSec);
        m_playlistTracks.append(item);
    }
    emit playlistTracksChanged();
    qDebug() << "歌单曲目加载完成，共" << m_playlistTracks.size() << "首";
}

QString Recommendation::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0);
    time = time.addSecs(totalSeconds);
    return time.toString("mm:ss");
}
