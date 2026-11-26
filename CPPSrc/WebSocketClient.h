#ifndef WEBSOCKETCLIENT_H
#define WEBSOCKETCLIENT_H

#include "playlistmanager.h"
#include "usermanager.h"
#include "models/MessageListModel.h"
#include <QObject>
#include <QWebSocket>
#include <QUrl>
#include <QJsonObject>
#include <QJsonDocument>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVariantList>
#include <QElapsedTimer>

// 与服务端 types.h 中的 enum ctrl 保持一致
enum ServerAction
{
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
    BROADCAST_SONG_PROGRESS,
    // 批量加歌（「添加到一起听」）：与服务端 enum ctrl 同步，追加在末尾保持既有编号不变
    ADD_SONGS_TO_PLAYLIST,
    LIKE_SONG,
    REQUEST_FM_RECOMMEND,
    SUBMIT_FM_RECOMMEND
};

// 聊天 & 操作日志 action（与服务端 types.h 一致）
enum ChatAction
{
    SEND_CHAT = 300,
    BROADCAST_CHAT,
    BROADCAST_ROOM_ACTION
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
    // 消息列表改为 QAbstractListModel:行级 insert/dataChanged 增量更新,
    // 替代原 QVariantList 每次全量替换导致 QML ListView 整表销毁重建的卡顿
    Q_PROPERTY(MessageListModel *chatMessages READ chatMessages CONSTANT)
    Q_PROPERTY(MessageListModel *actionMessages READ actionMessages CONSTANT)
    // 聊天 + 房间动态按时间合并后的单一时间线（一起听页三栏布局使用）
    Q_PROPERTY(MessageListModel *timelineMessages READ timelineMessages CONSTANT)
public:
    explicit WebSocketClient(PlaylistManager *playmanager, UserManager *usermanager, QObject *parent = nullptr);
    ~WebSocketClient() override;
    // 连接状态枚举
    enum ConnectionState
    {
        Disconnected = 0, // 未连接
        Connecting,       // 连接中
        Connected,        // 已连接
    };
    Q_ENUM(ConnectionState)

    // 基本操作
    Q_INVOKABLE void connectToServer();                  // 连接服务器
    Q_INVOKABLE void disconnectFromServer();             // 断开连接
    Q_INVOKABLE void sendJson(const QJsonObject &json);  // 发送JSON数据
    Q_INVOKABLE bool isConnected() const;                // 是否已连接
    Q_INVOKABLE ConnectionState connectionState() const; // 获取连接状态

    // URL 相关
    QString url() const;
    Q_INVOKABLE void setUrl(const QString &roomid, const QString &userid);

    QString Getroomid() const;

    // 一起听操作命令（QML 可调用）
    Q_INVOKABLE void addSongToTogether(
        const QString &songname, const QString &songhash, const QString &singername, const QString &albumname,
        const QString &duration, const QString &coverurl
    );
    Q_INVOKABLE void removeSongFromTogether(const QString &songhash);
    // 点赞/取消点赞（房间内共享）
    Q_INVOKABLE void likeTogetherSong(const QString &songhash);
    Q_INVOKABLE void submitFmRecommendation(const QString &requestId, const QVariantList &songs, bool failed);
    // 批量加歌（歌单「添加到一起听」）：一次消息加一批。
    Q_INVOKABLE void addSongsToTogether(const QVariantList &songs);
    Q_INVOKABLE void playNextTogether();
    Q_INVOKABLE void playTogetherByHash(const QString &songhash);
    Q_INVOKABLE void upSongByHash(const QString &songhash);
    Q_INVOKABLE void requestPlaylist();
    Q_INVOKABLE void requestClientList();
    Q_INVOKABLE void fetchRoomList();
    QVariantList roomList() const;
    MessageListModel *chatMessages() const;
    MessageListModel *actionMessages() const;
    MessageListModel *timelineMessages() const;

    // 聊天
    Q_INVOKABLE void sendChatMessage(const QString &message);
    Q_INVOKABLE void retryMessage(int msgId);

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

    // 聊天 & 操作日志
    void chatMessageReceived(
        const QString &userid, const QString &nickname, const QString &avatarUrl, const QString &message,
        qint64 timestamp
    );
    void roomActionsReceived(const QJsonArray &actions);
    void messageConfirmed(int msgId);
    // 服务器请求本客户端用当前登录账号拉个人 FM（requestId 原样回传）
    void fmRecommendationRequested(const QString &requestId, int want, int timeoutMs);

    // 服务器操作结果通知
    void serverNotice(const QString &message, const QString &mode); // mode: "loading" / "success" / "error"

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &data);
    void onError(QAbstractSocket::SocketError error);

    void sendHeartbeat();
    void checkHeartbeatTimeout();
    void checkAddSongTimeout();

private:
    PlaylistManager *playmanager = nullptr;
    UserManager *usermanager     = nullptr;
    void initializeWebSocket();

    // 服务器消息分发
    void handleServerMessage(const QJsonObject &json);
    // 动态/聊天历史合并进消息模型(去重 + 批量增量追加 + 截断到 200 条)
    void mergeRoomActions(const QJsonArray &actions);
    // allowSeek=false：来自歌单同步消息内嵌 song_info 的调用——服务器的
    // played_percent 只在 5s 定时器里累加，这类快照最多滞后 5s，拿它判 seek
    void handleSongInfoBroadcast(const QJsonObject &data, bool allowSeek = true);
    void handleSongProgressBroadcast(const QJsonObject &data);
    void handleSongListBroadcast(const QJsonObject &json);
    void handleClientListBroadcast(const QJsonObject &json);
    // 向服务器请求房间当前歌曲信息（GET_CUR_SONG_INFO）。triggerHash 用于节流：
    // 同一个 hash 1 秒内只请求一次，避免异常包触发请求风暴
    void requestCurrentSongInfo(const QString &triggerHash);
    // 一起听进度纠偏：与房间进度偏差超过 3 秒才 seek。durationMs 为房间歌曲的真实时长
    // （<= 0 时退回本地播放器时长）；本地音频比房间歌曲短时不纠偏（见实现注释）
    void seekTogetherIfDrifted(double playedPercent, qint64 durationMs, bool verbose);

    // JSON 工具方法
    QJsonObject parseJson(const QString &jsonString);

    // 私有成员变量
    QWebSocket *m_webSocket;
    QUrl m_serverUrl;
    ConnectionState m_connectionState;
    QString Roomid;
    QString m_userId;

    // 当前一起听播放的歌曲 hash，用于判断是否切歌
    QString m_currentTogetherSongHash;
    // 房间当前歌曲的真实时长（毫秒，服务器下发的 duration）：进度纠偏按它换算偏差秒数，
    // 不依赖本地播放器时长（本地缓存可能是时长不符的片段）
    qint64 m_currentTogetherDurationMs = 0;
    // 本地音频比房间歌曲短的歌曲 hash：只打一次日志
    QString m_shortAudioSongHash;
    // 当前歌曲信息请求节流：同一 hash 上次请求的时刻
    QString m_curSongReqHash;
    qint64 m_curSongReqAtMs = 0;
    // 最近一次同步队列列表时，房间当前歌的 hash（列表与这首歌的房间状态一致）：
    // 之后若靠 200/213 才发现切歌，据此判断要不要补拉一次列表
    QString m_lastPlaylistSyncSongHash;
    // 一起听：本地暂停期间服务器切歌时暂存的新歌信息，手动播放后再补切
    QJsonObject m_deferredTogetherSong;

    // 心跳机制
    QTimer *m_heartbeatTimer;
    QTimer *m_heartbeatTimeoutTimer;
    int m_heartbeatInterval;
    QElapsedTimer m_lastMessageTime;
    static constexpr int HEARTBEAT_TIMEOUT_FACTOR = 5; // 超过 N 倍心跳间隔无响应则断开

    // 房间列表
    QNetworkAccessManager m_httpManager;
    QVariantList m_roomList;

    // 消息存储（切换页面不丢失）:行级增量 C++ 模型,聊天/系统动态各一份
    MessageListModel *m_chatModel     = nullptr;
    MessageListModel *m_actionModel   = nullptr;
    MessageListModel *m_timelineModel = nullptr;

    // 待确认的添加歌曲操作（单曲/批量共用同一个超时计时器）
    bool m_pendingAddSong         = false;
    QTimer *m_addSongTimeoutTimer = nullptr;
    void ensureAddSongTimeoutTimer();

    // 消息发送状态追踪
    int m_msgIdCounter = 0;
    QMap<int, QTimer *> m_pendingMsgTimers;
    void markMessageFailed(int msgId);
};

#endif // WEBSOCKETCLIENT_H
