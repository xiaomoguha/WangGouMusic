#include "ApiClient.h"

#include <QJsonDocument>
#include <QJsonParseError>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>
#include <QDebug>

ApiClient& ApiClient::instance()
{
    // Meyers Singleton：线程安全（C++11 起 static local 由编译器保证）
    static ApiClient s_instance;
    return s_instance;
}

ApiClient::ApiClient(QObject* parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this))
{
    // 统一 SSL/TLS 配置可在此扩展（目前用 Qt 默认）
}

ApiClient::~ApiClient()
{
    // 中止所有活跃 reply 并清理超时 timer
    const auto replies = m_timeoutTimers.keys();
    for (QNetworkReply* reply : replies) {
        if (reply) {
            reply->abort();
            reply->deleteLater();
        }
        QTimer* t = m_timeoutTimers.value(reply);
        if (t) t->deleteLater();
    }
    m_timeoutTimers.clear();
}

void ApiClient::setUserAgent(const QString& ua)
{
    m_userAgent = ua;
}

void ApiClient::setAuthToken(const QString& token)
{
    m_authToken = token;
}

void ApiClient::setDefaultTimeout(int ms)
{
    if (ms > 0) m_defaultTimeout = ms;
}

void ApiClient::setBaseHeader(const QString& name, const QString& value)
{
    m_baseHeaders.insert(name, value);
}

void ApiClient::clearBaseHeaders()
{
    m_baseHeaders.clear();
}

void ApiClient::setupReply(QNetworkReply* reply,
                           int timeoutMs,
                           const QString& url,
                           SuccessCallback onSuccess,
                           ErrorCallback   onError)
{
    if (!reply) return;

    const int t = (timeoutMs > 0) ? timeoutMs : m_defaultTimeout;

    // 每个 reply 配一个 QTimer 做超时
    QTimer* timer = new QTimer(reply);
    timer->setSingleShot(true);
    timer->setInterval(t);
    m_timeoutTimers.insert(reply, timer);

    connect(timer, &QTimer::timeout, this, [this, reply, url, onError]() {
        if (!reply) return;
        if (reply->isRunning()) {
            reply->abort();
            if (onError) onError(QStringLiteral("request timeout"), 0);
            emit globalErrorOccurred(url, QStringLiteral("request timeout"), 0);
        }
    });
    timer->start();

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, url, onSuccess, onError, timer]() {
        timer->stop();
        m_timeoutTimers.remove(reply);
        timer->deleteLater();

        if (!reply) return;
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (reply->error() != QNetworkReply::NoError) {
            const QString err = reply->errorString();
            reply->deleteLater();
            if (onError) onError(err, httpStatus);
            emit globalErrorOccurred(url, err, httpStatus);
            return;
        }

        const QByteArray body = reply->readAll();
        reply->deleteLater();
        if (onSuccess) onSuccess(body);
    });
}

QNetworkReply* ApiClient::get(const QString& url,
                              SuccessCallback onSuccess,
                              ErrorCallback   onError,
                              int             timeoutMs)
{
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    if (!m_authToken.isEmpty()) {
        req.setRawHeader("Authorization", "Bearer " + m_authToken.toUtf8());
    }
    for (auto it = m_baseHeaders.constBegin(); it != m_baseHeaders.constEnd(); ++it) {
        req.setRawHeader(it.key().toUtf8(), it.value().toUtf8());
    }

    QNetworkReply* reply = m_nam->get(req);
    setupReply(reply, timeoutMs, url, std::move(onSuccess), std::move(onError));
    return reply;
}

QNetworkReply* ApiClient::post(const QString& url,
                               const QByteArray& body,
                               SuccessCallback onSuccess,
                               ErrorCallback   onError,
                               int             timeoutMs)
{
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    if (!m_authToken.isEmpty()) {
        req.setRawHeader("Authorization", "Bearer " + m_authToken.toUtf8());
    }
    for (auto it = m_baseHeaders.constBegin(); it != m_baseHeaders.constEnd(); ++it) {
        req.setRawHeader(it.key().toUtf8(), it.value().toUtf8());
    }

    QNetworkReply* reply = m_nam->post(req, body);
    setupReply(reply, timeoutMs, url, std::move(onSuccess), std::move(onError));
    return reply;
}

QNetworkReply* ApiClient::getJson(const QString& url,
                                  JsonSuccessCb   onSuccess,
                                  JsonErrorCb     onError,
                                  int             timeoutMs)
{
    auto wrapped = [onSuccess, onError](QByteArray body) {
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(body, &perr);
        if (perr.error != QJsonParseError::NoError) {
            if (onError) onError(QStringLiteral("JSON parse error: ") + perr.errorString(), 0);
            return;
        }
        if (!doc.isObject()) {
            if (onError) onError(QStringLiteral("JSON root is not an object"), 0);
            return;
        }
        if (onSuccess) onSuccess(doc.object());
    };
    return get(url, wrapped,
              [onError](QString err, int code) { if (onError) onError(err, code); },
              timeoutMs);
}

QNetworkReply* ApiClient::postJson(const QString& url,
                                   const QJsonObject& body,
                                   JsonSuccessCb   onSuccess,
                                   JsonErrorCb     onError,
                                   int             timeoutMs)
{
    const QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    auto wrapped = [onSuccess, onError](QByteArray resp) {
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(resp, &perr);
        if (perr.error != QJsonParseError::NoError) {
            if (onError) onError(QStringLiteral("JSON parse error: ") + perr.errorString(), 0);
            return;
        }
        if (!doc.isObject()) {
            if (onError) onError(QStringLiteral("JSON root is not an object"), 0);
            return;
        }
        if (onSuccess) onSuccess(doc.object());
    };
    return post(url, payload, wrapped,
               [onError](QString err, int code) { if (onError) onError(err, code); },
               timeoutMs);
}
