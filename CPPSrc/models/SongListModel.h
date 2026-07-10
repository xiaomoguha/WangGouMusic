#ifndef SONG_LIST_MODEL_H
#define SONG_LIST_MODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QVariant>
#include "../SongInfo.h"

/**
 * @brief SongInfo 列表的 QAbstractListModel 封装
 *
 * 替代原先暴露给 QML 的 QList<SongInfo> / QVariantList。
 * 优点：每次 append/remove/clear 只通知变化的行（beginInsertRows/dataChanged），
 * 而非把整个列表深拷贝一遍。QML ListView 直接用本 model，delegate 内用
 * model.title / model.songhash 等 role 访问字段。
 *
 * 供 PlaylistManager 的 playlist / togetherplaylist / recentPlaylist 三个列表复用。
 */
class SongListModel : public QAbstractListModel
{
    Q_OBJECT
    // QML 可直接绑定的行数属性（QAbstractItemModel 无内建 count 属性）
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        SongHashRole,
        UrlRole,
        SingerNameRole,
        UnionCoverRole,
        AlbumNameRole,
        DurationRole,
        LyricRole,
        AddedByNicknameRole,
        AddedByAvatarRole,
    };
    Q_ENUM(Roles)

    explicit SongListModel(QObject *parent = nullptr);

    // ── QAbstractListModel 接口 ──
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ── 供 QML JS 迭代（替代直接数组下标访问）──
    Q_INVOKABLE QVariant get(int index) const;
    int count() const { return m_songs.size(); }

    // ── 数据操作（C++ 端调用，触发正确的 model 信号）──
    /// 用外部 QList 替换全部数据（保留原 list 的引用语义给 PlaylistManager）
    void syncFromList(const QList<SongInfo> &songs);
    void append(const SongInfo &song);
    void appendList(const QList<SongInfo> &songs);
    void insert(int index, const SongInfo &song);
    void removeAt(int index);
    void clear();
    /// 替换指定行（用于更新 url/lyric 等字段）
    bool replaceAt(int index, const SongInfo &song);

signals:
    void countChanged();

    /// 取底层 list 的只读引用（PlaylistManager 内部用）
public:
    const QList<SongInfo> &songs() const { return m_songs; }
    /// 取底层 list 的可写引用（PlaylistManager 直接操作后需手动调 syncFromList 刷新）
    QList<SongInfo> &songsRef() { return m_songs; }

private:
    QList<SongInfo> m_songs;
};

#endif // SONG_LIST_MODEL_H
