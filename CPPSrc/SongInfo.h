#ifndef SONG_INFO_H
#define SONG_INFO_H

#include <QJsonObject>
#include <QObject>
#include <QString>

/**
 * @brief 歌曲信息结构（Q_GADGET，可在 QML 中作为值类型访问）
 *
 * 从 playlistmanager.h 提取到独立头，供 SongListModel / PlaylistManager /
 * PlaylistCacheStore 共享，避免循环 include。
 */
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
    // 评论用 album_audio_id：一起听广播由服务器解析下发；其余场景见下面的登记表
    Q_PROPERTY(QString mxid MEMBER mxid)

public:
    /// 从接口返回的歌曲对象里取 album_audio_id（= 评论接口要的 mixsongid）。
    /// 各接口字段位置不统一（顶层 album_audio_id / 顶层 mixsongid /
    /// audio_info.album_audio_id / base.album_audio_id），统一在这里兜住，取不到返回空串。
    static QString mxidFromJson(const QJsonObject &songObj);

    /// 解析并登记 hash→mxid。歌曲列表（搜索/排行/歌单/每日推荐/FM/专辑/歌手…）解析时
    /// 顺手调一次，之后这首歌播放、拉评论就能直接拿到 id，不必再去搜索或查接口。
    static void rememberMxidFromJson(const QJsonObject &songObj, const QString &hash);

    /// 取已登记的 mxid（键不分大小写）；没登记过返回空串
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
};

#endif // SONG_INFO_H
