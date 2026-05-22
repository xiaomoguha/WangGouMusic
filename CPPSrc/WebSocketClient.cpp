#include "WebSocketClient.h"
#include <QDebug>

#define WEB_SOCKET_SERVICE_HOST "192.168.9.119:3001"
#define WEB_SOCKET_SERVICE_PATH "/ws"

WebSocketClient::WebSocketClient(PlaylistManager *playManager, UserManager *userManager, QObject *parent)
    : QObject{parent}, playmanager(playManager), usermanager(userManager), m_webSocket(nullptr), m_serverUrl("ws://192.168.9.119:3001/ws"), m_connectionState(Disconnected), m_autoReconnect(true), m_reconnectInterval(100)
      ,
      m_reconnectAttempts(0), m_maxReconnectAttempts(5)
      ,
      m_heartbeatTimer(nullptr), m_heartbeatInterval(30)
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
    if (m_connectionState == Connected || m_connectionState == Connecting)
    {
        emit logMessage("WebSocket 正在连接或已连接，无需重复连接");
        return;
    }
    if (!m_serverUrl.isValid())
    {
        emit errorOccurred("无效的服务器URL: " + m_serverUrl.toString());
        return;
    }

    m_connectionState = Connecting;
    emit connectionStateChanged(m_connectionState);

    emit logMessage("正在连接服务器: " + m_serverUrl.toString());
    m_webSocket->open(m_serverUrl);
}

void WebSocketClient::disconnectFromServer()
{
    m_autoReconnect = false; // 用户主动断开，禁止自动重连
    QMutexLocker locker(&m_mutex);

    if (m_heartbeatTimer && m_heartbeatTimer->isActive())
    {
        m_heartbeatTimer->stop();
    }

    if (m_webSocket)
    {
        // 先断开信号连接，避免触发 onDisconnected 中的 connectFail
        disconnect(m_webSocket, &QWebSocket::disconnected, this, &WebSocketClient::onDisconnected);
        m_webSocket->close();
        // 延迟删除，等待关闭完成
        m_webSocket->deleteLater();
        m_webSocket = nullptr;
    }

    m_connectionState = Disconnected;
    emit connectionStateChanged(m_connectionState);
    emit connectionStatusChanged(false);

    // 退出一起听模式，恢复本地播放列表
    playmanager->changeplaylisttype(LOCAL);

    emit logMessage("已断开服务器连接");
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

void WebSocketClient::setUrl(const QString &roomid, const QString &userid)
{
    int ischange = 0;
    Roomid = roomid;
    m_userId = userid;

    // 从 UserManager 获取昵称和头像
    QString nickname;
    QString avatarUrl;
    if (usermanager && usermanager->isLoggedIn())
    {
        nickname = usermanager->nickname();
        avatarUrl = usermanager->avatarUrl();
    }

    QString web_service_url = QString("ws://%1%2?userid=%3&roomid=%4&nickname=%5&avatar=%6")
                                  .arg(WEB_SOCKET_SERVICE_HOST)
                                  .arg(WEB_SOCKET_SERVICE_PATH)
                                  .arg(userid)
                                  .arg(roomid)
                                  .arg(QString(QUrl::toPercentEncoding(nickname)))
                                  .arg(QString(QUrl::toPercentEncoding(avatarUrl)));
    if (m_serverUrl.toString() != web_service_url)
    {
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
}

void WebSocketClient::sendString(const QString &message)
{
    if (!isConnected())
    {
        emit errorOccurred("无法发送消息：WebSocket未连接");
        return;
    }

    m_webSocket->sendTextMessage(message);
}

void WebSocketClient::setAutoReconnect(bool enable)
{
    m_autoReconnect = enable;
}

void WebSocketClient::setHeartbeatInterval(int seconds)
{
    if (seconds < 5)
    {
        seconds = 5;
    }

    m_heartbeatInterval = seconds;

    if (m_heartbeatTimer)
    {
        m_heartbeatTimer->setInterval(seconds * 1000);
    }
}

// ==================== 一起听操作命令 ====================

void WebSocketClient::addSongToTogether(const QString &songname, const QString &songhash,
                                         const QString &singername, const QString &albumname,
                                         const QString &duration, const QString &coverurl)
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = ADD_SONG_TO_PLAYLIST;
    QJsonObject params;
    params["songname"] = songname;
    params["songhash"] = songhash;
    params["singername"] = singername;
    params["albumname"] = albumname;
    params["duration"] = duration;
    params["coverurl"] = coverurl;
    json["params"] = params;
    sendJson(json);
}

void WebSocketClient::removeSongFromTogether(const QString &songhash)
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = REMOVE_SONG_FROM_PLAYLIST;
    QJsonObject params;
    params["songhash"] = songhash;
    json["params"] = params;
    sendJson(json);
}

void WebSocketClient::playNextTogether()
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = PLAY_NEXT_SONG;
    sendJson(json);
}

void WebSocketClient::pauseTogether()
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = PAUSE_SONG;
    sendJson(json);
}

void WebSocketClient::resumeTogether()
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = RESUME_SONG;
    sendJson(json);
}

void WebSocketClient::playTogetherByHash(const QString &songhash)
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = PLAY_BY_SONG_HASH;
    QJsonObject params;
    params["songhash"] = songhash;
    json["params"] = params;
    sendJson(json);
}

void WebSocketClient::upSongByHash(const QString &songhash)
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = UP_SONGBYHASH;
    QJsonObject params;
    params["songhash"] = songhash;
    json["params"] = params;
    sendJson(json);
}

void WebSocketClient::requestPlaylist()
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = GET_PLAYLIST;
    sendJson(json);
}

void WebSocketClient::requestClientList()
{
    QJsonObject json;
    json["userid"] = m_userId;
    json["action"] = GET_CLIENT_LIST;
    sendJson(json);
}

// ==================== 事件处理 ====================

void WebSocketClient::onConnected()
{
    QMutexLocker locker(&m_mutex);

    m_connectionState = Connected;
    m_reconnectAttempts = 0;
    m_currentTogetherSongHash.clear();

    emit connectionStateChanged(m_connectionState);
    emit connectionStatusChanged(true);
    emit logMessage("WebSocket 连接成功");

    if (m_heartbeatTimer)
    {
        m_heartbeatTimer->start();
    }
    playmanager->changeplaylisttype(TOGETHER);

    // 连接成功后主动请求房间状态（播放列表 + 当前歌曲 + 在线用户）
    // 使用 QTimer::singleShot 延迟发送，避免在锁内发送消息
    QTimer::singleShot(100, this, [this]()
                       {
        if (isConnected())
        {
            requestPlaylist();
            requestClientList();
            QJsonObject json;
            json["userid"] = m_userId;
            json["action"] = GET_CUR_SONG_INFO;
            sendJson(json);
        } });
}

void WebSocketClient::onDisconnected()
{
    QMutexLocker locker(&m_mutex);

    m_connectionState = Disconnected;

    emit connectionStateChanged(m_connectionState);
    emit connectionStatusChanged(false);
    emit logMessage("WebSocket 连接断开");

    if (m_heartbeatTimer && m_heartbeatTimer->isActive())
    {
        m_heartbeatTimer->stop();
    }

    // 退出一起听模式，恢复本地播放列表
    playmanager->changeplaylisttype(LOCAL);

    if (m_autoReconnect && m_reconnectAttempts < m_maxReconnectAttempts)
    {
        QTimer::singleShot(m_reconnectInterval, this, &WebSocketClient::tryReconnect);
    }
    else
    {
        emit connectFail();
    }
}

void WebSocketClient::onTextMessageReceived(const QString &message)
{
    emit messageReceived(message);

    QJsonObject json = parseJson(message);
    if (json.isEmpty())
    {
        return;
    }
    emit jsonReceived(json);

    handleServerMessage(json);
}

void WebSocketClient::onBinaryMessageReceived(const QByteArray &data)
{
    emit binaryReceived(data);
}

void WebSocketClient::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);

    QString errorString = m_webSocket->errorString();
    emit errorOccurred(errorString);
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

    m_connectionState = Reconnecting;
    emit connectionStateChanged(m_connectionState);

    connectToServer();
}

// ==================== 服务器消息分发 ====================

void WebSocketClient::handleServerMessage(const QJsonObject &json)
{
    int action = json["action"].toInt(-1);

    switch (action)
    {
    case BROADCAST_SONG_INFO:
        if (json.contains("data") && json["data"].isObject())
        {
            handleSongInfoBroadcast(json["data"].toObject());
        }
        break;

    case BROADCAST_SONG_PROGRESS:
        if (json.contains("data") && json["data"].isObject())
        {
            handleSongProgressBroadcast(json["data"].toObject());
        }
        break;

    case BROADCAST_SONG_LIST:
        handleSongListBroadcast(json);
        break;

    case BROADCAST_CLIENT_LIST:
        handleClientListBroadcast(json);
        break;

    case GET_CUR_SONG_INFO:
        // 请求当前歌曲信息的响应，格式与 BROADCAST_SONG_INFO 相同
        if (json.contains("data") && json["data"].isObject())
        {
            handleSongInfoBroadcast(json["data"].toObject());
        }
        break;

    case GET_PLAYLIST:
        // 请求播放列表的响应，格式与 BROADCAST_SONG_LIST 相同
        handleSongListBroadcast(json);
        break;

    case GET_CLIENT_LIST:
        handleClientListBroadcast(json);
        break;

    default:
        // success/error 响应等，无需特殊处理
        break;
    }
}

void WebSocketClient::handleSongInfoBroadcast(const QJsonObject &data)
{
    QString songHash = data["songhash"].toString();
    QString songUrl = data["song_url"].toString();
    QString songName = data["songname"].toString();
    QString singerName = data["singername"].toString();
    QString coverUrl = data["cover_url"].toString();
    QString albumName = data["album_name"].toString();
    QString duration = data["duration"].toString();
    double playedPercent = data["played_percent"].toDouble();
    int isPlaying = data["is_playing"].toInt();

    // 通知 QML 更新
    emit songInfoUpdated(data);

    if (songHash != m_currentTogetherSongHash)
    {
        // 切歌：加载新歌曲
        m_currentTogetherSongHash = songHash;
        // 设置 seek 进度，歌曲加载完成后自动 seek
        if (playedPercent > 0)
        {
            playmanager->setTogetherSeekPercent(playedPercent);
        }
        playmanager->playTogetherSongFromServer(songUrl, songName, songHash,
                                                  singerName, coverUrl, albumName,
                                                  duration);
    }
    else
    {
        // 同一首歌：检测是否为循环重播（进度回到起点）
        if (isPlaying == 1 && playedPercent < 0.05)
        {
            playmanager->playTogetherSongFromServer(songUrl, songName, songHash,
                                                      singerName, coverUrl, albumName,
                                                      duration);
            return;
        }

        // 正常进度同步
        if (isPlaying == 0)
        {
            playmanager->setPaused(true);
        }
        else
        {
            playmanager->setPaused(false);
            // 进度偏差超过 3 秒才 seek，避免频繁跳动
            float localPercent = playmanager->getpercent();
            qint64 durationMs = 0;
            // duration 格式可能是 "mm:ss" 或秒数字符串
            if (duration.contains(":"))
            {
                QStringList parts = duration.split(":");
                if (parts.size() == 2)
                {
                    durationMs = (parts[0].toInt() * 60 + parts[1].toInt()) * 1000;
                }
            }
            else
            {
                durationMs = static_cast<qint64>(duration.toDouble() * 1000);
            }
            if (durationMs > 0)
            {
                double diff = qAbs(localPercent - playedPercent) * durationMs / 1000.0;
                if (diff > 3.0)
                {
                    playmanager->seekToPercent(playedPercent);
                }
            }
        }
    }
}

void WebSocketClient::handleSongProgressBroadcast(const QJsonObject &data)
{
    QString songHash = data["songhash"].toString();
    double playedPercent = data["played_percent"].toDouble();
    int isPlaying = data["is_playing"].toInt();

    if (songHash.isEmpty())
        return;

    if (songHash != m_currentTogetherSongHash)
    {
        // hash 不一致说明切歌了，主动请求完整歌曲信息
        QJsonObject req;
        req["action"] = GET_CUR_SONG_INFO;
        req["userid"] = m_userId;
        sendJson(req);
        return;
    }

    // 同一首歌：同步播放状态和进度
    if (isPlaying == 0)
    {
        playmanager->setPaused(true);
    }
    else
    {
        playmanager->setPaused(false);
        float localPercent = playmanager->getpercent();
        if (localPercent > 0 && qAbs(localPercent - playedPercent) > 0.01)
        {
            playmanager->seekToPercent(playedPercent);
        }
    }
}

void WebSocketClient::handleSongListBroadcast(const QJsonObject &json)
{
    if (json.contains("playlist") && json["playlist"].isArray())
    {
        QJsonArray playlist = json["playlist"].toArray();
        playmanager->syncTogetherPlaylistFromServer(playlist);
    }
    // 合并消息可能同时包含 song_info
    if (json.contains("song_info") && json["song_info"].isObject())
    {
        handleSongInfoBroadcast(json["song_info"].toObject());
    }
}

void WebSocketClient::handleClientListBroadcast(const QJsonObject &json)
{
    emit clientListUpdated(json);
}

// ==================== JSON 工具 ====================

QJsonObject WebSocketClient::parseJson(const QString &jsonString)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8(), &parseError);

    if (parseError.error != QJsonParseError::NoError)
    {
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
