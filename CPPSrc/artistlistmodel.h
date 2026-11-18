#ifndef ARTIST_LIST_MODEL_H
#define ARTIST_LIST_MODEL_H

#include <QAbstractListModel>
#include <QVariantList>

// 歌手页列表模型（单曲/专辑共用）。
class ArtistListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles
    {
        SongNameRole = Qt::UserRole + 1,
        SingerNameRole,
        SongHashRole,
        AlbumNameRole,
        DurationRole,
        UnionCoverRole,
        AlbumIdRole,
        CoverRole,
        PublishDateRole,
        IntroRole,
    };
    Q_ENUM(Roles)

    explicit ArtistListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QVariant get(int index) const;
    int count() const { return m_items.size(); }

    void reset(const QVariantList &items);
    void appendList(const QVariantList &items);
    void clear();

signals:
    void countChanged();

private:
    QVariantList m_items;
};

#endif // ARTIST_LIST_MODEL_H
