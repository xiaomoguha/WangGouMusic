#ifndef PLAYLIST_CACHE_STORE_H
#define PLAYLIST_CACHE_STORE_H

#include <QString>
#include <QList>
#include "SongInfo.h"

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

    // ── 播放列表缓存 ─────────────────────────────────────
    /// 序列化播放列表 + 播放位置到 playlist_cache.json
    static bool savePlaylist(const QList<SongInfo> &playlist, int currentIndex, float percent);
    /// 从 playlist_cache.json 反序列化。返回是否成功读取（含索引/进度）
    static bool loadPlaylist(QList<SongInfo> &outPlaylist, int &outCurrentIndex, float &outPercent);

    // ── 最近播放缓存 ─────────────────────────────────────
    static bool saveRecent(const QList<SongInfo> &recent);
    static bool loadRecent(QList<SongInfo> &outRecent);

    // ── 歌词缓存 ─────────────────────────────────────────
    static bool saveLyric(const QString &songhash, const QString &lyric);
    static QString loadLyric(const QString &songhash);

private:
    PlaylistCacheStore() = delete;  // 纯工具类，禁止实例化

    static QString playlistCachePath();
    static QString recentCachePath();
    static QString lyricCachePath(const QString &songhash);

    // 封面 URL 升级：旧缓存里的低清尺寸统一升到 720（消除 playlistmanager 的两处自重复）
    static QString normalizeCoverUrl(const QString &url);
};

#endif // PLAYLIST_CACHE_STORE_H
