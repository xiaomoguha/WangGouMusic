#ifndef SONG_INFO_H
#define SONG_INFO_H

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

public:
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
};

#endif // SONG_INFO_H
