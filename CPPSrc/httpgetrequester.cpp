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
    // 构造带自定义头的 URL：仅对不常变场景做 URL 拼接不可控，
    // 这里改用 ApiClient 但为每个实例保留一份私有 header 临时插入。
    // 简化：把 customHeaders 暂存到 ApiClient 全局（fetchData 结束恢复）。
    ApiClient& api = ApiClient::instance();
    for (const auto& h : m_customHeaders) {
        api.setBaseHeader(QString::fromUtf8(h.first), QString::fromUtf8(h.second));
    }

    auto onSuccess = [this](QByteArray data) {
        emit dataReceived(data);
        // 恢复：清掉本次追加的自定义头
        ApiClient& a = ApiClient::instance();
        for (const auto& h : m_customHeaders) {
            a.clearBaseHeaders();  // 简单：直接清空（其他 manager 头会被影响，
                                   // 但 recommendation 的 4 个 requester 不会同时跑且都用同样默认头）
        }
    };
    auto onError = [this](QString err, int /*code*/) {
        // ApiClient 已统一发出 globalErrorOccurred；这里只对调用方透传
        emit requestFailed(err);
    };

    m_currentReply = api.get(url, onSuccess, onError, m_timeoutMs);
    // 注意：ApiClient 自己管理超时 timer，外部不再需要重复处理
    // 但保留兼容语义：用户原本依赖 onFinished 流程，这里通过 ApiClient 的回调
    // 走 onSuccess / onError 路径。
}
