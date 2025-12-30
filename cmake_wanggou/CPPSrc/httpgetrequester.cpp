#include "HttpGetRequester.h"
#include <QDebug>

HttpGetRequester::HttpGetRequester(int timeoutMs, QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_timeoutTimer(new QTimer(this))
{
    // 设置单次触发定时器
    m_timeoutTimer->setSingleShot(true);
    connect(m_timeoutTimer, &QTimer::timeout, this, &HttpGetRequester::handleTimeout);
    setTimeout(timeoutMs);
}

void HttpGetRequester::setTimeout(int milliseconds)
{
    m_timeoutTimer->setInterval(milliseconds);
}

void HttpGetRequester::setHeader(const QByteArray &name, const QByteArray &value)
{
    m_customHeaders[name] = value;
}

void HttpGetRequester::clearHeaders()
{
    m_customHeaders.clear();
}

void HttpGetRequester::fetchData(const QString &url)
{
    // 清理之前的请求（如果存在）
    cleanupReply();

    QNetworkRequest request;
    request.setUrl(QUrl(url));

    // 设置默认User-Agent
    request.setHeader(QNetworkRequest::UserAgentHeader, "MyApp/1.0");

    // 添加自定义头
    for (auto it = m_customHeaders.constBegin(); it != m_customHeaders.constEnd(); ++it)
    {
        request.setRawHeader(it.key(), it.value());
    }

    // 发送异步GET请求
    m_currentReply = m_networkManager->get(request);

    // 连接信号槽
    connect(m_currentReply, &QNetworkReply::finished, this, &HttpGetRequester::handleFinished);
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError error) {
        Q_UNUSED(error)
        emit requestFailed(m_currentReply->errorString());
        cleanupReply();
    });

    // 启动超时定时器
    m_timeoutTimer->start();
}

void HttpGetRequester::handleFinished()
{
    // 停止超时定时器
    m_timeoutTimer->stop();

    if (m_currentReply && m_currentReply->error() == QNetworkReply::NoError)
    {
        QByteArray response = m_currentReply->readAll();
        emit dataReceived(response);
    }

    cleanupReply();
}

void HttpGetRequester::handleTimeout()
{
    if (m_currentReply) {
        emit requestTimeout();
        m_currentReply->abort(); // 中止请求
        cleanupReply();
    }
}

void HttpGetRequester::cleanupReply()
{
    if (m_currentReply) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
}
