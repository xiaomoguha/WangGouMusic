#include "serveradminmanager.h"

#include "ApiClient.h"

#include <QJsonObject>
#include <QMap>
#include <QDebug>

namespace
{
const QString kApiRoot = QStringLiteral("https://api.special520.com");
constexpr int kAdminTimeoutMs = 15000; // 同步/检测服务端要再向酷狗校验一次，放宽超时
} // namespace

ServerAdminManager::ServerAdminManager(QObject *parent) : QObject(parent)
{
    m_adminKey = m_settings.value("adminKey").toString();
}

QString ServerAdminManager::adminKey() const
{
    return m_adminKey;
}

void ServerAdminManager::setAdminKey(const QString &key)
{
    const QString trimmed = key.trimmed();
    if (trimmed == m_adminKey)
        return;
    m_adminKey = trimmed;
    m_settings.setValue("adminKey", m_adminKey);
    emit adminKeyChanged();
}

bool ServerAdminManager::busy() const
{
    return m_busy;
}

void ServerAdminManager::setBusy(bool loading)
{
    if (loading == m_busy)
        return;
    m_busy = loading;
    emit busyChanged();
}

bool ServerAdminManager::ensureKeyPresent(const QString &operation)
{
    if (!m_adminKey.isEmpty())
        return true;
    emit requestFailed(operation, QStringLiteral("请先填写服务器管理密钥"));
    return false;
}

bool ServerAdminManager::parseBusinessReply(const QJsonObject &root, QVariantMap &out, QString &err)
{
    if (root.value("status").toInt() == 1)
    {
        out = root.value("data").toObject().toVariantMap();
        return true;
    }
    // 服务器业务失败统一 {status:0, msg}（403 密钥错误 / 400 校验未通过等）
    err = root.value("msg").toString();
    if (err.isEmpty())
        err = QStringLiteral("服务器返回异常（status=%1）").arg(root.value("status").toInt());
    return false;
}

void ServerAdminManager::fetchStatus()
{
    if (m_busy || !ensureKeyPresent(QStringLiteral("status")))
        return;
    setBusy(true);
    ApiClient::instance().getJson(
        kApiRoot + QStringLiteral("/admin/token"),
        [this](QJsonObject root)
        {
            setBusy(false);
            QVariantMap data;
            QString err;
            if (parseBusinessReply(root, data, err))
                emit statusReceived(data);
            else
                emit requestFailed(QStringLiteral("status"), err);
        },
        [this](QString err, int /*httpStatus*/)
        {
            setBusy(false);
            emit requestFailed(QStringLiteral("status"), QStringLiteral("连接服务器失败：") + err);
        },
        kAdminTimeoutMs,
        {{QStringLiteral("x-admin-key"), m_adminKey}}
    );
}

void ServerAdminManager::syncToken(const QString &token, const QString &userid)
{
    if (m_busy || !ensureKeyPresent(QStringLiteral("sync")))
        return;
    if (token.isEmpty() || userid.isEmpty())
    {
        emit requestFailed(QStringLiteral("sync"), QStringLiteral("请先在客户端登录共享账号"));
        return;
    }
    setBusy(true);
    QJsonObject body;
    body.insert(QStringLiteral("token"), token);
    body.insert(QStringLiteral("userid"), userid);
    ApiClient::instance().postJson(
        kApiRoot + QStringLiteral("/admin/token"),
        body,
        [this](QJsonObject root)
        {
            setBusy(false);
            QVariantMap data;
            QString err;
            if (parseBusinessReply(root, data, err))
                emit syncResult(data);
            else
                emit requestFailed(QStringLiteral("sync"), err);
        },
        [this](QString err, int /*httpStatus*/)
        {
            setBusy(false);
            emit requestFailed(QStringLiteral("sync"), QStringLiteral("连接服务器失败：") + err);
        },
        kAdminTimeoutMs,
        {{QStringLiteral("x-admin-key"), m_adminKey}}
    );
}

void ServerAdminManager::fetchGuardStatus()
{
    // 顶栏状态点的 30 秒轮询：服务器只回读看门狗落盘的缓存结果，
    // 不会触发真实检测——不走 busy 闸门，也不与手动同步/检测互相阻塞
    if (m_adminKey.isEmpty())
    {
        emit requestFailed(QStringLiteral("guard"), QStringLiteral("请先填写服务器管理密钥"));
        return;
    }
    ApiClient::instance().getJson(
        kApiRoot + QStringLiteral("/admin/token/status"),
        [this](QJsonObject root)
        {
            QVariantMap data;
            QString err;
            if (parseBusinessReply(root, data, err))
                emit guardStatusReceived(data);
            else
                emit requestFailed(QStringLiteral("guard"), err);
        },
        [this](QString err, int /*httpStatus*/)
        {
            emit requestFailed(QStringLiteral("guard"), QStringLiteral("连接服务器失败：") + err);
        },
        8000,
        {{QStringLiteral("x-admin-key"), m_adminKey}}
    );
}

void ServerAdminManager::checkToken()
{
    if (m_busy || !ensureKeyPresent(QStringLiteral("check")))
        return;
    setBusy(true);
    ApiClient::instance().postJson(
        kApiRoot + QStringLiteral("/admin/token/check"),
        {},
        [this](QJsonObject root)
        {
            setBusy(false);
            QVariantMap data;
            QString err;
            if (parseBusinessReply(root, data, err))
                emit checkResult(data);
            else
                emit requestFailed(QStringLiteral("check"), err);
        },
        [this](QString err, int /*httpStatus*/)
        {
            setBusy(false);
            emit requestFailed(QStringLiteral("check"), QStringLiteral("连接服务器失败：") + err);
        },
        kAdminTimeoutMs,
        {{QStringLiteral("x-admin-key"), m_adminKey}}
    );
}
