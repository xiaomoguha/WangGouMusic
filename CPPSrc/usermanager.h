#ifndef USERMANAGER_H
#define USERMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QString>
#include <QSettings>
#include <QVariantMap>
#include <functional>

/**
 * @brief 用户登录 / Token 管理 / 歌单获取
 *
 * 内部已迁移到 ApiClient 单例。Q_INVOKABLE 与信号保持不变。
 */
class UserManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStatusChanged)
    Q_PROPERTY(QString nickname READ nickname NOTIFY userInfoUpdated)
    Q_PROPERTY(QString avatarUrl READ avatarUrl NOTIFY userInfoUpdated)
    Q_PROPERTY(QString userid READ userid NOTIFY userInfoUpdated)
    Q_PROPERTY(bool isVip READ isVip NOTIFY userInfoUpdated)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)

public:
    explicit UserManager(QObject *parent = nullptr);

    bool isLoggedIn() const;
    QString nickname() const;
    QString avatarUrl() const;
    QString userid() const;
    QString token() const;
    bool isVip() const;
    bool isLoading() const;

    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void sendCaptcha(const QString &mobile);
    Q_INVOKABLE void loginByPhone(const QString &mobile, const QString &code);
    Q_INVOKABLE void refreshToken();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void fetchUserDetail();
    Q_INVOKABLE void fetchUserPlaylist(int page = 1, int pagesize = 30);
    Q_INVOKABLE void fetchPlaylistDetail(const QString &globalCollectionId, int page = 1, int pagesize = 30);

    // 缓存
    Q_INVOKABLE QVariantMap loadCachedPlaylists();
    Q_INVOKABLE QVariantMap loadCachedPlaylistDetail(const QString &globalCollectionId);
    Q_INVOKABLE void cacheUserDetail(const QVariantMap &data);
    Q_INVOKABLE QVariantMap loadCachedUserDetail();

signals:
    void loginStatusChanged();
    void userInfoUpdated();
    void isLoadingChanged();
    void loginSuccess();
    void loginFailed(const QString &error);
    void captchaSent(bool success, const QString &msg);
    void tokenRefreshResult(bool success);
    void userDetailReceived(const QVariantMap &data);
    void userPlaylistReceived(const QVariantMap &data);
    void playlistDetailReceived(const QVariantMap &data);

private:
    void setIsLoading(bool loading);
    void saveToSettings();
    void loadFromSettings();
    void clearSettings();
    void syncTokenToApiClient() const;

    QString getCacheDir() const;
    void ensureCacheDir() const;
    void writeCacheFile(const QString &fileName, const QJsonDocument &doc) const;
    QJsonDocument readCacheFile(const QString &fileName) const;

    /// 内部：POST 一组 form 参数，响应作为 QJsonObject 回调
    void postForm(const QString &path,
                  const QList<QPair<QString, QString>> &params,
                  std::function<void(QJsonObject)> onSuccess,
                  std::function<void(QString, int)> onError,
                  int timeoutMs = 10000);

    QSettings m_settings{"WangGouMusic", "UserConfig"};

    QString m_token;
    QString m_userid;
    QString m_nickname;
    QString m_avatarUrl;
    bool m_isVip = false;
    bool m_isLoading = false;
    int m_vipType = 0;
    QString m_vipToken;
};

#endif // USERMANAGER_H
