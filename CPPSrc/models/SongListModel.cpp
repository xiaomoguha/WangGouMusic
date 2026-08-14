#include "SongListModel.h"

SongListModel::SongListModel(QObject *parent) : QAbstractListModel(parent) {}

int SongListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_songs.size();
}

QVariant SongListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_songs.size())
        return {};
    const SongInfo &song = m_songs.at(index.row());
    // Qt::DisplayRole 返回整行 QVariantMap，供 Repeater 的 required property var
    // modelData 拿到完整行数据（QAbstractListModel 在 Repeater 里 modelData 绑定
    // DisplayRole；ListView delegate 则用 model.title 等 role 访问，互不影响）。
    if (role == Qt::DisplayRole)
        return get(index.row());
    switch (role)
    {
    case TitleRole:
        return song.title;
    case SongHashRole:
        return song.songhash;
    case UrlRole:
        return song.url;
    case SingerNameRole:
        return song.singername;
    case UnionCoverRole:
        return song.union_cover;
    case AlbumNameRole:
        return song.album_name;
    case DurationRole:
        return song.duration;
    case LyricRole:
        return song.lyric;
    case AddedByNicknameRole:
        return song.added_by_nickname;
    case AddedByAvatarRole:
        return song.added_by_avatar;
    case FileIdRole:
        return song.fileid;
    case MvHashRole:
        return song.mvhash;
    }
    return {};
}

QHash<int, QByteArray> SongListModel::roleNames() const
{
    // role 名与 SongInfo 的 Q_PROPERTY 字段名完全一致，
    // QML 端 model.title / model.songhash 等访问方式不变
    return {
        {TitleRole, "title"},
        {SongHashRole, "songhash"},
        {UrlRole, "url"},
        {SingerNameRole, "singername"},
        {UnionCoverRole, "union_cover"},
        {AlbumNameRole, "album_name"},
        {DurationRole, "duration"},
        {LyricRole, "lyric"},
        {AddedByNicknameRole, "added_by_nickname"},
        {AddedByAvatarRole, "added_by_avatar"},
        {FileIdRole, "fileid"},
        {MvHashRole, "mvhash"},
    };
}

// 供 QML JS 迭代：返回某行的 QVariantMap，字段名与 Q_PROPERTY 一致
QVariant SongListModel::get(int index) const
{
    if (index < 0 || index >= m_songs.size())
        return {};
    const SongInfo &s = m_songs.at(index);
    QVariantMap m;
    m["title"]             = s.title;
    m["songname"]          = s.title;   // 别名：部分 delegate 走 modelData.songname（DisplayRole map）
    m["songhash"]          = s.songhash;
    m["url"]               = s.url;
    m["singername"]        = s.singername;
    m["union_cover"]       = s.union_cover;
    m["album_name"]        = s.album_name;
    m["duration"]          = s.duration;
    m["lyric"]             = s.lyric;
    m["added_by_nickname"] = s.added_by_nickname;
    m["added_by_avatar"]   = s.added_by_avatar;
    m["fileid"]            = s.fileid;
    m["mvhash"]            = s.mvhash;
    return m;
}

// ── 数据操作 ──

void SongListModel::syncFromList(const QList<SongInfo> &songs)
{
    // 增量对齐：以 songhash 为主键尽量复用已有行，避免全量 reset 让 ListView
    // 销毁重建所有 delegate（一起听列表 delegate 含 ColorOverlay 等重效果，
    // 全量重建会卡住主线程、阻塞音频渲染 —— 别人加歌时接收方放歌卡一下的根因）。
    int common = 0;
    while (common < m_songs.size() && common < songs.size()
           && m_songs[common].songhash == songs[common].songhash)
        ++common;
    // 旧列表是新列表的前缀：末尾追加了若干首（=别人加歌），或完全相同（切歌/进度广播）
    if (common == m_songs.size() && songs.size() >= m_songs.size())
    {
        if (songs.size() > m_songs.size())
        {
            QList<SongInfo> tail;
            for (int i = m_songs.size(); i < songs.size(); ++i)
                tail.append(songs[i]);
            appendList(tail);   // 增量插入：ListView 只新建尾部 delegate，其余复用
        }
        return;                 // 含"完全相同" → no-op，不触发任何重建
    }
    // 其他（删歌/重排，偶发）→ 兜底全量 reset
    beginResetModel();
    m_songs = songs;
    endResetModel();
    emit countChanged();
}

void SongListModel::append(const SongInfo &song)
{
    beginInsertRows(QModelIndex(), m_songs.size(), m_songs.size());
    m_songs.append(song);
    endInsertRows();
    emit countChanged();
}

void SongListModel::appendList(const QList<SongInfo> &songs)
{
    if (songs.isEmpty())
        return;
    beginInsertRows(QModelIndex(), m_songs.size(), m_songs.size() + songs.size() - 1);
    m_songs.append(songs);
    endInsertRows();
    emit countChanged();
}

void SongListModel::insert(int index, const SongInfo &song)
{
    if (index < 0 || index > m_songs.size())
        return;
    beginInsertRows(QModelIndex(), index, index);
    m_songs.insert(index, song);
    endInsertRows();
    emit countChanged();
}

void SongListModel::removeAt(int index)
{
    if (index < 0 || index >= m_songs.size())
        return;
    beginRemoveRows(QModelIndex(), index, index);
    m_songs.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void SongListModel::clear()
{
    if (m_songs.isEmpty())
        return;
    beginResetModel();
    m_songs.clear();
    endResetModel();
    emit countChanged();
}

bool SongListModel::replaceAt(int index, const SongInfo &song)
{
    if (index < 0 || index >= m_songs.size())
        return false;
    m_songs[index]  = song;
    QModelIndex idx = createIndex(index, 0);
    emit dataChanged(idx, idx);
    return true;
}
