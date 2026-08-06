#ifndef MVMANAGER_H
#define MVMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>

/**
 * @brief MV 播放地址获取。
 *
 * GET /video/url?hash=mvhash → data[hash].downurl（mp4，带有效期）。
 * ponytail: 跳过 /video/privilege 预检与 /video/detail 详情，播放器自会 403，需要时再加。
 */
class MvManager : public QObject
{
    Q_OBJECT

public:
    explicit MvManager(QObject *parent = nullptr);

    Q_INVOKABLE void fetchVideoUrl(const QString &hash);

signals:
    void videoUrlReceived(QString hash, QString url);
    void videoUrlFailed(QString hash);  // 请求失败/无 MV 资源（数据源的 mvhash 偶发无效）

private slots:
    void onVideoUrlData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    QString m_lastHash;  // 当前请求的 mvhash（失败时带回）
    HttpGetRequester m_requester;
};

#endif // MVMANAGER_H
