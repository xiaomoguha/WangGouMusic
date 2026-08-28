#ifndef PLAYLISTMANAGER_H
#define PLAYLISTMANAGER_H
#include "lyricparser.h"
#include "SongInfo.h"
#include "models/SongListModel.h"
#include "recommendation.h"
#include <QObject>
#include <functional>
#include <QHash>
#include <QList>
#include <QPair>
#include <QSet>
#include <QVector>
#include <QString>
#include <QMediaPlayer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QAudioOutput>
#include <QTime>
#include <QTimer>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDir>
#include <QImage>
#include <QColor>
#include <QNetworkRequest>
#include <QSettings>

class DominantColorExtractor;
class QPropertyAnimation;

enum PlaylistType
{
    LOCAL,
    TOGETHER
};

// 播放模式：顺序 / 单曲循环 / 随机
enum PlayMode
{
    MODE_ORDER = 0,
    MODE_SINGLE_LOOP = 1,
    MODE_RANDOM = 2
};

class PlaylistManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentSonghash READ currentSongHash NOTIFY currentSongChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentSongChanged)
    Q_PROPERTY(QString currentsingername READ currentsingername NOTIFY currentSongChanged)
    Q_PROPERTY(bool isPaused READ isPaused NOTIFY isPausedChanged)
    Q_PROPERTY(QString union_cover READ union_cover NOTIFY currentSongChanged)
    Q_PROPERTY(QString dominantColor READ dominantColor NOTIFY dominantColorChanged)
    Q_PROPERTY(float percent READ getpercent NOTIFY percentChanged)
    Q_PROPERTY(QString percentstr READ getpercentstr NOTIFY percentChanged)
    // UI 空闲（窗口被遮蔽或应用失焦，main.qml 同步）：跳过进度条 10fps 发射，
    // 没人看时省掉主窗口整窗重绘；歌词 60Hz 定时器与桌面歌词不受影响
    Q_PROPERTY(bool uiIdle READ isUiIdle WRITE setUiIdle NOTIFY uiIdleChanged)
    Q_PROPERTY(QString duration READ durationstr NOTIFY durationChanged)
    Q_PROPERTY(SongListModel *playlist READ playlistModel NOTIFY playlistUpdated)
    Q_PROPERTY(int playlistcount READ playlistcount NOTIFY playlistUpdated)
    Q_PROPERTY(int playlistTotalCount READ playlistTotalCount NOTIFY playlistUpdated)
    Q_PROPERTY(QString currlyric READ getcurrlyric NOTIFY currlyricChanged)
    Q_PROPERTY(enum PlaylistType type READ getplaylist_type NOTIFY playlist_typeChanged)
    Q_PROPERTY(SongListModel *togetherplaylist READ togetherplaylistModel NOTIFY togetherplaylistUpdated)
    Q_PROPERTY(SongListModel *recentPlaylist READ recentPlaylistModel NOTIFY recentPlaylistUpdated)
    Q_PROPERTY(QVector<LyricLine> m_lyrics READ LyricLine_get NOTIFY parlyricsuc)
    Q_PROPERTY(qint64 lyricsindex READ lyricsindexget NOTIFY currlyricChanged)
    Q_PROPERTY(int lyricCharIndex READ lyricCharIndexget NOTIFY currlyricChanged)
    Q_PROPERTY(float lyricCharProgress READ lyricCharProgressget NOTIFY currlyricChanged)
    Q_PROPERTY(QVariantList lyricChars READ lyricCharsget NOTIFY currlyricChanged)
    Q_PROPERTY(int lyricCharCount READ lyricCharCountget NOTIFY currlyricChanged)
    Q_PROPERTY(int lyricOffsetMs READ lyricOffsetMs NOTIFY lyricOffsetChanged)  // 歌词偏移（毫秒，正值=歌词提前显示）
    Q_PROPERTY(qreal downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool isBuffering READ isBuffering NOTIFY isBufferingChanged)
    Q_PROPERTY(int playMode READ playMode NOTIFY playModeChanged)
    Q_PROPERTY(int quality READ quality NOTIFY qualityChanged)  // 0自动/1标准128/2高品320/3无损flac
    Q_PROPERTY(qreal climaxPercent READ climaxPercent NOTIFY climaxPercentChanged)  // 高潮段位置（0~1）
    Q_PROPERTY(qreal volume READ volume NOTIFY volumeChanged)  // 音量 0~1（持久化）
public:
    explicit PlaylistManager(Recommendation *recommendation, QObject *parent = nullptr);
    ~PlaylistManager(); // 清理退出中断留下的半截下载文件
    // 歌词逐字动画刷新频率的自适应开关：播放页展开 → 60Hz（用户直接看动画），
    // 桌面歌词窗口可见 → 60Hz（与播放页一致），都不可见 → 定时器停止
    Q_INVOKABLE void setPlayingPageLyricsActive(bool active);
    Q_INVOKABLE void setDesktopLyricsActive(bool active);
    bool isUiIdle() const { return m_uiIdle; }
    void setUiIdle(bool idle);
    Q_INVOKABLE void addSong(const SongInfo &song);
    Q_INVOKABLE void addSong(const QVariantMap &songMap);
    Q_INVOKABLE void removeSong(int index);
    Q_INVOKABLE void clearPlaylist();
    Q_INVOKABLE void playSongbyhasg(const QString &songhash);
    Q_INVOKABLE void playSongbyindex(int index);
    void loadSongPaused(int index);
    Q_INVOKABLE void playNext();
    Q_INVOKABLE void playPrevious();
    Q_INVOKABLE void playstop();
    Q_INVOKABLE void cyclePlayMode(); // 顺序 → 单曲循环 → 随机 → 顺序
    int playMode() const;
    int quality() const;
    Q_INVOKABLE void setQuality(int q);  // 切换音质：清空已取 URL 强制重取，当前歌即时换源
    Q_INVOKABLE void playNextAndPlay(const SongInfo &song);
    Q_INVOKABLE void playNextAndPlay(const QVariantMap &songMap);
    Q_INVOKABLE void addSongNext(const SongInfo &song);
    Q_INVOKABLE void addSongNext(const QVariantMap &songMap);
    Q_INVOKABLE void playPlaylistFromSource(
        const QString &sourceId, int totalCount, int startIndexInSource, const QVariantList &firstBatch
    );
    Q_INVOKABLE void requestMoreSourceTracks(); // 弹窗滚动按需加载下一批（不受播放邻近守卫限制）
    Q_INVOKABLE void setposistion(float positionvalue);
    Q_INVOKABLE void fetchClimax(const QString &hash);  // 高潮段：按 hash 去重请求，结果存 climaxPercent
    Q_INVOKABLE void setVolume(qreal v);  // 音量 0~1（持久化；停 fade 动画后立即生效）

    int currentIndex() const;
    QString currentTitle() const;
    QString currentsingername() const;
    QString currentSongHash() const;
    bool isPaused() const;
    QString union_cover() const;
    QString dominantColor() const;
    float getpercent() const;
    QString getpercentstr() const;
    QString durationstr();
    qreal climaxPercent() const { return m_climaxPercent; }
    qreal volume() const { return m_audioOutput ? m_audioOutput->volume() : 0.0; }
    qint64 playerDuration() const;
    SongListModel *playlistModel();
    QList<SongInfo> playlist();
    SongListModel *togetherplaylistModel();
    QList<SongInfo> togetherplaylist();
    SongListModel *recentPlaylistModel();
    QList<SongInfo> recentPlaylist() const;
    void addToRecent(const SongInfo &song);
    void clearTogetherSongHash();
    int playlistcount() const;
    int playlistTotalCount() const;
    QString getcurrlyric() const;
    enum PlaylistType getplaylist_type() const;
    void changeplaylisttype(enum PlaylistType type);
    int is_have_cache(const SongInfo &song, const int index);

    // 一起听模式同步方法
    void syncTogetherPlaylistFromServer(const QJsonArray &songs);
    void playTogetherSongFromServer(
        const QString &songUrl, const QString &songName, const QString &songHash, const QString &singerName,
        const QString &coverUrl, const QString &albumName, const QString &duration
    );
    void seekToPercent(double percent);
    void setPaused(bool paused);
    void setTogetherSeekPercent(double percent);
    double togetherSeekPercent() const;
    // 一起听：本地暂停/恢复只影响本机，不向服务器发送指令。
    // 服务器播放广播在 localPaused() 为 true 时不会恢复播放，直到用户手动播放。
    void pauseLocal();
    bool localPaused() const;
    void clearLocalPaused();
    Q_INVOKABLE void loadPlaylistFromCache();
    void savePlaylistToCache();
    void saveRecentToCache();
    void loadRecentFromCache();
    Q_INVOKABLE void restoreLastPlayback();
    void saveLyricToCache(const QString &songhash, const QString &lyric);
    QString loadLyricFromCache(const QString &songhash);
    QVector<LyricLine> LyricLine_get() const;
    int lyricCharIndexget();
    float lyricCharProgressget();
    QVariantList lyricCharsget();
    int lyricCharCountget();
    int lyricOffsetMs() const;
    Q_INVOKABLE void adjustLyricOffset(int deltaMs); // 每次 ±250ms 微调歌词显示时间
    Q_INVOKABLE void resetLyricOffset();             // 偏移归零
    qreal downloadProgress() const;
    bool isBuffering() const;

signals:
    void currentIndexChanged(int index);
    void playlistUpdated();
    void playbackFinished();
    void isPausedChanged();
    void currentSongChanged();
    void percentChanged();
    void durationChanged();
    void currlyricChanged();
    void lyricOffsetChanged();
    void playlist_typeChanged();
    void togetherplaylistUpdated();
    void recentPlaylistUpdated();
    void parlyricsuc();
    void dominantColorChanged();
    void downloadProgressChanged();
    void isBufferingChanged();
    void uiIdleChanged();
    void climaxPercentChanged();
    void volumeChanged();
    void songUrlFailed(const QString &reason);  // 拿不到播放地址(共享号失效/网络异常)
    void playModeChanged();
    void playbackPositionChanged(qint64 position);  // 播放进度（毫秒）：外部用于 30 秒听歌上报等
    void qualityChanged();

private:
    enum PlaylistType type = LOCAL;
    QList<SongInfo> m_playlist;
    QList<SongInfo> m_togetherplaylist;
    QList<SongInfo> m_recentPlaylist;
    // QML 视图 model：与上面三个 QList 同步，供 QML ListView 直接绑定
    SongListModel *m_playlistModel;
    SongListModel *m_togetherplaylistModel;
    SongListModel *m_recentPlaylistModel;
    static const int MAX_RECENT_SIZE = 300;
    QList<SongInfo> *m_curplaylist   = &m_playlist;
    int m_currentIndex               = -1;
    bool m_isPaused                  = true;
    // 一起听：本地主动暂停标记（播放键/媒体键/拔耳机），服务器播放广播不覆盖
    bool m_localPaused               = false;
    LyricParser m_lyricParser;
    qint64 lyricsindexget();
    QMediaPlayer *m_player      = new QMediaPlayer(this);
    QAudioOutput *m_audioOutput = new QAudioOutput(this);
    void startPlayback(const SongInfo &song);
    void fetchSongUrl(const QString &hash, std::function<void(QString)> callback,
                      bool keepIntegrityCount = false);
    // 音质解析取址（借鉴 MoeKoe）：/privilege/lite 拿该曲各音质专属 hash（同一首歌
    // 不同音质 hash 不同），按当前档位从高到低逐档试 /song/url，跳过无 URL/mp4 档
    void resolvePrivilegeThenFetch(const QString &hash, std::function<void(QString)> callback);
    void trySongUrlCandidates(const QString &songHash, const QVector<QPair<QString, QString>> &candidates, int idx,
                              std::function<void(QString)> callback);
    void handleSongUrlFailed(const QString &hash, const QString &reason);  // 拿不到 url:停 loading+提示;本地模式自动跳下一首(连败达上限则停),一起听只暂停
    float m_percent      = 0.0;
    QString m_percentstr = "00:00";
    // 音量淡入/淡出：切歌/恢复渐强、暂停/自然结束前渐弱，各 1.5s
    qreal m_targetVolume                            = 1.0;
    QPropertyAnimation *m_volAnim                   = nullptr;
    QMediaPlayer::PlaybackState m_prevPlaybackState = QMediaPlayer::StoppedState;
    bool m_endFadeStarted                           = false;
    void fadeInVolume(); // 0 -> 目标音量（1.5s）
    void fadeOutVolume(int ms, std::function<void()> onFinished);
    QString m_duration = "00:00";
    // 音质切换续播：setQuality 换源时记录当前进度，startPlayback 新源就绪后 seek 到该位置（-1 = 无续播）
    float m_resumePercentAfterSwitch = -1.0f;
    void updatePlaybackProgress(qint64 position);
    // 逐字进度刷新：本地文件播放 positionChanged 实测仅 ~11Hz（无损缓存）、网络流 ~20Hz，
    // 不足以驱动 60fps 动画——16ms 定时器按真实播放位置重算补足。渲染已优化
    // （三文本方案每帧仅 2 个几何节点），60Hz 通知无压力；隐藏歌词页 Connections 关闭
    void updateLyricProgress(qint64 position);
    QTimer m_lyricAnimTimer;
    // 歌词动画消费方可见性（QML 上报）：决定 16ms 定时器跑不跑/跑多快
    bool m_playingPageLyricsActive = false;
    bool m_desktopLyricsActive     = false;
    int m_lyricFeedHz              = 0; // 当前实际刷新频率：60=任一歌词消费方可见 / 0=停
    bool m_uiIdle                  = false; // 窗口被遮蔽/应用失焦（QML 同步）：停进度条 UI 发射
    void recomputeLyricFeed();
    void handlePlayerError(QMediaPlayer::Error error, const QString &errorString);
    QString formatTime(qint64 milliseconds);
    Recommendation *m_recommendation = nullptr;
    QString m_currentTogetherSongHash;
    QList<SongInfo> convertToSongInfoList(const QVariantList &variantList);
    static SongInfo songFromMap(const QVariantMap &map);
    void doAddSong(const SongInfo &song, bool toHead, bool playNow);
    bool m_isRepairing            = false;
    float m_restorePercent        = -1.0f;
    int m_repairCount             = 0;
    int m_urlFailStreak           = 0;  // 连续取 URL 失败计数：自动跳下一首的全队死循环保护
    int m_localIndex              = -1;   // 一起听模式前保存的本地播放索引
    float m_localPercent          = 0.0f; // 一起听模式前保存的本地播放进度
    const int MAX_REPAIR_ATTEMPTS = 5;
    // 播放源未就绪时用户点了播放：等 source 就绪（LoadedMedia）后自动续播
    bool m_pendingPlayWhenReady = false;
    // percentChanged 限频（本地文件 positionChanged 可达 80Hz+，进度条 30fps 足够）
    qint64 m_lastPercentNotifyMs = 0;
    // position 值外推：flac 音频帧 4096 采样（≈92ms）导致 position 值阶梯步进，
    // 阶梯间隙按真实时间外推——跳跃歌词动画因此平滑（mp3 帧 26ms 无此问题）
    qint64 m_lastRawPosMs  = 0;
    qint64 m_lastRawTickMs = 0;
    // 懒加载队列源
    QString m_lazySourceId; // 源歌单 id（空 = 非懒加载模式）
    int m_lazyTotal             = 0;
    int m_lazyPage              = 0;
    // 与页面侧 detailPageSize(300) 对齐：双击建队后按需补拉的单页大小；
    // 30/页时几百首的歌单补齐要连发几十个小请求，对风控不友好
    int m_lazyPageSize          = 300;
    QSet<QString> m_lazySeenHashes; // 队列内已有歌曲 hash：补拉跨页重叠时去重
    bool m_lazyFetching         = false;
    bool m_pendingNextAfterLoad = false; // 到已加载末尾点下一首时，等下一批到位后续播
    void tryLazyLoadMore();              // 接近队列末尾时自动拉下一批
    void fetchNextSourcePage();          // 拉取下一页源数据并 append 到队列（供上面两个入口共用）
    void fetchLyricData(const QString &hash, std::function<void(QString)> callback);
    void fetchLyricContent(const QString &id, const QString &accesskey, std::function<void(QString)> callback);
    // 边下边播共享逻辑：下载 songUrl 到 cacheFilePath，达到阈值后开始播放。
    // seekPercent > 0 时在 LoadedMedia 后 seek；onStreamStart 在首次开播时调用
    // （startPlayback 用于 emit currentSongChanged，一起听路径不需要）。
    // 抽出以消除 startPlayback 与 playTogetherSongFromServer 的重复下载代码。
    void downloadAndStream(
        const QString &songUrl, const QString &songHash, const QString &cacheFilePath, const QString &coverUrlForColor,
        double seekPercent, std::function<void()> onStreamStart
    );
    QString currlyric         = "网狗音乐！";
    QString m_dominantColor   = "#FF6B6B";
    int m_lyricCharIndex      = -1;
    float m_lyricCharProgress = 0.0f;
    QVariantList m_lyricChars;
    int m_lyricCharCount         = 0;
    qint64 m_lyricOffsetMs       = 0; // 歌词偏移（毫秒，正值=歌词提前显示）；按歌生效，切歌归零
    QString m_lyricOffsetSongHash;    // 当前偏移所属歌曲（用于切歌时自动归零）
    double m_togetherSeekPercent = 0;
    qreal m_downloadProgress     = 1.0; // 下载进度 0~1，默认1表示已就绪
    int m_playMode               = MODE_ORDER;
    bool m_isBuffering           = false;
    int m_quality                = 0;  // 音质档位（0自动/1标准128/2高品320/3无损flac），QSettings 持久化
    QSettings m_settings{"WangGouMusic", "UserConfig"};
    qint64 m_downloadedBytes     = 0;
    qint64 m_totalDownloadBytes  = 0;
    // 缓存目录访问（转发到 PlaylistCacheStore，保留供内部使用）
    QString getCacheDir() const;

    // 正在下载的缓存文件路径：app 退出时进程中断下载会留下半截 flac，
    // 下次播放 probe 失败（0 channels 无声音）——析构时删除它们
    QSet<QString> m_activeDownloadFiles;
    // 同路径下载代际：重新触发同路径下载时递增，旧下载回调据此静默退出，
    // 避免旧回调的校验/删除逻辑误伤新下载正在写的文件
    QHash<QString, qint64> m_downloadGen;
    // 播放前 MD5 校验失败时刻：同曲 5 分钟冷却，防止个别目录级异常导致反复重下
    QHash<QString, qint64> m_md5FailAtMs;
    // 下载完整性失败连续计数（hash 大写）：同曲最多自动重下 2 次，仍失败则放弃；
    // 用户重新点播（fetchSongUrl 非 retry 链入口）自动清零
    QHash<QString, int> m_integrityFailCount;
    /// 播放缓存前的完整性校验：酷狗歌曲 hash 即对应音质文件的 MD5（实测），
    /// 本地文件算出的 MD5 与之不符 = 损坏。返回 false = 应删除重新下载
    bool verifyCachedFileMd5(const QString &filePath, const QString &songhash);
    // 取歌接口（song/url）返回的期望文件字节数与内容 MD5（酷狗 hash 即该音质文件的 MD5，
    // 已实测验证）：downloadAndStream 进入时消费一次，下载完成时做完整性校验
    qint64 m_pendingFileSize = 0;
    QString m_pendingFileMd5;
    // 音质解析缓存（歌曲 hash 大写 -> [音质档, 该音质文件专属 hash]，会话内有效）：
    // /privilege/lite 每曲只打一次，重播/重试链不再重复请求
    QHash<QString, QVector<QPair<QString, QString>>> m_privilegeCache;
    // 本会话内各缓存路径对应的期望 MD5（取址响应 hash = 该音质实际下发文件的 MD5，实测全音质成立）：
    // 播放前校验优先比对它，无期望时才退回歌单 hash（仅 128 口味可比）
    QHash<QString, QString> m_sessionFileMd5;

    // 主色调提取（独立模块）：异步后台线程 + 内存 LRU 缓存
    DominantColorExtractor *m_colorExtractor;

    // 高潮段：切歌按 hash 去重请求，避免多组件（底栏/播放页 ClimaxDot）重复打 /song/climax
    qreal m_climaxPercent = 0;
    QString m_climaxHash;       // 正在请求的 hash（去重 + 迟到响应核对）
    bool m_climaxPending = false; // 该 hash 的 climax 请求在途：LoadedMedia 补请求避让竞态
    void setClimaxPercent(qreal p);
    // 高潮点本地缓存（hash.toUpper() -> start_time 毫秒，0 = 服务端确认无高潮）：
    // 同一首歌高潮位置不变，重播直接换算不再请求；存原始 ms 而非百分比，
    // 每次按当前时长换算，兼容流媒体/缓存文件时长差异
    QHash<QString, qint64> m_climaxCache;
    bool m_climaxCacheLoaded = false;
    void loadClimaxCache();
    void saveClimaxCacheEntry(const QString &hash, qint64 startMs);
    static qint64 parseDurationMs(const QString &str);  // "mm:ss"/秒 → 毫秒

    // 歌词去重：同 hash 并发请求合并为一次（多调用点/组件触发同一首歌）
    QSet<QString> m_lyricPendingHashes;
    QHash<QString, QVector<std::function<void(QString)>>> m_lyricPendingCallbacks;
};

#endif // PLAYLISTMANAGER_H
