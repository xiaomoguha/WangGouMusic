#include "ApiClient.h"

#include <QJsonDocument>
#include <QJsonParseError>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>
#include <QDebug>

ApiClient &ApiClient::instance()
{
    // Meyers Singleton：线程安全（C++11 起 static local 由编译器保证）
    static ApiClient s_instance;
    return s_instance;
}

ApiClient::ApiClient(QObject *parent) : QObject(parent), m_nam(new QNetworkAccessManager(this))
{
    // 统一 SSL/TLS 配置可在此扩展（目前用 Qt 默认）
}

ApiClient::~ApiClient()
{
    // 中止所有活跃 reply 并清理超时 timer。
    // 必须先断掉以 this 为 context 的连接再 abort：abort()/QNAM 析构会同步派发
    // finished/errorOccurred，若不先断开，回调 lambda 会访问早已析构的
    // HttpGetRequester 等调用方对象 → SIGSEGV（退出时崩溃）
    const auto replies = m_timeoutTimers.keys();
    for (QNetworkReply *reply : replies)
    {
        if (reply)
        {
            QObject::disconnect(reply, nullptr, this, nullptr);
            reply->abort();
            reply->deleteLater();
        }
        QTimer *t = m_timeoutTimers.value(reply);
        if (t)
        {
            QObject::disconnect(t, nullptr, this, nullptr);
            t->deleteLater();
        }
    }
    m_timeoutTimers.clear();
}

void ApiClient::setUserAgent(const QString &ua)
{
    m_userAgent = ua;
}

void ApiClient::setAuthToken(const QString &token)
{
    m_authToken = token;
}

void ApiClient::setupReply(
    QNetworkReply *reply, int timeoutMs, const QString &url, SuccessCallback onSuccess, ErrorCallback onError
)
{
    if (!reply)
        return;

    const int t = (timeoutMs > 0) ? timeoutMs : m_defaultTimeout;

    // 每个 reply 配一个 QTimer 做超时
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    timer->setInterval(t);
    m_timeoutTimers.insert(reply, timer);

    connect(
        timer, &QTimer::timeout, this,
        [this, reply, onError]()
        {
            if (!reply)
                return;
            if (reply->isRunning())
            {
                reply->abort();
                if (onError)
                    onError(QStringLiteral("request timeout"), 0);
            }
        }
    );
    timer->start();

    connect(
        reply, &QNetworkReply::finished, this,
        [this, reply, onSuccess, onError, timer]()
        {
            timer->stop();
            m_timeoutTimers.remove(reply);
            timer->deleteLater();

            if (!reply)
                return;
            const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            if (reply->error() != QNetworkReply::NoError)
            {
                const QString err = reply->errorString();
                const int status  = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                // 请求被取消（abort：如重新搜索/切页面丢弃旧请求，或超时 abort）：
                // device 已关闭，readAll 会报 "QIODevice::read: device not open"，且本就无 body，
                // 直接走 onError，不解析。
                if (reply->error() == QNetworkReply::OperationCanceledError)
                {
                    reply->deleteLater();
                    if (onError)
                        onError(err, status);
                    return;
                }
                // 服务器业务错误以非 2xx（如 502）+ 可解析 JSON（status/error_code）返回，
                // body 仍含有效业务信息，按正常响应解析（如 token 过期让 refreshToken 能清登录态）。
                // 真网络错误（断连/网关 502 的 HTML 页）body 为空或非 JSON，仍走 onError。
                const QByteArray body = reply->readAll();
                reply->deleteLater();
                if (onSuccess && !body.isEmpty())
                {
                    QJsonParseError perr;
                    QJsonDocument::fromJson(body, &perr);
                    if (perr.error == QJsonParseError::NoError)
                    {
                        onSuccess(body);
                        return;
                    }
                }
                if (onError)
                    onError(err, status);
                return;
            }

            const QByteArray body = reply->readAll();
            reply->deleteLater();
            if (onSuccess)
                onSuccess(body);
        }
    );
}

QNetworkReply *ApiClient::get(const QString &url, SuccessCallback onSuccess, ErrorCallback onError, int timeoutMs)
{
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    if (!m_authToken.isEmpty())
    {
        req.setRawHeader("Authorization", "Bearer " + m_authToken.toUtf8());
    }

    QNetworkReply *reply = m_nam->get(req);
    setupReply(reply, timeoutMs, url, std::move(onSuccess), std::move(onError));
    return reply;
}

QNetworkReply *ApiClient::post(
    const QString &url, const QByteArray &body, SuccessCallback onSuccess, ErrorCallback onError, int timeoutMs
)
{
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    if (!m_authToken.isEmpty())
    {
        req.setRawHeader("Authorization", "Bearer " + m_authToken.toUtf8());
    }

    QNetworkReply *reply = m_nam->post(req, body);
    setupReply(reply, timeoutMs, url, std::move(onSuccess), std::move(onError));
    return reply;
}

QNetworkReply *ApiClient::getJson(const QString &url, JsonSuccessCb onSuccess, JsonErrorCb onError, int timeoutMs)
{
    auto wrapped = [onSuccess, onError](QByteArray body)
    {
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(body, &perr);
        if (perr.error != QJsonParseError::NoError)
        {
            if (onError)
                onError(QStringLiteral("JSON parse error: ") + perr.errorString(), 0);
            return;
        }
        if (!doc.isObject())
        {
            if (onError)
                onError(QStringLiteral("JSON root is not an object"), 0);
            return;
        }
        if (onSuccess)
            onSuccess(doc.object());
    };
    return get(
        url, wrapped,
        [onError](QString err, int code)
        {
            if (onError)
                onError(err, code);
        },
        timeoutMs
    );
}

QNetworkReply *ApiClient::postJson(
    const QString &url, const QJsonObject &body, JsonSuccessCb onSuccess, JsonErrorCb onError, int timeoutMs
)
{
    const QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    auto wrapped             = [onSuccess, onError](QByteArray resp)
    {
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(resp, &perr);
        if (perr.error != QJsonParseError::NoError)
        {
            if (onError)
                onError(QStringLiteral("JSON parse error: ") + perr.errorString(), 0);
            return;
        }
        if (!doc.isObject())
        {
            if (onError)
                onError(QStringLiteral("JSON root is not an object"), 0);
            return;
        }
        if (onSuccess)
            onSuccess(doc.object());
    };
    return post(
        url, payload, wrapped,
        [onError](QString err, int code)
        {
            if (onError)
                onError(err, code);
        },
        timeoutMs
    );
}
