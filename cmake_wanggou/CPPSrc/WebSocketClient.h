#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include <QObject>
#include "playlistmanager.h"
#include <QWebSocket>
#include <QUrl>
#include <QJsonObject>
#include <QJsonDocument>
#include <QTimer>
#include <QMutex>

class WebSocketClient : public QObject
{
    Q_OBJECT
    // 暴露给 QML 的属性
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(ConnectionState connectionState READ connectionState NOTIFY connectionStateChanged)
public:
    explicit WebSocketClient(PlaylistManager *playmanager, QObject *parent = nullptr);
    // 连接状态枚举
    enum ConnectionState {
        Disconnected = 0,  // 未连接
        Connecting,        // 连接中
        Connected,         // 已连接
        Reconnecting       // 重连中
    };
    Q_ENUM(ConnectionState)

    // 基本操作
    Q_INVOKABLE void connectToServer();           // 连接服务器
    Q_INVOKABLE void disconnectFromServer();      // 断开连接
    Q_INVOKABLE void sendJson(const QJsonObject &json);  // 发送JSON数据
    Q_INVOKABLE bool isConnected() const;         // 是否已连接
    Q_INVOKABLE ConnectionState connectionState() const; // 获取连接状态

    // URL 相关
    QString url() const;
    Q_INVOKABLE void setUrl(const QString &url);

    // 配置
    Q_INVOKABLE void setAutoReconnect(bool enable);      // 设置自动重连
    Q_INVOKABLE void setHeartbeatInterval(int seconds);  // 设置心跳间隔

signals:
    // 连接状态相关
    void connected();                       // 连接成功
    void disconnected();                    // 连接断开
    void connectionStatusChanged(bool connected);  // 连接状态变化
    void connectionStateChanged(WebSocketClient::ConnectionState state); // 连接状态枚举变化
    void urlChanged(const QString &url);    // URL变化

    // 数据相关
    void messageReceived(const QString &message);       // 收到文本消息
    void jsonReceived(const QJsonObject &json);         // 收到JSON消息
    void binaryReceived(const QByteArray &data);        // 收到二进制数据

    // 错误处理
    void errorOccurred(const QString &error);          // 发生错误

    // 日志（可选）
    void logMessage(const QString &log);               // 日志消息

public slots:
    // 发送消息的便捷方法
    Q_INVOKABLE void sendString(const QString &message);  // 发送字符串

private slots:
    // WebSocket 事件处理
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &data);
    void onError(QAbstractSocket::SocketError error);

    // 心跳和重连
    void sendHeartbeat();
    void tryReconnect();

private:
    PlaylistManager *playmanager = nullptr;
    // 初始化连接
    void initializeWebSocket();

    // JSON 工具方法
    QJsonObject parseJson(const QString &jsonString);
    QString jsonToString(const QJsonObject &json);

    // 私有成员变量
    QWebSocket *m_webSocket;          // WebSocket 核心对象
    QUrl m_serverUrl;                 // 服务器URL
    ConnectionState m_connectionState;// 连接状态
    bool m_autoReconnect;             // 是否自动重连
    int m_reconnectInterval;          // 重连间隔(毫秒)
    int m_reconnectAttempts;          // 重连尝试次数
    int m_maxReconnectAttempts;       // 最大重连次数

    // 心跳机制
    QTimer *m_heartbeatTimer;         // 心跳定时器
    int m_heartbeatInterval;          // 心跳间隔(秒)

    // 线程安全
    QMutex m_mutex;                   // 线程锁
};

#endif // WEBSOCKETCLIENT_H
