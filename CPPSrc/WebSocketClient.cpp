#include "WebSocketClient.h"
#include <QDebug>

#define WEB_SOCKET_SERVICE_IP "10.0.0.113"
#define WEB_SOCKET_SERVICE_PORT 3375

WebSocketClient::WebSocketClient(PlaylistManager *playManager, QObject *parent)
    : QObject{parent}, playmanager(playManager), m_webSocket(nullptr), m_serverUrl("ws://10.0.0.113:3375"), m_connectionState(Disconnected), m_autoReconnect(true), m_reconnectInterval(100)
      ,
      m_reconnectAttempts(0), m_maxReconnectAttempts(5) // 最大重连10次
      ,
      m_heartbeatTimer(nullptr), m_heartbeatInterval(30) // 30秒心跳
{
    initializeWebSocket();
}

void WebSocketClient::initializeWebSocket()
{
    QMutexLocker locker(&m_mutex);

    if (m_webSocket)
    {
        m_webSocket->deleteLater();
    }

    m_webSocket = new QWebSocket();

    // 连接所有信号槽
    connect(m_webSocket, &QWebSocket::connected,
            this, &WebSocketClient::onConnected);
    connect(m_webSocket, &QWebSocket::disconnected,
            this, &WebSocketClient::onDisconnected);
    connect(m_webSocket, &QWebSocket::textMessageReceived,
            this, &WebSocketClient::onTextMessageReceived);
    connect(m_webSocket, &QWebSocket::binaryMessageReceived,
            this, &WebSocketClient::onBinaryMessageReceived);
    connect(m_webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
            this, &WebSocketClient::onError);

    // 初始化心跳定时器
    if (!m_heartbeatTimer)
    {
        m_heartbeatTimer = new QTimer(this);
        m_heartbeatTimer->setInterval(m_heartbeatInterval * 1000);
        connect(m_heartbeatTimer, &QTimer::timeout,
                this, &WebSocketClient::sendHeartbeat);
    }
}

void WebSocketClient::connectToServer()
{
    // QMutexLocker locker(&m_mutex);
    if (m_connectionState == Connected || m_connectionState == Connecting)
    {
        emit logMessage("WebSocket 正在连接或已连接，无需重复连接");
        qDebug() << "WebSocket 正在连接或已连接，无需重复连接";
        return;
    }
    if (!m_serverUrl.isValid())
    {
        emit errorOccurred("无效的服务器URL: " + m_serverUrl.toString());
        qDebug() << "无效的服务器URL: " + m_serverUrl.toString();
        return;
    }

    m_connectionState = Connecting;
    emit connectionStateChanged(m_connectionState);

    emit logMessage("正在连接服务器: " + m_serverUrl.toString());
    qDebug() << "正在连接服务器: " + m_serverUrl.toString();

    m_webSocket->open(m_serverUrl);
}

void WebSocketClient::disconnectFromServer()
{
    QMutexLocker locker(&m_mutex);

    if (m_heartbeatTimer && m_heartbeatTimer->isActive())
    {
        m_heartbeatTimer->stop();
    }

    if (m_webSocket)
    {
        m_webSocket->close();
    }

    m_connectionState = Disconnected;
    emit connectionStateChanged(m_connectionState);
    emit connectionStatusChanged(false);

    emit logMessage("已断开服务器连接");
    qDebug() << "已断开服务器连接";
}

bool WebSocketClient::isConnected() const
{
    return m_connectionState == Connected;
}

WebSocketClient::ConnectionState WebSocketClient::connectionState() const
{
    return m_connectionState;
}

QString WebSocketClient::url() const
{
    return m_serverUrl.toString();
}

void WebSocketClient::setUrl(const QString &roomid,const QString &userid)
{
    int ischange = 0;
    Roomid = roomid;
    QString web_service_url = QString("ws://%1:%2/?userid=%3&roomid=%4")
                                  .arg(WEB_SOCKET_SERVICE_IP)   // 替换 %1
                                  .arg(WEB_SOCKET_SERVICE_PORT) // 替换 %2
                                  .arg(userid)                   // 替换 %3
                                  .arg(roomid);                    // 替换 %4
    if (m_serverUrl.toString() != web_service_url)
    {
        // 如果已连接，先断开
        if (m_connectionState == Connected)
        {
            disconnectFromServer();
        }
        QMutexLocker locker(&m_mutex);
        m_serverUrl = QUrl(web_service_url);
        ischange = 1;
    }
    if (ischange)
    {
        initializeWebSocket();
        emit urlChanged(web_service_url);
    }
}

QString WebSocketClient::Getroomid() const
{
    return Roomid;
}

void WebSocketClient::sendJson(const QJsonObject &json)
{
    if (!isConnected())
    {
        emit errorOccurred("无法发送JSON：WebSocket未连接");
        return;
    }

    QJsonDocument doc(json);
    QString jsonString = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));

    m_webSocket->sendTextMessage(jsonString);

    emit logMessage("发送JSON: " + jsonString);
}

void WebSocketClient::sendString(const QString &message)
{
    if (!isConnected())
    {
        emit errorOccurred("无法发送消息：WebSocket未连接");
        return;
    }

    m_webSocket->sendTextMessage(message);
    emit logMessage("发送消息: " + message);
}

void WebSocketClient::setAutoReconnect(bool enable)
{
    m_autoReconnect = enable;
    emit logMessage(QString("自动重连: %1").arg(enable ? "启用" : "禁用"));
}

void WebSocketClient::setHeartbeatInterval(int seconds)
{
    if (seconds < 5)
    {
        seconds = 5; // 最小5秒
    }

    m_heartbeatInterval = seconds;

    if (m_heartbeatTimer)
    {
        m_heartbeatTimer->setInterval(seconds * 1000);
    }

    emit logMessage(QString("心跳间隔设置为: %1秒").arg(seconds));
}

void WebSocketClient::onConnected()
{
    qDebug() << "WebSocket 连接成功";
    QMutexLocker locker(&m_mutex);

    m_connectionState = Connected;
    m_reconnectAttempts = 0; // 重置重连次数

    emit connectionStateChanged(m_connectionState);
    emit logMessage("WebSocket 连接成功");
    qDebug() << "WebSocket 连接成功";

    // 启动心跳定时器
    if (m_heartbeatTimer)
    {
        m_heartbeatTimer->start();
    }
    //更改播放列表为一起听
    playmanager->changeplaylisttype(TOGETHER);
}

void WebSocketClient::onDisconnected()
{

    QMutexLocker locker(&m_mutex);

    m_connectionState = Disconnected;

    emit connectionStateChanged(m_connectionState);
    emit connectionStatusChanged(false);
    emit logMessage("WebSocket 连接断开");
    qDebug() << "WebSocket 连接断开";

    // 停止心跳
    if (m_heartbeatTimer && m_heartbeatTimer->isActive())
    {
        m_heartbeatTimer->stop();
    }

    // 自动重连
    if (m_autoReconnect && m_reconnectAttempts < m_maxReconnectAttempts)
    {
        QTimer::singleShot(m_reconnectInterval, this, &WebSocketClient::tryReconnect);
    }
    else
    {
        //触发连接失败信号
        emit connectFail();
        return;
    }
}

void WebSocketClient::onTextMessageReceived(const QString &message)
{
    emit messageReceived(message);

    // 尝试解析为JSON
    QJsonObject json = parseJson(message);
    if (!json.isEmpty())
    {
        emit jsonReceived(json);
    }
    qDebug() << "收到消息：" << message;

    // 可以在这里添加业务逻辑处理
    // emit logMessage("收到消息: " + message);
}

void WebSocketClient::onBinaryMessageReceived(const QByteArray &data)
{
    emit binaryReceived(data);
    emit logMessage(QString("收到二进制数据，大小: %1 字节").arg(data.size()));
}

void WebSocketClient::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);

    QString errorString = m_webSocket->errorString();
    emit errorOccurred(errorString);
    emit logMessage("WebSocket 错误: " + errorString);
}

void WebSocketClient::sendHeartbeat()
{
    if (!isConnected())
    {
        return;
    }

    QJsonObject heartbeat;
    heartbeat["type"] = "heartbeat";
    heartbeat["timestamp"] = QDateTime::currentMSecsSinceEpoch();

    sendJson(heartbeat);
}

void WebSocketClient::tryReconnect()
{
    if (m_connectionState == Connected)
    {
        return;
    }

    m_reconnectAttempts++;

    if (m_reconnectAttempts > m_maxReconnectAttempts)
    {
        emit logMessage("达到最大重连次数，停止重连");
        return;
    }

    emit logMessage(QString("尝试重连 (%1/%2)...").arg(m_reconnectAttempts).arg(m_maxReconnectAttempts));

    m_connectionState = Reconnecting;
    emit connectionStateChanged(m_connectionState);

    connectToServer();
}

QJsonObject WebSocketClient::parseJson(const QString &jsonString)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8(), &parseError);

    if (parseError.error != QJsonParseError::NoError)
    {
        // 不是有效的JSON，返回空对象
        return QJsonObject();
    }

    if (!doc.isObject())
    {
        return QJsonObject();
    }

    return doc.object();
}

QString WebSocketClient::jsonToString(const QJsonObject &json)
{
    QJsonDocument doc(json);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}
