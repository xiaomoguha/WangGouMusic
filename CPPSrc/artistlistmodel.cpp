#include "artistlistmodel.h"

ArtistListModel::ArtistListModel(QObject *parent) : QAbstractListModel(parent)
{
}

int ArtistListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant ArtistListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();
    const QVariantMap item = m_items.at(index.row()).toMap();
    switch (role)
    {
    case SongNameRole:    return item["songname"];
    case SingerNameRole:  return item["singername"];
    case SongHashRole:    return item["songhash"];
    case AlbumNameRole:   return item["album_name"];
    case DurationRole:    return item["duration"];
    case UnionCoverRole:  return item["union_cover"];
    case AlbumIdRole:     return item["album_id"];
    case CoverRole:       return item["cover"];
    case PublishDateRole: return item["publish_date"];
    case IntroRole:       return item["intro"];
    default:              return QVariant();
    }
}

QHash<int, QByteArray> ArtistListModel::roleNames() const
{
    return {
        {SongNameRole,    "songname"},
        {SingerNameRole,  "singername"},
        {SongHashRole,    "songhash"},
        {AlbumNameRole,   "album_name"},
        {DurationRole,    "duration"},
        {UnionCoverRole,  "union_cover"},
        {AlbumIdRole,     "album_id"},
        {CoverRole,       "cover"},
        {PublishDateRole, "publish_date"},
        {IntroRole,       "intro"},
    };
}

QVariant ArtistListModel::get(int index) const
{
    if (index < 0 || index >= m_items.size())
        return QVariant();
    return m_items.at(index);
}

void ArtistListModel::reset(const QVariantList &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
    emit countChanged();
}

void ArtistListModel::appendList(const QVariantList &items)
{
    if (items.isEmpty())
        return;
    const int first = m_items.size();
    beginInsertRows(QModelIndex(), first, first + items.size() - 1);
    m_items.append(items);
    endInsertRows();
    emit countChanged();
}

void ArtistListModel::clear()
{
    if (m_items.isEmpty())
        return;
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
}
