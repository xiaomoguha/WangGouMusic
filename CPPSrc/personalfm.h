#ifndef PERSONALFM_H
#define PERSONALFM_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

class UserManager;

/**
 * @brief 个人 FM（/api/personal/fm）：每批 5 首推荐，传 hash 切下一批。
 *
 * 已登录时传 token/userid 返回个性化推荐（未登录返回通用推荐）。
 */
class PersonalFM : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)

public:
    explicit PersonalFM(QObject *parent = nullptr);

    // 绑定登录态来源（main.cpp 里 userManager 构造后调用）
    void setUserManager(UserManager *um);

    /// 拉取首批（无 hash）
    Q_INVOKABLE void fetch();
    /// 基于上一批最后一首 hash 切下一批（旧批替换为新批）
    Q_INVOKABLE void fetchNext();

    QVariantList songs() const { return m_songs; }
    bool isLoading() const { return m_isLoading; }
    // 当前批最后一首的 hash（自动续播时传给 fetchNext）
    QString lastHash() const;

signals:
    void songsChanged();
    void isLoadingChanged();

private slots:
    void onData(const QByteArray &data);
    void onCoverData(const QByteArray &data);

private:
    void onFailed();
    void onCoverFailed(const QString &err);
    void request(const QString &hash);
    // FM 接口无封面：按 album_id 查专辑图回填（同专辑只请求一次，串行队列）
    void requestNextCover();

    UserManager *m_userManager = nullptr;
    HttpGetRequester m_requester;
    HttpGetRequester m_coverRequester;
    QVariantList m_songs;
    // 封面队列元素：{albumId, indexes}
    QVariantList m_coverQueue;
    int m_coverCursor = 0;
    bool m_isLoading = false;
};

#endif // PERSONALFM_H
