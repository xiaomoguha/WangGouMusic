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
    , m_lazyRequester(10000, this)
{
    connect(&m_topSongsRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onTopSongsData);
    connect(&m_topPlaylistsRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onTopPlaylistsData);
    connect(&m_playlistTracksRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onPlaylistTracksData);
    connect(&m_lazyRequester, &HttpGetRequester::dataReceived, this, &Recommendation::onLazyTracksData);
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

    QVariantList parsed;
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
        parsed.append(item);
    }

    // 接口偶发返回空 data 数组时保留上一次的数据，避免首页热门歌曲被清空。
    if (parsed.isEmpty()) {
        qWarning() << "热门推荐响应为空，保留现有" << m_topSongs.size() << "首";
        return;
    }

    m_topSongs = parsed;
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

    QVariantList parsed;
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
        parsed.append(item);
    }

    // 接口偶发返回空 special_list（仅 OlexpIds 等，status 仍为 1）。
    // 此时保留上一次的数据，避免刷新把首页歌单清空。
    if (parsed.isEmpty()) {
        qWarning() << "精选歌单响应为空，保留现有" << m_topPlaylists.size() << "个歌单";
        return;
    }

    m_topPlaylists = parsed;
    emit topPlaylistsChanged();
    qDebug() << "精选歌单加载完成，共" << m_topPlaylists.size() << "个";
}

QVariantList Recommendation::getTopSongsQml() const { return m_topSongs; }
QVariantList Recommendation::getTopPlaylistsQml() const { return m_topPlaylists; }
QVariantList Recommendation::getPlaylistTracksQml() const { return m_playlistTracks; }

void Recommendation::fetchPlaylistTracks(const QString &globalCollectionId)
{
    m_currentPlaylistId = globalCollectionId;
    m_playlistPage = 0;
    m_playlistTotal = 0;
    m_playlistHasMore = true;
    m_playlistTracks.clear();
    emit playlistTracksChanged();
    fetchMorePlaylistTracks();
}

void Recommendation::fetchMorePlaylistTracks()
{
    if (m_playlistIsLoading || !m_playlistHasMore || m_currentPlaylistId.isEmpty())
        return;
    m_playlistIsLoading = true;
    emit playlistIsLoadingChanged();
    int nextPage = m_playlistPage + 1;
    QString url = QString("https://xjt-togethertracks.top/api/playlist/track/all?id=%1&page=%2&pagesize=%3")
                      .arg(m_currentPlaylistId).arg(nextPage).arg(m_playlistPageSize);
    m_playlistTracksRequester.fetchData(url);
}

void Recommendation::loadAllPlaylistTracks()
{
    if (m_playlistIsLoading || m_currentPlaylistId.isEmpty())
        return;
    m_playlistTracks.clear();
    m_playlistPage = 0;
    m_playlistHasMore = false;
    m_playlistTotal = 0;
    emit playlistTracksChanged();
    m_playlistIsLoading = true;
    emit playlistIsLoadingChanged();
    QString url = QString("https://xjt-togethertracks.top/api/playlist/track/all?id=%1&page=1&pagesize=1000")
                      .arg(m_currentPlaylistId);
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

    QJsonObject dataObj = doc.object()["data"].toObject();
    QJsonArray songs = dataObj["songs"].toArray();
    int serverCount = dataObj["count"].toInt(0);
    // loadAll 已置 hasMore=false（全量模式）；分页模式按 count 判断
    if (serverCount > 0) m_playlistTotal = serverCount;
    // 注意：不清空，追加到已有列表（fetchPlaylistTracks / loadAllPlaylistTracks 已先行 clear）

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
    // 更新分页状态：分页模式下，已加载数 < total 则还有更多
    if (m_playlistHasMore && m_playlistTotal > 0) {
        m_playlistHasMore = m_playlistTracks.size() < m_playlistTotal;
    }
    // loadAll 模式下 hasMore 保持 false（已在 loadAllPlaylistTracks 设定）
    m_playlistIsLoading = false;
    emit playlistIsLoadingChanged();
    emit playlistTracksChanged();
    qDebug() << "歌单曲目加载完成，已加载" << m_playlistTracks.size() << "/" << m_playlistTotal << "首";
}

void Recommendation::fetchPlaylistTracksPage(const QString &id, int page, int pagesize,
                                             std::function<void(const QVariantList&)> callback)
{
    m_pendingLazyCallback = callback;
    QString url = QString("https://xjt-togethertracks.top/api/playlist/track/all?id=%1&page=%2&pagesize=%3")
                      .arg(id).arg(page).arg(pagesize);
    m_lazyRequester.fetchData(url);
}

void Recommendation::onLazyTracksData(const QByteArray &data)
{
    QVariantList result;
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error == QJsonParseError::NoError && doc.isObject()) {
        QJsonArray arr = doc.object()["data"].toObject()["songs"].toArray();
        for (const QJsonValue &val : arr) {
            QJsonObject s = val.toObject();
            QString name = s["name"].toString();
            QStringList parts = name.split(" - ");
            QString songname = parts.size() > 1 ? parts.mid(1).join(" - ") : name;
            QString singername = parts.size() > 1 ? parts[0] : QString();
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
            QVariantMap item;
            item["songname"] = songname;
            item["songhash"] = s["hash"].toString();
            item["singername"] = singername;
            item["union_cover"] = cover;
            item["album_name"] = s["albuminfo"].toObject()["name"].toString();
            item["duration"] = secondsToMinutesSeconds(durationSec);
            result.append(item);
        }
    }
    if (m_pendingLazyCallback) {
        auto cb = m_pendingLazyCallback;
        m_pendingLazyCallback = nullptr;
        cb(result);
    }
}

QString Recommendation::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0);
    time = time.addSecs(totalSeconds);
    return time.toString("mm:ss");
}
