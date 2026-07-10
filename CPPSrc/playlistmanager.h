#ifndef PLAYLISTMANAGER_H
#define PLAYLISTMANAGER_H
#include "lyricparser.h"
#include "SongInfo.h"
#include "models/SongListModel.h"
#include <QObject>
#include <functional>
#include <QHash>
#include <QList>
#include <QSet>
#include <QString>
#include <QMediaPlayer>
#include <QNetworkAccessManager>
#include <QObject>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QAudioOutput>
#include <QTime>
#include <QFileInfo>
#include <QStandardPaths>
#include <QDir>
#include <QImage>
#include <QColor>
#include <QNetworkRequest>
#include "recommendation.h"

class DominantColorExtractor;

enum playlist_type
{
    LOCAL,
    TOGETHER
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
    Q_PROPERTY(QString duration READ durationstr NOTIFY durationChanged)
    Q_PROPERTY(SongListModel* playlist READ playlistModel NOTIFY playlistUpdated)
    Q_PROPERTY(int playlistcount READ playlistcount NOTIFY playlistUpdated)
    Q_PROPERTY(int playlistTotalCount READ playlistTotalCount NOTIFY playlistUpdated)
    Q_PROPERTY(QString currlyric READ getcurrlyric NOTIFY currlyricChanged)
    Q_PROPERTY(enum playlist_type type READ getplaylist_type NOTIFY playlist_typeChanged)
    Q_PROPERTY(SongListModel* togetherplaylist READ togetherplaylistModel NOTIFY togetherplaylistUpdated)
    Q_PROPERTY(SongListModel* recentPlaylist READ recentPlaylistModel NOTIFY recentPlaylistUpdated)
    Q_PROPERTY(QVector<LyricLine> m_lyrics READ LyricLine_get NOTIFY parlyricsuc)
    Q_PROPERTY(qint64 lyricsindex READ lyricsindexget NOTIFY currlyricChanged)
    Q_PROPERTY(int lyricCharIndex READ lyricCharIndexget NOTIFY currlyricChanged)
    Q_PROPERTY(float lyricCharProgress READ lyricCharProgressget NOTIFY currlyricChanged)
    Q_PROPERTY(QVariantList lyricChars READ lyricCharsget NOTIFY currlyricChanged)
    Q_PROPERTY(int lyricCharCount READ lyricCharCountget NOTIFY currlyricChanged)
    Q_PROPERTY(qreal downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool isBuffering READ isBuffering NOTIFY isBufferingChanged)
public:
    explicit PlaylistManager(Recommendation *recommendation, QObject *parent = nullptr);
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
    Q_INVOKABLE void playNextAndPlay(const SongInfo &song);
    Q_INVOKABLE void playNextAndPlay(const QVariantMap &songMap);
    Q_INVOKABLE void addSongNext(const SongInfo &song);
    Q_INVOKABLE void addSongNext(const QVariantMap &songMap);
    Q_INVOKABLE void playPlaylistFromSource(const QString &sourceId, int totalCount, int startIndexInSource, const QVariantList &firstBatch);
    Q_INVOKABLE void requestMoreSourceTracks();   // 弹窗滚动按需加载下一批（不受播放邻近守卫限制）
    Q_INVOKABLE void setposistion(float positionvalue);

    int currentIndex() const;
    QString currentTitle() const;
    QString currentsingername() const;
    QString currentSongHash() const;
    int count() const;
    bool isPaused() const;
    QString union_cover() const;
    QString dominantColor() const;
    float getpercent() const;
    QString getpercentstr() const;
    QString durationstr();
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
    enum playlist_type getplaylist_type() const;
    void changeplaylisttype(enum playlist_type type);
    int is_have_cache(const SongInfo &song, const int index);

    // 一起听模式同步方法
    void syncTogetherPlaylistFromServer(const QJsonArray &songs);
    void playTogetherSongFromServer(const QString &songUrl, const QString &songName,
                                     const QString &songHash, const QString &singerName,
                                     const QString &coverUrl, const QString &albumName,
                                     const QString &duration);
    void seekToPercent(double percent);
    void setPaused(bool paused);
    void setTogetherSeekPercent(double percent);
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
    void playlist_typeChanged();
    void togetherplaylistUpdated();
    void recentPlaylistUpdated();
    void parlyricsuc();
    void dominantColorChanged();
    void downloadProgressChanged();
    void isBufferingChanged();

public slots:
    void parselyricsuc();

private:
    enum playlist_type type = LOCAL;
    QList<SongInfo> m_playlist;
    QList<SongInfo> m_togetherplaylist;
    QList<SongInfo> m_recentPlaylist;
    // QML 视图 model：与上面三个 QList 同步，供 QML ListView 直接绑定
    SongListModel *m_playlistModel;
    SongListModel *m_togetherplaylistModel;
    SongListModel *m_recentPlaylistModel;
    static const int MAX_RECENT_SIZE = 300;
    QList<SongInfo> *m_curplaylist = &m_playlist;
    int m_currentIndex = -1;
    bool m_isPaused = true;
    LyricParser lyricParser;
    qint64 lyricsindexget();
    QMediaPlayer *player = new QMediaPlayer(this);
    QAudioOutput *audioOutput = new QAudioOutput(this);
    void startPlayback(const SongInfo &song);
    void fetchSongUrl(const QString &hash, std::function<void(QString)> callback);
    void showplaylist();
    float m_percent = 0.0;
    QString m_percentstr = "00:00";
    QString m_duration = "00:00";
    void updatePlaybackProgress(qint64 position);
    void handlePlayerError(QMediaPlayer::Error error, const QString &errorString);
    QString formatTime(qint64 milliseconds);
    Recommendation *m_recommendation = nullptr; // 改为指针
    QString m_currentTogetherSongHash;
    QList<SongInfo> convertToSongInfoList(const QVariantList &variantList);
    static SongInfo songFromMap(const QVariantMap &map);
    void doAddSong(const SongInfo &song, bool toHead, bool playNow);
    bool m_isRepairing = false;        // 添加修复状态标志
    float m_restorePercent = -1.0f;
    int m_repairCount = 0;             // 修复次数计数
    int m_localIndex = -1;             // 一起听模式前保存的本地播放索引
    float m_localPercent = 0.0f;       // 一起听模式前保存的本地播放进度
    const int MAX_REPAIR_ATTEMPTS = 5; // 最大修复尝试次数
    // 懒加载队列源
    QString m_lazySourceId;            // 源歌单 id（空 = 非懒加载模式）
    int m_lazyTotal = 0;               // 源歌单总数
    int m_lazyPage = 0;                // 已加载到第几页
    int m_lazyPageSize = 30;
    bool m_lazyFetching = false;       // 是否正在拉取下一批
    bool m_pendingNextAfterLoad = false; // 到已加载末尾点下一首时，等下一批到位后续播
    void tryLazyLoadMore();            // 接近队列末尾时自动拉下一批
    void fetchNextSourcePage();        // 拉取下一页源数据并 append 到队列（供上面两个入口共用）
    void fetchLyricData(const QString &hash, std::function<void(QString)> callback);
    void fetchLyricContent(const QString &id, const QString &accesskey, std::function<void(QString)> callback);
    // 边下边播共享逻辑：下载 songUrl 到 cacheFilePath，达到阈值后开始播放。
    // seekPercent > 0 时在 LoadedMedia 后 seek；onStreamStart 在首次开播时调用
    // （startPlayback 用于 emit currentSongChanged，一起听路径不需要）。
    // 抽出以消除 startPlayback 与 playTogetherSongFromServer 的重复下载代码。
    void downloadAndStream(const QString &songUrl, const QString &cacheFilePath,
                           const QString &coverUrlForColor, double seekPercent,
                           std::function<void()> onStreamStart);
    QString currlyric = "网狗音乐！";
    QString m_dominantColor = "#FF6B6B";
    int m_lyricCharIndex = -1;
    float m_lyricCharProgress = 0.0f;
    QVariantList m_lyricChars;
    int m_lyricCharCount = 0;
    double m_togetherSeekPercent = 0;
    qreal m_downloadProgress = 1.0;    // 下载进度 0~1，默认1表示已就绪
    bool m_isBuffering = false;
    qint64 m_downloadedBytes = 0;
    qint64 m_totalDownloadBytes = 0;
    // 缓存目录访问（转发到 PlaylistCacheStore，保留供内部使用）
    QString getCacheDir() const;

    // 主色调提取（独立模块）：异步后台线程 + 内存 LRU 缓存
    DominantColorExtractor *m_colorExtractor;
};

#endif // PLAYLISTMANAGER_H
