#ifndef DAILYRECOMMEND_H
#define DAILYRECOMMEND_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

class UserManager;

/**
 * @brief 每日推荐（/api/everyday/recommend）：每天 30 首推荐歌曲 + 整体封面。
 *
 * 登录态注入 userid/token 后，酷狗上游按账号个性化推荐（实测有无账号列表完全不同）。
 */
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

    UserManager *m_userManager = nullptr;
    HttpGetRequester m_requester;
    QVariantList m_songs;
    QString m_date;
    QString m_coverUrl;
    bool m_isLoading = false;
};

#endif // DAILYRECOMMEND_H
