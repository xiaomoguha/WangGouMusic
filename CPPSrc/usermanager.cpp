#include "usermanager.h"
#include "ApiClient.h"

#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

static const QString API_BASE = "https://xjt-togethertracks.top/api";

UserManager::UserManager(QObject *parent)
    : QObject(parent)
{
    loadFromSettings();
    syncTokenToApiClient();
}

bool UserManager::isLoggedIn() const { return !m_token.isEmpty() && !m_userid.isEmpty(); }
QString UserManager::nickname() const { return m_nickname.isEmpty() ? "未登录" : m_nickname; }
QString UserManager::avatarUrl() const { return m_avatarUrl; }
QString UserManager::userid() const { return m_userid; }
QString UserManager::token() const { return m_token; }
bool UserManager::isVip() const { return m_isVip; }
bool UserManager::isLoading() const { return m_isLoading; }

void UserManager::setIsLoading(bool loading)
{
    if (m_isLoading != loading) {
        m_isLoading = loading;
        emit isLoadingChanged();
    }
}

void UserManager::syncTokenToApiClient() const
{
    ApiClient::instance().setAuthToken(m_token);
}

void UserManager::login(const QString &username, const QString &password)
{
    if (username.isEmpty() || password.isEmpty()) {
        emit loginFailed("用户名或密码不能为空");
        return;
    }
    setIsLoading(true);
    postForm("/login", {{"username", username}, {"password", password}},
        [this](QJsonObject root) {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1) {
                const int errCode = root["error_code"].toInt();
                QString msg = root["message"].toString();
                if (msg.isEmpty()) msg = QString("登录失败 (错误码: %1)").arg(errCode);
                emit loginFailed(msg);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token      = data["token"].toString();
            m_userid     = QString::number(data["userid"].toInt());
            m_nickname   = data["nickname"].toString();
            m_avatarUrl  = data["pic"].toString();
            m_isVip      = data["is_vip"].toInt() == 1;
            m_vipType    = data["vip_type"].toInt();
            m_vipToken   = data["vip_token"].toString();
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit loginSuccess();
        },
        [this](QString err, int) {
            setIsLoading(false);
            emit loginFailed(QString("网络错误: %1").arg(err));
        });
}

void UserManager::sendCaptcha(const QString &mobile)
{
    if (mobile.isEmpty()) {
        emit captchaSent(false, "手机号不能为空");
        return;
    }
    postForm("/captcha/sent", {{"mobile", mobile}},
        [this](QJsonObject root) {
            const int status = root["status"].toInt();
            const int errCode = root["error_code"].toInt();
            if (status == 1 || errCode == 0) {
                emit captchaSent(true, "验证码已发送");
            } else {
                QString msg = root["message"].toString();
                if (msg.isEmpty()) msg = QString("发送失败 (错误码: %1)").arg(errCode);
                emit captchaSent(false, msg);
            }
        },
        [this](QString err, int) {
            emit captchaSent(false, QString("网络错误: %1").arg(err));
        });
}

void UserManager::loginByPhone(const QString &mobile, const QString &code)
{
    if (mobile.isEmpty() || code.isEmpty()) {
        emit loginFailed("手机号或验证码不能为空");
        return;
    }
    setIsLoading(true);
    postForm("/login/cellphone", {{"mobile", mobile}, {"code", code}},
        [this](QJsonObject root) {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1) {
                const int errCode = root["error_code"].toInt();
                QString msg = root["message"].toString();
                if (msg.isEmpty()) msg = QString("登录失败 (错误码: %1)").arg(errCode);
                emit loginFailed(msg);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token      = data["token"].toString();
            m_userid     = QString::number(data["userid"].toInt());
            m_nickname   = data["nickname"].toString();
            m_avatarUrl  = data["pic"].toString();
            m_isVip      = data["is_vip"].toInt() == 1;
            m_vipType    = data["vip_type"].toInt();
            m_vipToken   = data["vip_token"].toString();
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit loginSuccess();
        },
        [this](QString err, int) {
            setIsLoading(false);
            emit loginFailed(QString("网络错误: %1").arg(err));
        });
}

void UserManager::refreshToken()
{
    if (m_token.isEmpty() || m_userid.isEmpty()) {
        emit tokenRefreshResult(false);
        return;
    }
    setIsLoading(true);
    postForm("/login/token", {{"token", m_token}, {"userid", m_userid}},
        [this](QJsonObject root) {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1) {
                clearSettings();
                m_token.clear();
                m_userid.clear();
                emit loginStatusChanged();
                emit tokenRefreshResult(false);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token      = data["token"].toString();
            m_userid     = QString::number(data["userid"].toInt());
            m_nickname   = data["nickname"].toString();
            m_avatarUrl  = data["pic"].toString();
            m_isVip      = data["is_vip"].toInt() == 1;
            m_vipType    = data["vip_type"].toInt();
            m_vipToken   = data["vip_token"].toString();
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit tokenRefreshResult(true);
        },
        [this](QString err, int) {
            setIsLoading(false);
            clearSettings();
            m_token.clear();
            m_userid.clear();
            emit loginStatusChanged();
            emit tokenRefreshResult(false);
        });
}

void UserManager::logout()
{
    m_token.clear();
    m_userid.clear();
    m_nickname.clear();
    m_avatarUrl.clear();
    m_isVip = false;
    m_vipType = 0;
    m_vipToken.clear();
    clearSettings();
    syncTokenToApiClient();
    emit loginStatusChanged();
    emit userInfoUpdated();
}

void UserManager::fetchUserDetail()
{
    if (!isLoggedIn()) return;
    postForm("/user/detail", {{"token", m_token}, {"userid", m_userid}},
        [this](QJsonObject root) {
            writeCacheFile("user_detail_cache.json", QJsonDocument(root));
            emit userDetailReceived(root.toVariantMap());
        },
        [](QString, int) {});
}

void UserManager::fetchUserPlaylist(int page, int pagesize)
{
    if (!isLoggedIn()) return;
    qDebug() << "[UserManager] fetchUserPlaylist called, token:" << m_token.left(10) << "userid:" << m_userid;
    postForm("/user/playlist",
        {{"token", m_token}, {"userid", m_userid},
         {"page", QString::number(page)}, {"pagesize", QString::number(pagesize)}},
        [this](QJsonObject root) {
            writeCacheFile("playlists_cache.json", QJsonDocument(root));
            emit userPlaylistReceived(root.toVariantMap());
        },
        [](QString, int) {});
}

void UserManager::fetchPlaylistDetail(const QString &globalCollectionId, int page, int pagesize)
{
    if (!isLoggedIn()) return;
    postForm("/playlist/track/all",
        {{"id", globalCollectionId}, {"token", m_token}, {"userid", m_userid},
         {"page", QString::number(page)}, {"pagesize", QString::number(pagesize)}},
        [this, globalCollectionId](QJsonObject root) {
            writeCacheFile("playlist_" + globalCollectionId + ".json", QJsonDocument(root));
            emit playlistDetailReceived(root.toVariantMap());
        },
        [](QString, int) {});
}

// ── 缓存相关 ──

QString UserManager::getCacheDir() const
{
#ifdef Q_OS_WIN
    return "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/网狗音乐缓存目录";
#else
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/网狗音乐缓存目录";
#endif
}

void UserManager::ensureCacheDir() const
{
    QDir dir(getCacheDir());
    if (!dir.exists()) dir.mkpath(".");
}

void UserManager::writeCacheFile(const QString &fileName, const QJsonDocument &doc) const
{
    ensureCacheDir();
    QString path = getCacheDir() + "/" + fileName;
    QFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
    }
}

QJsonDocument UserManager::readCacheFile(const QString &fileName) const
{
    QString path = getCacheDir() + "/" + fileName;
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return QJsonDocument();
    QByteArray data = file.readAll();
    file.close();
    return QJsonDocument::fromJson(data);
}

QVariantMap UserManager::loadCachedPlaylists()
{
    QJsonDocument doc = readCacheFile("playlists_cache.json");
    if (doc.isObject()) return doc.object().toVariantMap();
    return QVariantMap();
}

QVariantMap UserManager::loadCachedPlaylistDetail(const QString &globalCollectionId)
{
    QJsonDocument doc = readCacheFile("playlist_" + globalCollectionId + ".json");
    if (doc.isObject()) return doc.object().toVariantMap();
    return QVariantMap();
}

void UserManager::cacheUserDetail(const QVariantMap &data)
{
    QJsonObject obj = QJsonObject::fromVariantMap(data);
    writeCacheFile("user_detail_cache.json", QJsonDocument(obj));
}

QVariantMap UserManager::loadCachedUserDetail()
{
    QJsonDocument doc = readCacheFile("user_detail_cache.json");
    if (doc.isObject()) return doc.object().toVariantMap();
    return QVariantMap();
}

void UserManager::postForm(const QString &path,
                           const QList<QPair<QString, QString>> &params,
                           std::function<void(QJsonObject)> onSuccess,
                           std::function<void(QString, int)> onError,
                           int timeoutMs)
{
    // 旧接口语义：URL query + JSON body（与原 sendPostRequest 一致）
    QUrlQuery query;
    for (const auto& p : params) {
        query.addQueryItem(p.first, p.second);
    }
    const QJsonObject body;  // 原实现是空 body（POST 表单无 JSON body）
    const QString url = API_BASE + path + "?" + query.toString();

    ApiClient::instance().postJson(url, body, std::move(onSuccess), std::move(onError), timeoutMs);
}

void UserManager::saveToSettings()
{
    m_settings.setValue("token", m_token);
    m_settings.setValue("userid", m_userid);
    m_settings.setValue("nickname", m_nickname);
    m_settings.setValue("avatarUrl", m_avatarUrl);
    m_settings.setValue("isVip", m_isVip);
    m_settings.setValue("vipType", m_vipType);
    m_settings.setValue("vipToken", m_vipToken);
}

void UserManager::loadFromSettings()
{
    m_token     = m_settings.value("token").toString();
    m_userid    = m_settings.value("userid").toString();
    m_nickname  = m_settings.value("nickname").toString();
    m_avatarUrl = m_settings.value("avatarUrl").toString();
    m_isVip     = m_settings.value("isVip").toBool();
    m_vipType   = m_settings.value("vipType").toInt();
    m_vipToken  = m_settings.value("vipToken").toString();
}

void UserManager::clearSettings()
{
    m_settings.remove("token");
    m_settings.remove("userid");
    m_settings.remove("nickname");
    m_settings.remove("avatarUrl");
    m_settings.remove("isVip");
    m_settings.remove("vipType");
    m_settings.remove("vipToken");
}
