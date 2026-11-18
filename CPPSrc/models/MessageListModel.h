#ifndef MESSAGE_LIST_MODEL_H
#define MESSAGE_LIST_MODEL_H

#include <QAbstractListModel>
#include <QVariantList>
#include <QVariantMap>

// 聊天/操作动态列表的 QAbstractListModel 封装
// 替代 WebSocketClient 原先暴露给 QML 的 QVariantList messages 属性。
class MessageListModel : public QAbstractListModel
{
    Q_OBJECT
    // QML 可直接绑定的行数属性(QAbstractItemModel 无内建 count)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles
    {
        ModelDataRole = Qt::UserRole + 1,
    };
    Q_ENUM(Roles)

    explicit MessageListModel(QObject *parent = nullptr);

    // ── QAbstractListModel 接口 ──
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ── 供 QML JS 访问 ──
    Q_INVOKABLE QVariantMap get(int index) const;
    int count() const
    {
        return m_messages.size();
    }

    // ── 数据操作(WebSocketClient 调用,触发正确的行级 model 信号)──
    // 末尾追加一条,返回其行号
    int appendMessage(const QVariantMap &msg);
    // 末尾批量追加(历史动态已按时间正序排好)
    void appendMessages(const QList<QVariantMap> &msgs);
    // 原地更新指定行(发送状态流转),只发 dataChanged 不重建
    bool updateMessage(int index, const QVariantMap &msg);
    // 全表按 _msgId + status 找行号,找不到返回 -1(status 为空则不筛)
    int findByMsgId(int msgId, const QString &status = QString()) const;
    // 队尾 5 条窗口内找本地回显(_local && userid && message),返回行号或 -1
    int findLocalEcho(const QString &userid, const QString &message) const;
    // 队尾 30 条窗口内查重(time + userid + message 三元组,QVariant 语义与原逻辑一致)
    bool containsAction(const QVariant &time, const QVariant &userid, const QVariant &message) const;
    // 超过 max 条时从头部截断
    void truncate(int max);
    void clearAll();

signals:
    void countChanged();

private:
    QVariantList m_messages;
};

#endif // MESSAGE_LIST_MODEL_H
