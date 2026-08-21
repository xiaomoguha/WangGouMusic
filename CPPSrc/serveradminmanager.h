#ifndef SERVERADMINMANAGER_H
#define SERVERADMINMANAGER_H

#include <QJsonObject>
#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantMap>

/**
 * @brief 服务器共享 token 管理（设置页「服务器」分区后端）
 *
 * 对接服务器 /admin/token 管理接口（需 x-admin-key 鉴权）：
 * - fetchStatus：查询服务器当前共享 token 概况（脱敏）
 * - syncToken：把客户端当前登录的 token 推到服务器（服务端先校验再热更新+持久化）
 * - checkToken：检测服务器当前共享 token 是否仍有效（服务端现场真查一次酷狗）
 * 管理密钥持久化在 QSettings，只在客户端与自己的服务器之间传输。
 */
class ServerAdminManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString adminKey READ adminKey WRITE setAdminKey NOTIFY adminKeyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit ServerAdminManager(QObject *parent = nullptr);

    QString adminKey() const;
    void setAdminKey(const QString &key);
    bool busy() const;

    Q_INVOKABLE void fetchStatus();
    Q_INVOKABLE void syncToken(const QString &token, const QString &userid);
    Q_INVOKABLE void checkToken();

signals:
    void adminKeyChanged();
    void busyChanged();
    /// fetchStatus 成功：{userid, vip_type, token_masked, updated_at}
    void statusReceived(const QVariantMap &data);
    /// syncToken 成功：同 statusReceived 结构
    void syncResult(const QVariantMap &data);
    /// checkToken 成功：{valid, error_code, userid, vip_type, msg}
    void checkResult(const QVariantMap &data);
    /// 任一操作失败（网络错误 / 密钥不对 / 校验未通过），operation 为 "status"/"sync"/"check"
    void requestFailed(const QString &operation, const QString &error);

private:
    void setBusy(bool loading);
    /// 解析业务响应：status==1 时取出 data 填入 out，否则从 msg/错误码生成 err
    static bool parseBusinessReply(const QJsonObject &root, QVariantMap &out, QString &err);
    /// 未配置密钥时的统一前置校验（弹 requestFailed 并返回 false）
    bool ensureKeyPresent(const QString &operation);

    QSettings m_settings{"WangGouMusic", "ServerAdmin"};
    QString m_adminKey;
    bool m_busy = false;
};

#endif // SERVERADMINMANAGER_H
