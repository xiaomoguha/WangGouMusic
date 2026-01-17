#ifndef PLAYLISTMANAGER_H
#define PLAYLISTMANAGER_H
#include "lyricparser.h"
#include <QObject>
#include <QList>
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
#include "recommendation.h"
struct SongInfo
{
    Q_GADGET  // 使结构体能被 Qt 元系统识别
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString songhash MEMBER songhash)
    Q_PROPERTY(QString url MEMBER url)
    Q_PROPERTY(QString singername MEMBER singername)
    Q_PROPERTY(QString union_cover MEMBER union_cover)
    Q_PROPERTY(QString album_name MEMBER album_name)
    Q_PROPERTY(QString duration MEMBER duration)
    Q_PROPERTY(QString lyric MEMBER lyric)

public:
    QString title;
    QString songhash;
    QString url;
    QString singername;
    QString union_cover;
    QString album_name;
    QString duration;
    QString lyric;
};
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
    Q_PROPERTY(float percent READ getpercent NOTIFY percentChanged)
    Q_PROPERTY(QString percentstr READ getpercentstr NOTIFY percentChanged)
    Q_PROPERTY(QString duration READ durationstr NOTIFY durationChanged)
    Q_PROPERTY(QList<SongInfo> playlist READ playlist NOTIFY playlistUpdated)
    Q_PROPERTY(int playlistcount READ playlistcount NOTIFY playlistUpdated)
    Q_PROPERTY(QString currlyric READ getcurrlyric NOTIFY currlyricChanged)
    Q_PROPERTY(enum playlist_type type READ getplaylist_type NOTIFY playlist_typeChanged)
    Q_PROPERTY(QList<SongInfo> togetherplaylist READ togetherplaylist NOTIFY togetherplaylistUpdated)
    Q_PROPERTY(QVector<LyricLine> m_lyrics READ LyricLine_get NOTIFY parlyricsuc)
    Q_PROPERTY(qint64 lyricsindex READ lyricsindexget NOTIFY currlyricChanged)
public:
    explicit PlaylistManager(Recommendation *recommendation,QObject *parent = nullptr);
    Q_INVOKABLE void addSong(const QString &title,const QString &songhash,const QString &singername,const QString &union_cover,const QString &album_name,const QString &duration);
    Q_INVOKABLE void removeSong(int index);
    Q_INVOKABLE void playSongbyhasg(const QString &songhash);
    Q_INVOKABLE void playSongbyindex(int index);
    Q_INVOKABLE void playNext();
    Q_INVOKABLE void playPrevious();
    Q_INVOKABLE void playstop();
    Q_INVOKABLE void addandplay(const QString &title, const QString &url,const QString &singername,const QString &union_cover,const QString &album_name,const QString &duration);
    Q_INVOKABLE void setposistion(float positionvalue);

    int currentIndex() const;
    QString currentTitle() const;
    QString currentsingername() const;
    QString currentSongHash() const;
    int count() const;
    bool isPaused() const;
    QString union_cover() const;
    float getpercent() const;
    QString getpercentstr() const;
    QString durationstr();
    QList<SongInfo> playlist();
    QList<SongInfo> togetherplaylist();
    int playlistcount() const;
    int getnowplaylistrange() const;
    QString getcurrlyric() const;
    enum playlist_type getplaylist_type() const;
    void changeplaylisttype(enum playlist_type type);
    int is_have_cache(const SongInfo &song,const int index);
    QVector<LyricLine> LyricLine_get() const;

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
    void parlyricsuc();

public slots:
    void parselyricsuc();


private:
    enum playlist_type type = LOCAL;
    QList<SongInfo> m_playlist;
    QList<SongInfo> m_togetherplaylist;
    QList<SongInfo> *m_curplaylist = &m_playlist;
    int m_currentIndex = -1;
    bool m_isPaused = true;
    LyricParser lyricParser;
    qint64 lyricsindexget();
    QMediaPlayer *player = new QMediaPlayer(this);
    QAudioOutput *audioOutput = new QAudioOutput(this);
    void startPlayback(const SongInfo &song);
    void fetchSongUrl(const QString &hash, std::function<void(QString)> callback);
    QNetworkAccessManager m_networkManager;
    void showplaylist();
    float m_percent = 0.0;
    QString m_percentstr ="00:00";
    QString m_duration = "00:00";
    void updatePlaybackProgress(qint64 position);
    void handlePlayerError(QMediaPlayer::Error error, const QString &errorString) ;
    QString formatTime(qint64 milliseconds);
    Recommendation *m_recommendation = nullptr;  // 改为指针
    QList<SongInfo> convertToSongInfoList(const QVariantList &variantList);
    bool m_isRepairing = false; // 添加修复状态标志
    int m_repairCount = 0;      // 修复次数计数
    const int MAX_REPAIR_ATTEMPTS = 5; // 最大修复尝试次数
    void fetchLyricData(const QString &hash, std::function<void(QString)> callback);
    void fetchLyricContent(const QString &id, const QString &accesskey, std::function<void(QString)> callback);
    QString currlyric = "网狗音乐！";
};
Q_DECLARE_METATYPE(SongInfo)


#endif // PLAYLISTMANAGER_H
