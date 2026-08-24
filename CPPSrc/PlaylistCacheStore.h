#ifndef PLAYLIST_CACHE_STORE_H
#define PLAYLIST_CACHE_STORE_H

#include "SongInfo.h"
#include <QDir>
#include <QSet>
#include <QString>
#include <QList>

/**
 * @brief 播放列表/最近播放/歌词的本地缓存读写工具
 *
 * 从 PlaylistManager 拆分而来。本类为纯工具类（全 static），
 * 不持有任何播放器或队列状态——只负责：
 *  - 统一缓存目录路径（消除原先 PlaylistManager/UserManager/LyricsConfigManager
 *    三处各自 #ifdef Q_OS_WIN 的重复）
 *  - SongInfo <-> JSON 序列化
 *  - 文件读写
 *
 * 调用方（PlaylistManager / UserManager / LyricsConfigManager）传入自己的
 * QList<SongInfo> 等数据结构做读写，状态管理仍归各 manager。
 */
class PlaylistCacheStore
{
public:
    // ── 缓存目录 ─────────────────────────────────────────
    /// 统一缓存目录（跨平台）。原三处 getCacheDir 的合并实现。
    static QString cacheDir();
    /// 确保缓存目录存在
    static void ensureCacheDir();
    /// 旧版平铺结构（根目录 .mp3/*.json）→ 新版分类目录（songs/128|320|flac、config、lyrics），
    /// 移动后删旧文件；已迁移过（.cache_v2 标记）则跳过。启动时调用一次。
    static void migrateLegacyCache();
    /// 歌曲缓存路径：按音质分目录（0自动/1标准→songs/128/*.mp3，2高品→songs/320/*.mp3，3无损→songs/flac/*.flac）
    static QString songCachePath(const QString &title, const QString &singer, int quality);
    /// config 子目录下指定配置文件的完整路径（history_cache.json 等）
    static QString configPath(const QString &name);

    // ── 播放列表缓存 ─────────────────────────────────────
    /// 序列化播放列表 + 播放位置到 playlist_cache.json
    static bool savePlaylist(const QList<SongInfo> &playlist, int currentIndex, float percent, int playMode);
    /// 从 playlist_cache.json 反序列化。返回是否成功读取（含索引/进度）
    static bool loadPlaylist(QList<SongInfo> &outPlaylist, int &outCurrentIndex, float &outPercent, int &outPlayMode);

    // ── 最近播放缓存 ─────────────────────────────────────
    static bool saveRecent(const QList<SongInfo> &recent);
    static bool loadRecent(QList<SongInfo> &outRecent);

    // ── 歌词缓存 ─────────────────────────────────────────
    static bool saveLyric(const QString &songhash, const QString &lyric);
    static QString loadLyric(const QString &songhash);

private:
    PlaylistCacheStore() = delete; // 纯工具类，禁止实例化

    static QString playlistCachePath();
    static QString recentCachePath();
    static QString lyricCachePath(const QString &songhash);
    /// 迁移单个文件到子目录（目标已存在则直接删旧文件）
    static void migrateFile(QDir &root, const QString &name, const QString &subDir);

    // 封面 URL 升级：旧缓存里的低清尺寸统一升到 720（消除 playlistmanager 的两处自重复）
    static QString normalizeCoverUrl(const QString &url);
};

#endif // PLAYLIST_CACHE_STORE_H
