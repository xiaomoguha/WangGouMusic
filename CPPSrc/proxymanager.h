#ifndef PROXYMANAGER_H
#define PROXYMANAGER_H

#include <QObject>
#include <QString>

// 网络代理管理：进程级设置 QNetworkProxy::setApplicationProxy，
// 一处生效，所有 QNetworkAccessManager / QWebSocket / QML XMLHttpRequest 自动遵循。
// mode: 0=不使用代理(强制直连，绕开 clash 等全局代理) / 1=系统代理 / 2=自定义
class ProxyManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int mode READ mode NOTIFY proxyChanged)
    Q_PROPERTY(QString customHost READ customHost NOTIFY proxyChanged)
    Q_PROPERTY(int customPort READ customPort NOTIFY proxyChanged)
    Q_PROPERTY(int customType READ customType NOTIFY proxyChanged)   // 0=HTTP / 1=SOCKS5
    Q_PROPERTY(QString currentModeName READ currentModeName NOTIFY proxyChanged)

public:
    explicit ProxyManager(QObject *parent = nullptr);

    int mode() const { return m_mode; }
    QString customHost() const { return m_customHost; }
    int customPort() const { return m_customPort; }
    int customType() const { return m_customType; }
    QString currentModeName() const;

    // 把当前配置应用到全局代理（启动时构造函数已调一次）
    Q_INVOKABLE void apply();
    // QML 设置后调：保存 + 应用；自定义模式校验失败返回 false
    Q_INVOKABLE bool setConfig(int mode, const QString &host, int port, int type);

signals:
    void proxyChanged();

private:
    void load();
    void save();

    int m_mode = 1;                 // 默认跟随系统，保持现有行为
    QString m_customHost;
    int m_customPort = 7890;        // clash 默认混合端口
    int m_customType = 0;           // 默认 HTTP（兼容 HTTPS 的 CONNECT 隧道）
};

#endif // PROXYMANAGER_H
