#ifndef HTTPGETREQUESTER_H
#define HTTPGETREQUESTER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QUrl>
#include <QTimer>

class HttpGetRequester : public QObject
{
    Q_OBJECT
public:
    // 构造函数，可以设置超时时间（单位：毫秒）
    explicit HttpGetRequester(int timeoutMs = 10000, QObject *parent = nullptr);

    // 设置请求超时时间
    void setTimeout(int milliseconds);

    // 异步GET请求方法
    void fetchData(const QString &url);

    // 设置自定义HTTP头
    void setHeader(const QByteArray &name, const QByteArray &value);

    // 清除所有自定义头
    void clearHeaders();

signals:
    // 数据获取成功的信号
    void dataReceived(const QByteArray &data);
    // 请求失败的信号
    void requestFailed(const QString &error);
    // 请求超时的信号
    void requestTimeout();

private slots:
    void handleFinished();
    void handleTimeout();

private:
    QNetworkAccessManager *m_networkManager;
    QTimer *m_timeoutTimer;
    QMap<QByteArray, QByteArray> m_customHeaders;
    QNetworkReply *m_currentReply = nullptr;

    void cleanupReply();
};

#endif // HTTPGETREQUESTER_H
