#ifndef HISTORYMANAGER_H
#define HISTORYMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QTimer>
#include <QVariantList>

/**
 * @brief 听歌历史同步（/api/user/history 拉取 + /api/user/history/upload 上报）。
 *
 * 播放歌曲时入队（title+hash），延迟批量处理：逐首搜索解析 mxid（album_audio_id），
 * 攒够一批后批量上传到酷狗（官方 app 可见听歌历史）。历史列表分页拉取供展示页用。
 */
class HistoryManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY historyChanged)
    Q_PROPERTY(bool uploadWorking READ uploadWorking NOTIFY uploadWorkingChanged)

public:
    explicit HistoryManager(QObject *parent = nullptr);

    QVariantList history() const { return m_history; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }
    bool uploadWorking() const { return m_uploadWorking; }

    /// 播放歌曲时上报（入队，延迟批量处理；未登录忽略）
    Q_INVOKABLE void reportPlayed(const QString &title, const QString &hash);
    /// 拉取云端听歌历史（分页，首页重置）
    Q_INVOKABLE void fetchHistory();
    Q_INVOKABLE void fetchMoreHistory();

signals:
    void historyChanged();
    void isLoadingChanged();
    void uploadWorkingChanged();

private slots:
    void flushQueue();
    void onSearchData(const QByteArray &data);
    void onHistoryData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    void processQueue();
    void doUpload(const QVariantList &songs);

    HttpGetRequester m_searchRequester;   // 解析 mxid（同一时刻只搜一首）
    HttpGetRequester m_uploadRequester;
    HttpGetRequester m_historyRequester;

    QTimer m_flushTimer;
    QVariantList m_pending;        // 待解析上报的 {title, hash}
    QString m_searchHash;          // 正在解析的歌曲 hash
    QVariantList m_uploadBatch;    // 已解析出 mxid 的歌曲，攒批上传
    bool m_uploadWorking = false;
    bool m_uploadDone = false;     // 本次播放会话是否已上传（避免反复上报）

    QVariantList m_history;
    int m_page = 0;
    bool m_hasMore = false;
    bool m_isLoading = false;
};

#endif // HISTORYMANAGER_H
