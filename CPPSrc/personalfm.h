#ifndef PERSONALFM_H
#define PERSONALFM_H

#include "HttpGetRequester.h"
#include <QJsonArray>
#include <QObject>
#include <QVariantList>

class UserManager;

// 个人 FM（/api/personal/fm）：每次 5 首推荐。
// 首页用 songs 展示推荐卡片；独立 FM 页用 queue 累积连续播放队列。
class PersonalFM : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(QVariantList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(bool queueMode READ queueMode NOTIFY queueModeChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    // 0=发现 normal / 1=小众 small / 2=30秒 peak / 3=电台 radio
    Q_PROPERTY(int mode READ mode NOTIFY modeChanged)
    // 0=口味 Alpha / 1=风格 Beta / 2=探索 Gamma
    Q_PROPERTY(int pool READ pool NOTIFY poolChanged)

public:
    explicit PersonalFM(QObject *parent = nullptr);

    // 绑定登录态来源（main.cpp 里 userManager 构造后调用）
    void setUserManager(UserManager *um);

    // 拉取首批（首页推荐卡片）
    Q_INVOKABLE void fetch();
    // 基于上一批最后一首 hash 切下一批（首页卡片换一批）
    Q_INVOKABLE void fetchNext();

    // 独立 FM 页：进入连续播放模式。优先用已有卡片做首批，没有时再请求。
    Q_INVOKABLE void startQueue();
    // 退出连续模式（保留当前队列，停止自动追加）
    Q_INVOKABLE void stopQueue();
    // 队列快播完时预取下一批并追加（自动去重）
    Q_INVOKABLE void requestMore();
    // 清空队列并重新取两批（一起听模式手动刷新推荐，不影响本地 FM 播放）
    Q_INVOKABLE void refreshQueue();

    // 切换推荐模式 / 推荐源：立即重新拉一批
    Q_INVOKABLE void setMode(int mode);
    Q_INVOKABLE void setPool(int pool);
    // 推荐反馈：喜欢 / 不感兴趣 / 屏蔽歌手（hash 用于定位当前歌曲）
    Q_INVOKABLE void like(const QString &hash);
    Q_INVOKABLE void dislike(const QString &hash);
    Q_INVOKABLE void banSinger(const QString &hash);

    QVariantList songs() const { return m_songs; }
    QVariantList queue() const { return m_queue; }
    bool queueMode() const { return m_queueMode; }
    bool isLoading() const { return m_isLoading; }
    int mode() const { return m_mode; }
    int pool() const { return m_pool; }
    // 当前批最后一首的 hash（自动续播时传给 fetchNext）
    QString lastHash() const;

signals:
    void songsChanged();
    void queueChanged();
    void queueModeChanged();
    void songsAppended(const QVariantList &songs);
    void isLoadingChanged();
    void modeChanged();
    void poolChanged();
    void notice(const QString &message);
    void errorOccurred(const QString &message);

private slots:
    void onData(const QByteArray &data);
    void onCoverData(const QByteArray &data);
    void onFeedbackData(const QByteArray &data);

private:
    void onFailed();
    void onFeedbackFailed(const QString &err);
    void onCoverFailed(const QString &err);
    void request(const QString &hash, const QString &action, bool append);
    void requestFeedback(const QString &hash, const QString &action);
    QString modeString() const;

    QVariantList parseSongs(const QJsonArray &list) const;
    int appendToQueue(const QVariantList &songs);
    void updateCoverForHashes(const QStringList &hashes, const QString &cover);
    // FM 接口无封面：按 album_id 查专辑图回填（同专辑只请求一次，串行队列）
    void requestNextCover();
    void beginCoverFetch(const QVariantList &songs);

    UserManager *m_userManager = nullptr;
    HttpGetRequester m_requester;
    HttpGetRequester m_feedbackRequester;
    HttpGetRequester m_coverRequester;
    QVariantList m_songs;
    QVariantList m_queue;
    // 封面补全任务元素：{albumId, hashes}
    QVariantList m_coverQueue;
    int m_coverCursor = 0;
    bool m_coverFetching = false;
    bool m_queueMode = false;
    bool m_appendBatch = false;
    bool m_reloadAfterLoad = false;
    bool m_isLoading = false;
    int m_fillAttempts = 0;
    int m_mode = 0;
    int m_pool = 0;
    QString m_curMark;
    QString m_feedbackAction;
};

#endif // PERSONALFM_H
