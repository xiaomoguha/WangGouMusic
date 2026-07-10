#include "PlaylistCacheStore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

// ──────────────────────────────────────────────
// 缓存目录与路径
// ──────────────────────────────────────────────

QString PlaylistCacheStore::cacheDir()
{
    // 统一实现，替代原 PlaylistManager/UserManager/LyricsConfigManager 三处 #ifdef
#ifdef Q_OS_WIN
    return QStringLiteral("C:/网狗音乐缓存目录");
#else
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)
           + QStringLiteral("/网狗音乐缓存目录");
#endif
}

void PlaylistCacheStore::ensureCacheDir()
{
    QDir dir(cacheDir());
    if (!dir.exists()) {
        if (!dir.mkpath(QStringLiteral("."))) {
            qCritical() << "无法创建缓存目录:" << cacheDir();
        }
    }
}

QString PlaylistCacheStore::playlistCachePath()
{
    return cacheDir() + QStringLiteral("/playlist_cache.json");
}

QString PlaylistCacheStore::recentCachePath()
{
    return cacheDir() + QStringLiteral("/recent_cache.json");
}

QString PlaylistCacheStore::lyricCachePath(const QString &songhash)
{
    return cacheDir() + QStringLiteral("/lyrics_") + songhash + QStringLiteral(".json");
}

// 封面 URL 升级：低清尺寸路径段统一替换为 /720/
QString PlaylistCacheStore::normalizeCoverUrl(const QString &url)
{
    QString u = url;
    static const QStringList lowRes = {QStringLiteral("/80/"), QStringLiteral("/150/"),
                                       QStringLiteral("/300/"), QStringLiteral("/400/"),
                                       QStringLiteral("/480/")};
    for (const QString &seg : lowRes) {
        u.replace(seg, QStringLiteral("/720/"));
    }
    return u;
}

// ──────────────────────────────────────────────
// 播放列表缓存
// ──────────────────────────────────────────────

bool PlaylistCacheStore::savePlaylist(const QList<SongInfo> &playlist, int currentIndex, float percent)
{
    ensureCacheDir();
    QJsonArray arr;
    for (const SongInfo &song : playlist) {
        QJsonObject obj;
        obj["title"] = song.title;
        obj["songhash"] = song.songhash;
        obj["url"] = song.url;
        obj["singername"] = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"] = song.album_name;
        obj["duration"] = song.duration;
        arr.append(obj);
    }
    QJsonObject root;
    root["playlist"] = arr;
    root["currentIndex"] = currentIndex;
    root["percent"] = static_cast<double>(percent);
    QJsonDocument doc(root);

    QFile file(playlistCachePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
        return true;
    }
    qWarning() << "无法写入播放列表缓存:" << playlistCachePath();
    return false;
}

bool PlaylistCacheStore::loadPlaylist(QList<SongInfo> &outPlaylist, int &outCurrentIndex, float &outPercent)
{
    QFile file(playlistCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        qDebug() << "无播放列表缓存文件，跳过加载";
        return false;
    }
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);

    outCurrentIndex = -1;
    outPercent = 0.0f;
    QJsonArray arr;

    if (doc.isObject()) {
        QJsonObject root = doc.object();
        arr = root["playlist"].toArray();
        outCurrentIndex = root["currentIndex"].toInt(-1);
        outPercent = static_cast<float>(root["percent"].toDouble(0.0));
    } else if (doc.isArray()) {
        arr = doc.array();
    } else {
        qWarning() << "播放列表缓存格式错误";
        return false;
    }

    outPlaylist.clear();
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title = obj["title"].toString();
        song.songhash = obj["songhash"].toString();
        song.url = obj["url"].toString();
        song.singername = obj["singername"].toString();
        song.union_cover = normalizeCoverUrl(obj["union_cover"].toString());
        song.album_name = obj["album_name"].toString();
        song.duration = obj["duration"].toString();
        song.lyric = QString();
        outPlaylist.append(song);
    }
    return true;
}

// ──────────────────────────────────────────────
// 最近播放缓存
// ──────────────────────────────────────────────

bool PlaylistCacheStore::saveRecent(const QList<SongInfo> &recent)
{
    ensureCacheDir();
    QJsonArray arr;
    for (const SongInfo &song : recent) {
        QJsonObject obj;
        obj["title"] = song.title;
        obj["songhash"] = song.songhash;
        obj["singername"] = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"] = song.album_name;
        obj["duration"] = song.duration;
        arr.append(obj);
    }
    QJsonDocument doc(arr);
    QFile file(recentCachePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
        return true;
    }
    return false;
}

bool PlaylistCacheStore::loadRecent(QList<SongInfo> &outRecent)
{
    QFile file(recentCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) return false;

    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray()) return false;

    outRecent.clear();
    QJsonArray arr = doc.array();
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title = obj["title"].toString();
        song.songhash = obj["songhash"].toString();
        song.singername = obj["singername"].toString();
        song.union_cover = normalizeCoverUrl(obj["union_cover"].toString());
        song.album_name = obj["album_name"].toString();
        song.duration = obj["duration"].toString();
        outRecent.append(song);
    }
    return true;
}

// ──────────────────────────────────────────────
// 歌词缓存
// ──────────────────────────────────────────────

bool PlaylistCacheStore::saveLyric(const QString &songhash, const QString &lyric)
{
    if (songhash.isEmpty() || lyric.isEmpty()) return false;
    ensureCacheDir();
    QFile file(lyricCachePath(songhash));
    if (file.open(QIODevice::WriteOnly)) {
        QJsonObject obj;
        obj["songhash"] = songhash;
        obj["lyric"] = lyric;
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        file.close();
        qDebug() << "歌词已缓存:" << songhash;
        return true;
    }
    return false;
}

QString PlaylistCacheStore::loadLyric(const QString &songhash)
{
    if (songhash.isEmpty()) return QString();
    QFile file(lyricCachePath(songhash));
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) return QString();
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return QString();
    return doc.object()["lyric"].toString();
}
