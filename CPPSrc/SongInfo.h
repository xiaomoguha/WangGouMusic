#ifndef SONG_INFO_H
#define SONG_INFO_H

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QStringList>

// 歌曲信息结构（Q_GADGET，可在 QML 中作为值类型访问）
struct SongInfo
{
    Q_GADGET
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString songhash MEMBER songhash)
    Q_PROPERTY(QString url MEMBER url)
    Q_PROPERTY(QString singername MEMBER singername)
    Q_PROPERTY(QString union_cover MEMBER union_cover)
    Q_PROPERTY(QString album_name MEMBER album_name)
    Q_PROPERTY(QString duration MEMBER duration)
    Q_PROPERTY(QString lyric MEMBER lyric)
    Q_PROPERTY(QString added_by_nickname MEMBER added_by_nickname)
    Q_PROPERTY(QString added_by_avatar MEMBER added_by_avatar)
    // 歌单内歌曲标识（删歌用）：仅歌单 track/all 数据源填充，其他场景为空
    Q_PROPERTY(QString fileid MEMBER fileid)
    // MV 播放 hash（mvhash）：仅含 MV 的歌曲有值，歌单/搜索数据源填充
    Q_PROPERTY(QString mvhash MEMBER mvhash)
    // 个人FM 30秒模式的高潮片段起止（毫秒）
    Q_PROPERTY(double peakStartMs MEMBER peakStartMs)
    Q_PROPERTY(double peakEndMs MEMBER peakEndMs)
    // 评论用 album_audio_id：一起听广播由服务器解析下发；其余场景见下面的登记表
    Q_PROPERTY(QString mxid MEMBER mxid)
    // 一起听房间内共享点赞：like_count 总数，liked_by 点赞用户 id 列表
    Q_PROPERTY(int like_count MEMBER like_count)
    Q_PROPERTY(QStringList liked_by MEMBER liked_by)
    Q_PROPERTY(QString recommend_source MEMBER recommend_source)

public:
    // 从接口返回的歌曲对象里取 album_audio_id（= 评论接口要的 mixsongid）。
    static QString mxidFromJson(const QJsonObject &songObj);

    // 解析并登记 hash→mxid。歌曲列表（搜索/排行/歌单/每日推荐/FM/专辑/歌手…）解析时
    // 顺手调一次，之后这首歌播放、拉评论就能直接拿到 id，不必再去搜索或查接口。
    static void rememberMxidFromJson(const QJsonObject &songObj, const QString &hash);

    // 取已登记的 mxid（键不分大小写）；没登记过返回空串
    static QString cachedMxid(const QString &hash);

    QString title;
    QString songhash;
    QString url;
    QString singername;
    QString union_cover;
    QString album_name;
    QString duration;
    QString lyric;
    QString added_by_nickname;
    QString added_by_avatar;
    QString fileid;
    QString mvhash;
    QString mxid;
    int like_count = 0;
    QStringList liked_by;
    QString recommend_source;
    qint64 peakStartMs = 0;
    qint64 peakEndMs   = 0;
};

#endif // SONG_INFO_H
