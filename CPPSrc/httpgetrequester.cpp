#include "HttpGetRequester.h"
#include "ApiClient.h"

#include <QDebug>
#include <QNetworkReply>

HttpGetRequester::HttpGetRequester(int timeoutMs, QObject *parent)
    : QObject(parent), m_timeoutMs(timeoutMs > 0 ? timeoutMs : 10000)
{
}

void HttpGetRequester::setTimeout(int milliseconds)
{
    if (milliseconds > 0) m_timeoutMs = milliseconds;
}

void HttpGetRequester::setHeader(const QByteArray &name, const QByteArray &value)
{
    // 替换同名头
    for (auto& h : m_customHeaders) {
        if (h.first == name) { h.second = value; return; }
    }
    m_customHeaders.append({name, value});
}

void HttpGetRequester::clearHeaders()
{
    m_customHeaders.clear();
}

void HttpGetRequester::abortCurrent()
{
    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
}

void HttpGetRequester::fetchData(const QString &url)
{
    abortCurrent();
    startRequest(url);
}

void HttpGetRequester::startRequest(const QString &url)
{
    ApiClient& api = ApiClient::instance();

    // ⚠️ 修复：请求完成回调中必须将 m_currentReply 置 null，
    // 否则 ApiClient 内部的 deleteLater 会留下悬空指针，
    // 下次 fetchData → abortCurrent() 访问 m_currentReply 时段错误。
    auto onSuccess = [this](QByteArray data) {
        m_currentReply = nullptr;   // ApiClient 已完成删除
        emit dataReceived(data);
    };
    auto onError = [this](QString err, int /*code*/) {
        m_currentReply = nullptr;   // ApiClient 已完成删除
        emit requestFailed(err);
    };

    m_currentReply = api.get(url, onSuccess, onError, m_timeoutMs);
}
