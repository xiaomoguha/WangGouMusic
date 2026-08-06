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
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + QStringLiteral("/网狗音乐缓存目录");
#endif
}

void PlaylistCacheStore::ensureCacheDir()
{
    QDir dir(cacheDir());
    if (!dir.exists())
    {
        if (!dir.mkpath(QStringLiteral(".")))
        {
            qCritical() << "无法创建缓存目录:" << cacheDir();
        }
    }
}

// 旧版平铺结构 → 新版分类目录（songs/128|320|flac、config、lyrics），迁移后删旧文件。
// .cache_v2 标记文件保证只迁移一次（后续版本不再扫描根目录）。
void PlaylistCacheStore::migrateLegacyCache()
{
    ensureCacheDir();
    if (QFile::exists(cacheDir() + QStringLiteral("/.cache_v2")))
        return;
    QDir root(cacheDir());
    // 根目录旧歌曲缓存（平铺 mp3 都是默认音质）→ songs/128/
    const QStringList songs = root.entryList({QStringLiteral("*.mp3")}, QDir::Files);
    for (const QString &f : songs)
        migrateFile(root, f, QStringLiteral("songs/128"));
    // 旧配置文件 → config/
    migrateFile(root, QStringLiteral("playlist_cache.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("recent_cache.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("history_cache.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("lyrics_config.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("favorite_hashes.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("playlists_cache.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("search_history.json"), QStringLiteral("config"));
    migrateFile(root, QStringLiteral("user_detail_cache.json"), QStringLiteral("config"));
    // 用户歌单详情缓存 playlist_collection_*.json（注意别误匹配 playlist_cache.json，前缀不同）
    const QStringList collections = root.entryList({QStringLiteral("playlist_*.json")}, QDir::Files);
    for (const QString &f : collections)
        migrateFile(root, f, QStringLiteral("config"));
    // 旧歌词文件 → lyrics/
    const QStringList lyrics = root.entryList({QStringLiteral("lyrics_*.json")}, QDir::Files);
    for (const QString &f : lyrics)
        migrateFile(root, f, QStringLiteral("lyrics"));
    // 写迁移标记
    QFile marker(cacheDir() + QStringLiteral("/.cache_v2"));
    if (marker.open(QIODevice::WriteOnly))
    {
        marker.write("1");
        marker.close();
    }
    qDebug() << "[PlaylistCacheStore] 旧版缓存迁移完成";
}

void PlaylistCacheStore::migrateFile(QDir &root, const QString &name, const QString &subDir)
{
    const QString from = root.filePath(name);
    if (!QFile::exists(from))
        return;
    QDir target(cacheDir() + QStringLiteral("/") + subDir);
    if (!target.exists())
        target.mkpath(QStringLiteral("."));
    // 目标已存在（新结构已写入同文件）：直接删旧的，保留新的
    if (QFile::exists(target.filePath(name)))
    {
        QFile::remove(from);
        return;
    }
    if (QFile::rename(from, target.filePath(name)))
        qDebug() << "[PlaylistCacheStore] 迁移" << name << "→" << subDir;
    else
        qWarning() << "[PlaylistCacheStore] 迁移失败:" << name;
}

// 歌曲缓存按音质分目录：0自动/1标准 → songs/128/*.mp3，2高品 → songs/320/*.mp3，3无损 → songs/flac/*.flac
QString PlaylistCacheStore::songCachePath(const QString &title, const QString &singer, int quality)
{
    static const char *const dirs[] = {"128", "128", "320", "flac"};
    static const char *const exts[] = {".mp3", ".mp3", ".mp3", ".flac"};
    const int q = qBound(0, quality, 3);
    return QStringLiteral("%1/songs/%2/%3-%4%5")
        .arg(cacheDir(), QLatin1String(dirs[q]), title, singer, QLatin1String(exts[q]));
}

QString PlaylistCacheStore::configPath(const QString &name)
{
    return cacheDir() + QStringLiteral("/config/") + name;
}

QString PlaylistCacheStore::playlistCachePath()
{
    return configPath(QStringLiteral("playlist_cache.json"));
}

QString PlaylistCacheStore::recentCachePath()
{
    return configPath(QStringLiteral("recent_cache.json"));
}

QString PlaylistCacheStore::lyricCachePath(const QString &songhash)
{
    return cacheDir() + QStringLiteral("/lyrics/lyrics_") + songhash + QStringLiteral(".json");
}

// 封面 URL 升级：低清尺寸路径段统一替换为 /720/
QString PlaylistCacheStore::normalizeCoverUrl(const QString &url)
{
    QString u                       = url;
    static const QStringList lowRes = {
        QStringLiteral("/80/"), QStringLiteral("/150/"), QStringLiteral("/300/"), QStringLiteral("/400/"),
        QStringLiteral("/480/")
    };
    for (const QString &seg : lowRes)
    {
        u.replace(seg, QStringLiteral("/720/"));
    }
    return u;
}

// ──────────────────────────────────────────────
// 播放列表缓存
// ──────────────────────────────────────────────

bool PlaylistCacheStore::savePlaylist(const QList<SongInfo> &playlist, int currentIndex, float percent, int playMode)
{
    ensureCacheDir();
    QJsonArray arr;
    for (const SongInfo &song : playlist)
    {
        QJsonObject obj;
        obj["title"]       = song.title;
        obj["songhash"]    = song.songhash;
        obj["url"]         = song.url;
        obj["singername"]  = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"]  = song.album_name;
        obj["duration"]    = song.duration;
        arr.append(obj);
    }
    QJsonObject root;
    root["playlist"]     = arr;
    root["currentIndex"] = currentIndex;
    root["percent"]      = static_cast<double>(percent);
    root["playMode"]     = playMode;
    QJsonDocument doc(root);

    QFile file(playlistCachePath());
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
        return true;
    }
    qWarning() << "无法写入播放列表缓存:" << playlistCachePath();
    return false;
}

bool PlaylistCacheStore::loadPlaylist(QList<SongInfo> &outPlaylist, int &outCurrentIndex, float &outPercent, int &outPlayMode)
{
    QFile file(playlistCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
    {
        qDebug() << "无播放列表缓存文件，跳过加载";
        return false;
    }
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);

    outCurrentIndex = -1;
    outPercent      = 0.0f;
    outPlayMode     = -1;   // 旧缓存无该字段：调用方保持默认
    QJsonArray arr;

    if (doc.isObject())
    {
        QJsonObject root = doc.object();
        arr              = root["playlist"].toArray();
        outCurrentIndex  = root["currentIndex"].toInt(-1);
        outPercent       = static_cast<float>(root["percent"].toDouble(0.0));
        outPlayMode      = root["playMode"].toInt(-1);
    }
    else if (doc.isArray())
    {
        arr = doc.array();
    }
    else
    {
        qWarning() << "播放列表缓存格式错误";
        return false;
    }

    outPlaylist.clear();
    for (const QJsonValue &val : arr)
    {
        if (!val.isObject())
            continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title       = obj["title"].toString();
        song.songhash    = obj["songhash"].toString();
        song.url         = obj["url"].toString();
        song.singername  = obj["singername"].toString();
        song.union_cover = normalizeCoverUrl(obj["union_cover"].toString());
        song.album_name  = obj["album_name"].toString();
        song.duration    = obj["duration"].toString();
        song.lyric       = QString();
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
    for (const SongInfo &song : recent)
    {
        QJsonObject obj;
        obj["title"]       = song.title;
        obj["songhash"]    = song.songhash;
        obj["singername"]  = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"]  = song.album_name;
        obj["duration"]    = song.duration;
        arr.append(obj);
    }
    QJsonDocument doc(arr);
    QFile file(recentCachePath());
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
        return true;
    }
    return false;
}

bool PlaylistCacheStore::loadRecent(QList<SongInfo> &outRecent)
{
    QFile file(recentCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return false;

    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray())
        return false;

    outRecent.clear();
    QJsonArray arr = doc.array();
    for (const QJsonValue &val : arr)
    {
        if (!val.isObject())
            continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title       = obj["title"].toString();
        song.songhash    = obj["songhash"].toString();
        song.singername  = obj["singername"].toString();
        song.union_cover = normalizeCoverUrl(obj["union_cover"].toString());
        song.album_name  = obj["album_name"].toString();
        song.duration    = obj["duration"].toString();
        outRecent.append(song);
    }
    return true;
}

// ──────────────────────────────────────────────
// 歌词缓存
// ──────────────────────────────────────────────

bool PlaylistCacheStore::saveLyric(const QString &songhash, const QString &lyric)
{
    if (songhash.isEmpty() || lyric.isEmpty())
        return false;
    ensureCacheDir();
    QFile file(lyricCachePath(songhash));
    if (file.open(QIODevice::WriteOnly))
    {
        QJsonObject obj;
        obj["songhash"] = songhash;
        obj["lyric"]    = lyric;
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        file.close();
        qDebug() << "歌词已缓存:" << songhash;
        return true;
    }
    return false;
}

QString PlaylistCacheStore::loadLyric(const QString &songhash)
{
    if (songhash.isEmpty())
        return QString();
    QFile file(lyricCachePath(songhash));
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return QString();
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
        return QString();
    return doc.object()["lyric"].toString();
}
