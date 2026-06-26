#ifndef HTTPGETREQUESTER_H
#define HTTPGETREQUESTER_H

#include <QObject>
#include <QString>
#include <QByteArray>
#include <functional>

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

    /// 设置请求超时（毫秒）
    Q_INVOKABLE void setTimeout(int milliseconds);

    /// 发起异步 GET 请求
    Q_INVOKABLE void fetchData(const QString &url);

    /// 设置自定义 HTTP 头（仅追加到 User-Agent 后；不影响全局默认头）
    Q_INVOKABLE void setHeader(const QByteArray &name, const QByteArray &value);

    /// 清除所有自定义头
    Q_INVOKABLE void clearHeaders();

signals:
    void dataReceived(const QByteArray &data);
    void requestFailed(const QString &error);
    void requestTimeout();

private:
    void startRequest(const QString &url);
    void abortCurrent();

    int m_timeoutMs;
    QNetworkReply *m_currentReply = nullptr;
    // 自定义请求头（仅本实例生效，不写入 ApiClient 全局）
    QList<QPair<QByteArray, QByteArray>> m_customHeaders;
};

#endif // HTTPGETREQUESTER_H
