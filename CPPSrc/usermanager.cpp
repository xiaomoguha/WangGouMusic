#include "usermanager.h"
#include <QUrlQuery>
#include <QDir>
#include <QStandardPaths>

static const QString API_BASE = "https://xjt-togethertracks.top/api";

UserManager::UserManager(QObject *parent)
    : QObject(parent)
{
    loadFromSettings();
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

void UserManager::login(const QString &username, const QString &password)
{
    if (username.isEmpty() || password.isEmpty()) {
        emit loginFailed("用户名或密码不能为空");
        return;
    }
    setIsLoading(true);
    sendPostRequest("/login", {{"username", username}, {"password", password}},
                    [this](QNetworkReply *reply) { handleLoginReply(reply); });
}

void UserManager::sendCaptcha(const QString &mobile)
{
    if (mobile.isEmpty()) {
        emit captchaSent(false, "手机号不能为空");
        return;
    }
    sendPostRequest("/captcha/sent", {{"mobile", mobile}},
                    [this](QNetworkReply *reply) { handleCaptchaReply(reply); });
}

void UserManager::loginByPhone(const QString &mobile, const QString &code)
{
    if (mobile.isEmpty() || code.isEmpty()) {
        emit loginFailed("手机号或验证码不能为空");
        return;
    }
    setIsLoading(true);
    sendPostRequest("/login/cellphone", {{"mobile", mobile}, {"code", code}},
                    [this](QNetworkReply *reply) { handlePhoneLoginReply(reply); });
}

void UserManager::refreshToken()
{
    if (m_token.isEmpty() || m_userid.isEmpty()) {
        emit tokenRefreshResult(false);
        return;
    }
    setIsLoading(true);
    sendPostRequest("/login/token", {{"token", m_token}, {"userid", m_userid}},
                    [this](QNetworkReply *reply) { handleRefreshReply(reply); });
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
    emit loginStatusChanged();
    emit userInfoUpdated();
}

void UserManager::fetchUserDetail()
{
    if (!isLoggedIn()) return;
    sendPostRequest("/user/detail", {{"token", m_token}, {"userid", m_userid}},
                    [this](QNetworkReply *reply) { handleUserDetailReply(reply); });
}

void UserManager::fetchUserPlaylist(int page, int pagesize)
{
    if (!isLoggedIn()) return;
    qDebug() << "[UserManager] fetchUserPlaylist called, token:" << m_token.left(10) << "userid:" << m_userid;
    sendPostRequest("/user/playlist",
                    {{"token", m_token}, {"userid", m_userid},
                     {"page", QString::number(page)}, {"pagesize", QString::number(pagesize)}},
                    [this](QNetworkReply *reply) { handleUserPlaylistReply(reply); });
}

void UserManager::fetchPlaylistDetail(const QString &globalCollectionId, int page, int pagesize)
{
    if (!isLoggedIn()) return;
    sendPostRequest("/playlist/track/all",
                    {{"id", globalCollectionId}, {"token", m_token}, {"userid", m_userid},
                     {"page", QString::number(page)}, {"pagesize", QString::number(pagesize)}},
                    [this](QNetworkReply *reply) { handlePlaylistDetailReply(reply); });
}

void UserManager::handleLoginReply(QNetworkReply *reply)
{
    setIsLoading(false);
    if (reply->error() != QNetworkReply::NoError) {
        emit loginFailed("网络错误: " + reply->errorString());
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (!doc.isObject()) {
        emit loginFailed("服务器返回数据格式错误");
        return;
    }
    QJsonObject root = doc.object();
    if (root["status"].toInt() != 1) {
        int errorCode = root["error_code"].toInt();
        QString msg = root["message"].toString();
        if (msg.isEmpty()) msg = QString("登录失败 (错误码: %1)").arg(errorCode);
        emit loginFailed(msg);
        return;
    }
    QJsonObject data = root["data"].toObject();
    m_token = data["token"].toString();
    m_userid = QString::number(data["userid"].toInt());
    m_nickname = data["nickname"].toString();
    m_avatarUrl = data["pic"].toString();
    m_isVip = data["is_vip"].toInt() == 1;
    m_vipType = data["vip_type"].toInt();
    m_vipToken = data["vip_token"].toString();
    saveToSettings();
    emit loginStatusChanged();
    emit userInfoUpdated();
    emit loginSuccess();
}

void UserManager::handleCaptchaReply(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        emit captchaSent(false, "网络错误: " + reply->errorString());
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (!doc.isObject()) {
        emit captchaSent(false, "服务器返回数据格式错误");
        return;
    }
    QJsonObject root = doc.object();
    if (root["status"].toInt() == 1 || root["error_code"].toInt() == 0) {
        emit captchaSent(true, "验证码已发送");
    } else {
        QString msg = root["message"].toString();
        if (msg.isEmpty()) msg = QString("发送失败 (错误码: %1)").arg(root["error_code"].toInt());
        emit captchaSent(false, msg);
    }
}

void UserManager::handlePhoneLoginReply(QNetworkReply *reply)
{
    setIsLoading(false);
    if (reply->error() != QNetworkReply::NoError) {
        emit loginFailed("网络错误: " + reply->errorString());
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (!doc.isObject()) {
        emit loginFailed("服务器返回数据格式错误");
        return;
    }
    QJsonObject root = doc.object();
    if (root["status"].toInt() != 1) {
        int errorCode = root["error_code"].toInt();
        QString msg = root["message"].toString();
        if (msg.isEmpty()) msg = QString("登录失败 (错误码: %1)").arg(errorCode);
        emit loginFailed(msg);
        return;
    }
    QJsonObject data = root["data"].toObject();
    m_token = data["token"].toString();
    m_userid = QString::number(data["userid"].toInt());
    m_nickname = data["nickname"].toString();
    m_avatarUrl = data["pic"].toString();
    m_isVip = data["is_vip"].toInt() == 1;
    m_vipType = data["vip_type"].toInt();
    m_vipToken = data["vip_token"].toString();
    saveToSettings();
    emit loginStatusChanged();
    emit userInfoUpdated();
    emit loginSuccess();
}

void UserManager::handleRefreshReply(QNetworkReply *reply)
{
    setIsLoading(false);
    if (reply->error() != QNetworkReply::NoError) {
        clearSettings();
        m_token.clear();
        m_userid.clear();
        emit loginStatusChanged();
        emit tokenRefreshResult(false);
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (!doc.isObject()) {
        emit tokenRefreshResult(false);
        return;
    }
    QJsonObject root = doc.object();
    if (root["status"].toInt() != 1) {
        clearSettings();
        m_token.clear();
        m_userid.clear();
        emit loginStatusChanged();
        emit tokenRefreshResult(false);
        return;
    }
    QJsonObject data = root["data"].toObject();
    m_token = data["token"].toString();
    m_userid = QString::number(data["userid"].toInt());
    m_nickname = data["nickname"].toString();
    m_avatarUrl = data["pic"].toString();
    m_isVip = data["is_vip"].toInt() == 1;
    m_vipType = data["vip_type"].toInt();
    m_vipToken = data["vip_token"].toString();
    saveToSettings();
    emit loginStatusChanged();
    emit userInfoUpdated();
    emit tokenRefreshResult(true);
}

void UserManager::handleUserDetailReply(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (doc.isObject()) {
        writeCacheFile("user_detail_cache.json", doc);
        emit userDetailReceived(doc.object().toVariantMap());
    }
}

void UserManager::handleUserPlaylistReply(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return;
    }
    QByteArray response = reply->readAll();
    reply->deleteLater();
    QJsonDocument doc = QJsonDocument::fromJson(response);
    if (doc.isObject()) {
        writeCacheFile("playlists_cache.json", doc);
        emit userPlaylistReceived(doc.object().toVariantMap());
    }
}

void UserManager::handlePlaylistDetailReply(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        return;
    }
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    reply->deleteLater();
    if (doc.isObject()) {
        // 用当前请求的 ID 作为文件名（从 reply URL 中提取 id 参数）
        QUrl url = reply->url();
        QString gid = QUrlQuery(url).queryItemValue("id");
        if (!gid.isEmpty()) {
            writeCacheFile("playlist_" + gid + ".json", doc);
        }
        emit playlistDetailReceived(doc.object().toVariantMap());
    }
}

// ── 缓存相关 ──

QString UserManager::getCacheDir() const
{
#ifdef Q_OS_WIN
    return "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
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

void UserManager::sendPostRequest(const QString &path, const QList<QPair<QString, QString>> &params,
                                   std::function<void(QNetworkReply *)> callback)
{
    QUrl url(API_BASE + path);
    QUrlQuery query;
    for (const auto &p : params) {
        query.addQueryItem(p.first, p.second);
    }
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "MyApp/1.0");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");

    QNetworkReply *reply = m_networkManager.post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [reply, cb = std::move(callback)]() {
        cb(reply);
    });
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
    m_token = m_settings.value("token").toString();
    m_userid = m_settings.value("userid").toString();
    m_nickname = m_settings.value("nickname").toString();
    m_avatarUrl = m_settings.value("avatarUrl").toString();
    m_isVip = m_settings.value("isVip").toBool();
    m_vipType = m_settings.value("vipType").toInt();
    m_vipToken = m_settings.value("vipToken").toString();
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
