#include "VariantMapListModel.h"

VariantMapListModel::VariantMapListModel(QObject *parent)
    : QAbstractListModel(parent) {}

int VariantMapListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant VariantMapListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};
    const QVariantMap &item = m_items.at(index.row()).toMap();

    // Qt::DisplayRole 返回整个 map（QML 可用 model.display.xxx 兜底访问任意字段）
    if (role == Qt::DisplayRole)
        return item;

    auto it = m_roleToKey.find(role);
    if (it != m_roleToKey.end())
        return item.value(it.value());
    return {};
}

QHash<int, QByteArray> VariantMapListModel::roleNames() const
{
    return m_roleNames;
}

QVariant VariantMapListModel::get(int index) const
{
    if (index < 0 || index >= m_items.size())
        return {};
    return m_items.at(index);
}

void VariantMapListModel::setRoleNames(const QList<QByteArray> &names)
{
    m_roleNames.clear();
    m_roleToKey.clear();
    int role = Qt::UserRole + 1;
    for (const QByteArray &name : names) {
        m_roleNames.insert(role, name);
        m_roleToKey.insert(role, QString::fromLatin1(name));
        ++role;
    }
}

void VariantMapListModel::syncFromVariantList(const QVariantList &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
    emit countChanged();
}

void VariantMapListModel::append(const QVariantMap &item)
{
    beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
    m_items.append(item);
    endInsertRows();
    emit countChanged();
}

void VariantMapListModel::appendList(const QVariantList &items)
{
    if (items.isEmpty()) return;
    beginInsertRows(QModelIndex(), m_items.size(), m_items.size() + items.size() - 1);
    for (const QVariant &v : items)
        m_items.append(v);
    endInsertRows();
    emit countChanged();
}

void VariantMapListModel::insert(int index, const QVariantMap &item)
{
    if (index < 0 || index > m_items.size()) return;
    beginInsertRows(QModelIndex(), index, index);
    m_items.insert(index, item);
    endInsertRows();
    emit countChanged();
}

void VariantMapListModel::removeAt(int index)
{
    if (index < 0 || index >= m_items.size()) return;
    beginRemoveRows(QModelIndex(), index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void VariantMapListModel::clear()
{
    if (m_items.isEmpty()) return;
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
}
