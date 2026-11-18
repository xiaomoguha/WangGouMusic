#include "HttpGetRequester.h"
#include "ApiClient.h"

#include <QDebug>
#include <QNetworkReply>

HttpGetRequester::HttpGetRequester(int timeoutMs, QObject *parent)
    : QObject(parent), m_timeoutMs(timeoutMs > 0 ? timeoutMs : 10000)
{
}

HttpGetRequester::~HttpGetRequester()
{
    // 析构时清理挂起请求：先断开自身信号（接收方 manager 可能已析构），
    // 再 abort 当前 reply——否则 ApiClient 析构 abort 时回调会访问本对象（SIGSEGV）
    QObject::disconnect(this, nullptr, nullptr, nullptr);
    QNetworkReply *reply = m_currentReply;
    m_currentReply       = nullptr;
    if (reply)
    {
        reply->abort();
        reply->deleteLater();
    }
}

void HttpGetRequester::abortCurrent()
{
    // abort() 会同步触发 QNetworkReply::finished 信号（同线程为 DirectConnection），
    // finished 回调中 onError 会执行 m_currentReply = nullptr。
    QNetworkReply *reply = m_currentReply;
    m_currentReply       = nullptr;
    if (reply)
    {
        reply->abort();
        reply->deleteLater();
    }
}

void HttpGetRequester::fetchData(const QString &url)
{
    abortCurrent();
    startRequest(url);
}

void HttpGetRequester::startRequest(const QString &url)
{
    ApiClient &api = ApiClient::instance();

    // 修复：请求完成回调中必须将 m_currentReply 置 null，
    // 否则 ApiClient 内部的 deleteLater 会留下悬空指针，
    auto onSuccess = [this](QByteArray data)
    {
        m_currentReply = nullptr; // ApiClient 已完成删除
        emit dataReceived(data);
    };
    auto onError = [this](QString err, int /*code*/)
    {
        m_currentReply = nullptr; // ApiClient 已完成删除
        emit requestFailed(err);
    };

    m_currentReply = api.get(url, onSuccess, onError, m_timeoutMs);
}
