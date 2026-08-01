#ifndef HTTPGETREQUESTER_H
#define HTTPGETREQUESTER_H

#include <QObject>
#include <QString>
#include <QByteArray>

class QNetworkReply;

/**
 * @brief 通用 HTTP GET 请求封装
 *
 * 外部接口（信号/槽）保持向后兼容，内部实现已迁移到 ApiClient 单例。
 * 主要使用者：recommendation 的 4 个 requester 实例（m_topSongsRequester /
 * m_topPlaylistsRequester / m_playlistTracksRequester / m_lazyRequester）。
 *
 * 单实例只持有一个活跃 reply：fetchData 时若已有未完成请求会被 abort。
 */
class HttpGetRequester : public QObject
{
    Q_OBJECT
public:
    explicit HttpGetRequester(int timeoutMs = 10000, QObject *parent = nullptr);

    /// 发起异步 GET 请求
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
