#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include <QObject>
#include "playlistmanager.h"
#include "usermanager.h"
#include <QWebSocket>
#include <QUrl>
#include <QJsonObject>
#include <QJsonDocument>
#include <QTimer>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVariantList>

// 与服务端 types.h 中的 enum ctrl 保持一致
enum ServerAction {
    GET_CUR_SONG_INFO = 200,
    PLAY_NEXT_SONG,
    PLAY_BY_SONG_HASH,
    PAUSE_SONG,
    RESUME_SONG,
    ADD_SONG_TO_PLAYLIST,
    REMOVE_SONG_FROM_PLAYLIST,
    UP_SONGBYHASH,
    GET_PLAYLIST,
    BROADCAST_SONG_INFO,
    BROADCAST_SONG_LIST,
    BROADCAST_CLIENT_LIST,
    GET_CLIENT_LIST,
    BROADCAST_SONG_PROGRESS
};

class WebSocketClient : public QObject
{
    Q_OBJECT
    // 暴露给 QML 的属性
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString url READ url NOTIFY urlChanged)
    Q_PROPERTY(QString Roomid READ Getroomid NOTIFY roomidChanged)
    Q_PROPERTY(ConnectionState connectionState READ connectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(QVariantList roomList READ roomList NOTIFY roomListUpdated)
public:
    explicit WebSocketClient(PlaylistManager *playmanager, UserManager *usermanager, QObject *parent = nullptr);
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
    Q_INVOKABLE void setUrl(const QString &roomid,const QString &userid);

    QString Getroomid() const;

    // 配置
    Q_INVOKABLE void setAutoReconnect(bool enable);      // 设置自动重连
    Q_INVOKABLE void setHeartbeatInterval(int seconds);  // 设置心跳间隔

    // 一起听操作命令（QML 可调用）
    Q_INVOKABLE void addSongToTogether(const QString &songname, const QString &songhash,
                                        const QString &singername, const QString &albumname,
                                        const QString &duration, const QString &coverurl);
    Q_INVOKABLE void removeSongFromTogether(const QString &songhash);
    Q_INVOKABLE void playNextTogether();
    Q_INVOKABLE void pauseTogether();
    Q_INVOKABLE void resumeTogether();
    Q_INVOKABLE void playTogetherByHash(const QString &songhash);
    Q_INVOKABLE void upSongByHash(const QString &songhash);
    Q_INVOKABLE void requestPlaylist();
    Q_INVOKABLE void requestClientList();
    Q_INVOKABLE void fetchRoomList();
    QVariantList roomList() const;

signals:
    void connectionStatusChanged(bool connected);
    void connectionStateChanged(WebSocketClient::ConnectionState state);
    void urlChanged(const QString &url);
    void roomidChanged();
    void connectFail();
    void messageReceived(const QString &message);
    void jsonReceived(const QJsonObject &json);
    void binaryReceived(const QByteArray &data);
    void errorOccurred(const QString &error);
    void logMessage(const QString &log);

    // 一起听专用信号（QML 绑定用）
    void songInfoUpdated(const QJsonObject &data);
    void clientListUpdated(const QJsonObject &data);
    void roomListUpdated();

public slots:
    Q_INVOKABLE void sendString(const QString &message);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &data);
    void onError(QAbstractSocket::SocketError error);

    void sendHeartbeat();
    void tryReconnect();

private:
    PlaylistManager *playmanager = nullptr;
    UserManager *usermanager = nullptr;
    void initializeWebSocket();

    // 服务器消息分发
    void handleServerMessage(const QJsonObject &json);
    void handleSongInfoBroadcast(const QJsonObject &data);
    void handleSongProgressBroadcast(const QJsonObject &data);
    void handleSongListBroadcast(const QJsonObject &json);
    void handleClientListBroadcast(const QJsonObject &json);

    // JSON 工具方法
    QJsonObject parseJson(const QString &jsonString);
    QString jsonToString(const QJsonObject &json);

    // 私有成员变量
    QWebSocket *m_webSocket;
    QUrl m_serverUrl;
    ConnectionState m_connectionState;
    bool m_autoReconnect;
    int m_reconnectInterval;
    int m_reconnectAttempts;
    int m_maxReconnectAttempts;
    QString Roomid;
    QString m_userId;

    // 当前一起听播放的歌曲 hash，用于判断是否切歌
    QString m_currentTogetherSongHash;

    // 心跳机制
    QTimer *m_heartbeatTimer;
    int m_heartbeatInterval;

    // 线程安全
    QMutex m_mutex;

    // 房间列表
    QNetworkAccessManager m_httpManager;
    QVariantList m_roomList;
};

#endif // WEBSOCKETCLIENT_H
