#ifndef VARIANT_MAP_LIST_MODEL_H
#define VARIANT_MAP_LIST_MODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QVariant>
#include <QVariantMap>

/**
 * @brief QVariantMap 列表的通用 QAbstractListModel 基类
 *
 * 聊天消息/房间列表/热搜/搜索结果/推荐歌单等都用 QVariantMap 承载字段，
 * 它们的差异只在 roleNames。本基类提供统一的存储 + 增删改操作，
 * 子类只需在构造时调用 setRoleNames() 配置 role 列表。
 *
 * data() 从 QVariantMap 按 role 名取值（兼容字段缺失：返回空 QVariant）。
 * 同时把整个 map 暴露为 "display" role，便于 QML 用 model.display.xxx 兜底。
 */
class VariantMapListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    explicit VariantMapListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// 供 QML JS 迭代：返回某行的 QVariantMap
    Q_INVOKABLE QVariant get(int index) const;
    int count() const { return m_items.size(); }

signals:
    void countChanged();

public:
    // ── 数据操作（C++ 端调用）──
    void setRoleNames(const QList<QByteArray> &names);
    void syncFromVariantList(const QVariantList &items);
    void append(const QVariantMap &item);
    void appendList(const QVariantList &items);
    void insert(int index, const QVariantMap &item);
    void removeAt(int index);
    void clear();

    const QVariantList &items() const { return m_items; }

protected:
    QVariantList m_items;
    QHash<int, QByteArray> m_roleNames;
    // role 名 -> 在 QVariantMap 中的 key（多数一致，子类可覆写）
    QHash<int, QString> m_roleToKey;
};

#endif // VARIANT_MAP_LIST_MODEL_H
