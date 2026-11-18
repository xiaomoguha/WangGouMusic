#ifndef DAILYRECOMMEND_H
#define DAILYRECOMMEND_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QTimer>
#include <QVariantList>

class UserManager;

// 每日推荐（/api/everyday/recommend）：每天 30 首推荐歌曲 + 整体封面。
class DailyRecommend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    // 推荐日期（如 20260805）与整体封面（含 {size} 占位）
    Q_PROPERTY(QString date READ date NOTIFY songsChanged)
    Q_PROPERTY(QString coverUrl READ coverUrl NOTIFY songsChanged)

public:
    explicit DailyRecommend(QObject *parent = nullptr);

    // 绑定登录态来源（main.cpp 里 userManager 构造后调用）
    void setUserManager(UserManager *um);

    Q_INVOKABLE void fetch();

    // 手上这份还是"今天"的就什么都不做，已经跨天（或还没拉过）才重新请求。
    Q_INVOKABLE void refreshIfStale();

    QVariantList songs() const { return m_songs; }
    bool isLoading() const { return m_isLoading; }
    QString date() const { return m_date; }
    QString coverUrl() const { return m_coverUrl; }

signals:
    void songsChanged();
    void isLoadingChanged();

private slots:
    void onData(const QByteArray &data);

private:
    void onFailed();
    // 排下一次自动检查：已经是今天的 → 定到次日本地 0 点过后几秒；
    void scheduleNextRefresh();

    UserManager *m_userManager = nullptr;
    HttpGetRequester m_requester;
    QVariantList m_songs;
    QString m_date;
    QString m_coverUrl;
    bool m_isLoading = false;
    // 跨天自动刷新（单次触发，每次拿到数据/失败后重排）
    QTimer m_refreshTimer;
};

#endif // DAILYRECOMMEND_H
