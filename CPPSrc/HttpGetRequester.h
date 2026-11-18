#ifndef HTTPGETREQUESTER_H
#define HTTPGETREQUESTER_H

#include <QObject>
#include <QString>
#include <QByteArray>

class QNetworkReply;

// 通用 HTTP GET 请求封装
// 外部接口（信号/槽）保持向后兼容，内部实现已迁移到 ApiClient 单例。
class HttpGetRequester : public QObject
{
    Q_OBJECT
public:
    explicit HttpGetRequester(int timeoutMs = 10000, QObject *parent = nullptr);
    ~HttpGetRequester() override;

    // 发起异步 GET 请求
    Q_INVOKABLE void fetchData(const QString &url);

signals:
    void dataReceived(const QByteArray &data);
    void requestFailed(const QString &error);
    void requestTimeout();

private:
    void startRequest(const QString &url);
    void abortCurrent();

    int m_timeoutMs;
    QNetworkReply *m_currentReply = nullptr;
};

#endif // HTTPGETREQUESTER_H
