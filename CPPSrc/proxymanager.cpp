#include "proxymanager.h"

#include <QNetworkProxy>
#include <QSettings>

ProxyManager::ProxyManager(QObject *parent) : QObject(parent)
{
    load();
    apply();   // 启动即生效：必须在任何网络请求发出前（main.cpp 中早于 engine.load）
}

void ProxyManager::load()
{
    QSettings s("WangGouMusic", "NetworkConfig");
    m_mode       = s.value("proxy/mode", 1).toInt();
    m_customHost = s.value("proxy/host", "").toString();
    m_customPort = s.value("proxy/port", 7890).toInt();
    m_customType = s.value("proxy/type", 0).toInt();

    // 越界兜底
    if (m_mode < 0 || m_mode > 2) m_mode = 1;
    if (m_customType != 0 && m_customType != 1) m_customType = 0;
    if (m_customPort <= 0 || m_customPort > 65535) m_customPort = 7890;
}

void ProxyManager::save()
{
    QSettings s("WangGouMusic", "NetworkConfig");
    s.setValue("proxy/mode", m_mode);
    s.setValue("proxy/host", m_customHost);
    s.setValue("proxy/port", m_customPort);
    s.setValue("proxy/type", m_customType);
}

void ProxyManager::apply()
{
    QNetworkProxy proxy;
    switch (m_mode) {
    case 0:  // 不使用代理：强制直连，绕开 clash 等系统级全局代理
        proxy.setType(QNetworkProxy::NoProxy);
        break;
    case 1:  // 系统代理：跟随系统设置（Qt 默认行为，保持兼容）
        proxy.setType(QNetworkProxy::DefaultProxy);
        break;
    case 2: {  // 自定义代理
        const QNetworkProxy::ProxyType t = (m_customType == 1)
            ? QNetworkProxy::Socks5Proxy : QNetworkProxy::HttpProxy;
        proxy.setType(t);
        proxy.setHostName(m_customHost);
        proxy.setPort(static_cast<quint16>(m_customPort));
        break;
    }
    default:
        proxy.setType(QNetworkProxy::DefaultProxy);
        break;
    }
    QNetworkProxy::setApplicationProxy(proxy);
    qDebug() << "[ProxyManager] 已应用代理: mode=" << m_mode
             << "host=" << m_customHost << "port=" << m_customPort << "type=" << m_customType;
    emit proxyChanged();
}

bool ProxyManager::setConfig(int mode, const QString &host, int port, int type)
{
    if (mode < 0 || mode > 2) return false;
    if (mode == 2) {
        // 自定义模式必填校验
        if (host.trimmed().isEmpty()) return false;
        if (port <= 0 || port > 65535) return false;
        if (type != 0 && type != 1) return false;
    }
    m_mode       = mode;
    m_customHost = host.trimmed();
    m_customPort = port;
    m_customType = type;
    save();
    apply();
    return true;
}

QString ProxyManager::currentModeName() const
{
    switch (m_mode) {
    case 0:  return QStringLiteral("不使用代理");
    case 2:  return QStringLiteral("自定义代理");
    case 1:
    default: return QStringLiteral("系统代理");
    }
}
