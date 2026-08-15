#include "MessageListModel.h"

MessageListModel::MessageListModel(QObject *parent) : QAbstractListModel(parent) {}

int MessageListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_messages.size();
}

QVariant MessageListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_messages.size())
        return {};
    // 整行 QVariantMap 下发:与原 QVariantList 模型的 modelData.xxx 等价
    if (role == Qt::DisplayRole || role == ModelDataRole)
        return m_messages.at(index.row());
    return {};
}

QHash<int, QByteArray> MessageListModel::roleNames() const
{
    // 名字必须是 "modelData":QAbstractListModel 的 role 会以名字注入
    // delegate 上下文,这样 QML 里 modelData.type / modelData.status 等
    // 写法与原 QVariantList 模型完全一致,delegate 无需改动
    return { {ModelDataRole, "modelData"} };
}

QVariantMap MessageListModel::get(int index) const
{
    if (index < 0 || index >= m_messages.size())
        return {};
    return m_messages.at(index).toMap();
}

// ── 数据操作 ──

int MessageListModel::appendMessage(const QVariantMap &msg)
{
    const int row = m_messages.size();
    beginInsertRows(QModelIndex(), row, row);
    m_messages.append(msg);
    endInsertRows();
    emit countChanged();
    return row;
}

void MessageListModel::appendMessages(const QList<QVariantMap> &msgs)
{
    if (msgs.isEmpty())
        return;
    const int first = m_messages.size();
    beginInsertRows(QModelIndex(), first, first + msgs.size() - 1);
    for (const QVariantMap &m : msgs)
        m_messages.append(m);
    endInsertRows();
    emit countChanged();
}

bool MessageListModel::updateMessage(int index, const QVariantMap &msg)
{
    if (index < 0 || index >= m_messages.size())
        return false;
    m_messages[index] = msg;
    const QModelIndex idx = createIndex(index, 0);
    emit dataChanged(idx, idx);
    return true;
}

int MessageListModel::findByMsgId(int msgId, const QString &status) const
{
    for (int i = 0; i < m_messages.size(); ++i)
    {
        const QVariantMap m = m_messages.at(i).toMap();
        if (m.value("_msgId").toInt() != msgId)
            continue;
        if (!status.isEmpty() && m.value("status").toString() != status)
            continue;
        return i;
    }
    return -1;
}

int MessageListModel::findLocalEcho(const QString &userid, const QString &message) const
{
    // 只查最近 5 条:本地刚发出的消息必在队尾附近(与原 QVariantList 逻辑一致)
    for (int i = m_messages.size() - 1; i >= qMax(0, m_messages.size() - 5); --i)
    {
        const QVariantMap m = m_messages.at(i).toMap();
        if (m.value("_local").toBool() && m.value("userid").toString() == userid
            && m.value("message").toString() == message)
            return i;
    }
    return -1;
}

bool MessageListModel::containsAction(const QVariant &time, const QVariant &userid, const QVariant &message) const
{
    // 只查最近 30 条去重(与原 QVariantList 逻辑一致)
    for (int i = m_messages.size() - 1; i >= qMax(0, m_messages.size() - 30); --i)
    {
        const QVariantMap m = m_messages.at(i).toMap();
        if (m.value("time") == time && m.value("userid") == userid && m.value("message") == message)
            return true;
    }
    return false;
}

void MessageListModel::truncate(int max)
{
    if (m_messages.size() <= max)
        return;
    const int removeCount = m_messages.size() - max;
    beginRemoveRows(QModelIndex(), 0, removeCount - 1);
    for (int i = 0; i < removeCount; ++i)
        m_messages.removeAt(0);
    endRemoveRows();
    emit countChanged();
}

void MessageListModel::clearAll()
{
    if (m_messages.isEmpty())
        return;
    beginResetModel();
    m_messages.clear();
    endResetModel();
    emit countChanged();
}
