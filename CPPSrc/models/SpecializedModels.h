#ifndef SPECIALIZED_MODELS_H
#define SPECIALIZED_MODELS_H

#include "VariantMapListModel.h"

/**
 * @brief 聊天消息 model（websocket.messages）
 * 字段：type, status, avatar_url, avatarUrl, nickname, userid, message, time, _msgId
 * 注意 avatar_url（action 历史）与 avatarUrl（chat）并存，QML 按消息 type 各取所需。
 */
class ChatMessageModel : public VariantMapListModel
{
    Q_OBJECT
public:
    explicit ChatMessageModel(QObject *parent = nullptr)
        : VariantMapListModel(parent)
    {
        setRoleNames({"type", "status", "avatar_url", "avatarUrl", "nickname",
                      "userid", "message", "time", "_msgId"});
    }
};

/**
 * @brief 房间列表 model（websocket.roomList）
 * 字段全下划线命名（直接转发远程 JSON）：room_id, cover_url, current_song,
 * singername, member_count
 */
class RoomListModel : public VariantMapListModel
{
    Q_OBJECT
public:
    explicit RoomListModel(QObject *parent = nullptr)
        : VariantMapListModel(parent)
    {
        setRoleNames({"room_id", "cover_url", "current_song", "singername", "member_count"});
    }
};

/**
 * @brief 热搜词 model（hostSearch.items）
 * 单字段：keyword
 */
class HotSearchModel : public VariantMapListModel
{
    Q_OBJECT
public:
    explicit HotSearchModel(QObject *parent = nullptr)
        : VariantMapListModel(parent)
    {
        setRoleNames({"keyword"});
    }
};

/**
 * @brief 歌曲（QVariantMap 形态）model
 * 供 complexsearch.items / recommendation.topSongsQml / recommendation.playlistTracksQml 复用。
 * 字段：songname, singername, songhash, union_cover, album_name, duration
 */
class SongMapModel : public VariantMapListModel
{
    Q_OBJECT
public:
    explicit SongMapModel(QObject *parent = nullptr)
        : VariantMapListModel(parent)
    {
        setRoleNames({"songname", "singername", "songhash", "union_cover",
                      "album_name", "duration"});
    }
};

/**
 * @brief 歌单信息 model（recommendation.topPlaylistsQml）
 * 字段：specialname, imgurl, intro, play_count, global_collection_id, tags
 */
class PlaylistInfoModel : public VariantMapListModel
{
    Q_OBJECT
public:
    explicit PlaylistInfoModel(QObject *parent = nullptr)
        : VariantMapListModel(parent)
    {
        setRoleNames({"specialname", "imgurl", "intro", "play_count",
                      "global_collection_id", "tags"});
    }
};

#endif // SPECIALIZED_MODELS_H
