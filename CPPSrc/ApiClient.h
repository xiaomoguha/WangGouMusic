#pragma once

#include <QObject>
#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QMap>
#include <QString>
#include <functional>

class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;
class QTimer;

/**
 * @brief 全局 HTTP/JSON 网络访问单例
 *
 * 统一管理 QNetworkAccessManager、User-Agent、Token 注入、超时、错误处理。
 * 所有需要网络访问的 manager（UserManager / SearchComplex / GetHostSearch /
 * PlaylistManager / AppUpdater / HttpGetRequester）都应通过本类发起请求，
 * 避免每个 manager 各自 new QNetworkAccessManager 造成的资源浪费与配置分散。
 *
 * 本类不直接暴露给 QML，C++ 端以 std::function 回调方式使用。
 */
class ApiClient : public QObject
{
    Q_OBJECT
public:
    /// 成功回调：参数为响应 body
    using SuccessCallback = std::function<void(QByteArray)>;
    /// 失败回调：参数为错误描述、HTTP 状态码（无 HTTP 状态时为 0）
    using ErrorCallback = std::function<void(QString /*error*/, int /*httpStatus*/)>;
    /// JSON 成功回调：参数为解析后的根 JSON 对象
    using JsonSuccessCb = std::function<void(QJsonObject)>;
    /// JSON 失败回调
    using JsonErrorCb = std::function<void(QString /*error*/, int /*httpStatus*/)>;

    /// 获取全局唯一实例（线程安全：Meyers Singleton）
    static ApiClient &instance();

    // ── 配置 ─────────────────────────────────────────────
    /// 设置 User-Agent（影响所有后续请求）
    void setUserAgent(const QString &ua);
    /// 设置鉴权 Token（自动以 "Authorization: Bearer <token>" 注入到所有请求）
    void setAuthToken(const QString &token);

    // ── 原始 HTTP ────────────────────────────────────────
    /// GET 请求。timeoutMs <= 0 表示用 defaultTimeout；extraHeaders 为附加请求头（如管理密钥）
    QNetworkReply *get(
        const QString &url, SuccessCallback onSuccess, ErrorCallback onError = nullptr, int timeoutMs = -1,
        const QMap<QString, QString> &extraHeaders = {}
    );
    // ── JSON 便捷（自动 Content-Type: application/json，自动 parse 响应） ──
    /// GET 并解析为 JSON 对象
    QNetworkReply *
    getJson(const QString &url, JsonSuccessCb onSuccess, JsonErrorCb onError = nullptr, int timeoutMs = -1, const QMap<QString, QString> &extraHeaders = {});
    /// POST JSON 对象
    QNetworkReply *postJson(
        const QString &url, const QJsonObject &body, JsonSuccessCb onSuccess, JsonErrorCb onError = nullptr,
        int timeoutMs = -1, const QMap<QString, QString> &extraHeaders = {}
    );

    /// 检查响应是否为酷狗 20018（登录态被吊销/被踢），是则发 tokenKicked()。
    /// getJson/postJson 已内置；绕过 JSON 便捷层自行解析的调用方（如 HistoryManager）手动调用。
    void checkKicked(const QJsonObject &root);

signals:
    /// 任何接口返回 20018 时发出。UserManager 接收后清登录态并引导重新登录。
    void tokenKicked();

private:
    explicit ApiClient(QObject *parent = nullptr);
    ~ApiClient() override;
    ApiClient(const ApiClient &)            = delete;
    ApiClient &operator=(const ApiClient &) = delete;

    /// 给 reply 配置超时 timer / 错误处理 / 默认头
    void setupReply(
        QNetworkReply *reply, int timeoutMs, const QString &url, SuccessCallback onSuccess, ErrorCallback onError
    );

    /// POST 表单/任意 body（仅内部使用，由 postJson 调用）
    QNetworkReply *post(
        const QString &url, const QByteArray &body, SuccessCallback onSuccess, ErrorCallback onError = nullptr,
        int timeoutMs = -1, const QMap<QString, QString> &extraHeaders = {}
    );

    /// 给请求附加额外请求头（覆盖同名默认头）
    static void applyExtraHeaders(QNetworkRequest &req, const QMap<QString, QString> &headers);

    QNetworkAccessManager *m_nam;
    QString m_userAgent = QStringLiteral("WangGouMusic/0.5.7");
    QString m_authToken;
    int m_defaultTimeout = 10000;
    QHash<QNetworkReply *, QTimer *> m_timeoutTimers; // 跟踪活跃 reply 的超时
};
