#include "usermanager.h"
#include "ApiClient.h"
#include "PlaylistCacheStore.h"

#include <QDateTime>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

static const QString API_BASE = "https://api.special520.com";

UserManager::UserManager(QObject *parent) : QObject(parent)
{
    loadFromSettings();
    syncTokenToApiClient();
}

bool UserManager::isLoggedIn() const
{
    return !m_token.isEmpty() && !m_userid.isEmpty();
}
QString UserManager::nickname() const
{
    return m_nickname.isEmpty() ? "未登录" : m_nickname;
}
QString UserManager::avatarUrl() const
{
    return m_avatarUrl;
}
QString UserManager::userid() const
{
    return m_userid;
}
QString UserManager::token() const
{
    return m_token;
}
bool UserManager::isVip() const
{
    return m_isVip;
}
bool UserManager::isLoading() const
{
    return m_isLoading;
}

void UserManager::setIsLoading(bool loading)
{
    if (m_isLoading != loading)
    {
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
    if (username.isEmpty() || password.isEmpty())
    {
        emit loginFailed("用户名或密码不能为空");
        return;
    }
    setIsLoading(true);
    postForm(
        "/login", {{"username", username}, {"password", password}},
        [this](QJsonObject root)
        {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1)
            {
                const int errCode = root["error_code"].toInt();
                QString msg       = root["message"].toString();
                if (msg.isEmpty())
                    msg = QString("登录失败 (错误码: %1)").arg(errCode);
                emit loginFailed(msg);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token                = data["token"].toString();
            m_userid               = QString::number(data["userid"].toInt());
            m_nickname             = data["nickname"].toString();
            m_avatarUrl            = data["pic"].toString();
            m_isVip                = data["is_vip"].toInt() == 1;
            m_settings.setValue("lastTokenRefreshMs", QDateTime::currentMSecsSinceEpoch()); // 刚拿到全新 token，同样计入 24h 节流
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit loginSuccess();
        },
        [this](QString err, int)
        {
            setIsLoading(false);
            emit loginFailed(QString("网络错误: %1").arg(err));
        }
    );
}

void UserManager::sendCaptcha(const QString &mobile)
{
    if (mobile.isEmpty())
    {
        emit captchaSent(false, "手机号不能为空");
        return;
    }
    postForm(
        "/captcha/sent", {{"mobile", mobile}},
        [this](QJsonObject root)
        {
            const int status  = root["status"].toInt();
            const int errCode = root["error_code"].toInt();
            if (status == 1 || errCode == 0)
            {
                emit captchaSent(true, "验证码已发送");
            }
            else
            {
                QString msg = root["message"].toString();
                if (msg.isEmpty())
                    msg = QString("发送失败 (错误码: %1)").arg(errCode);
                emit captchaSent(false, msg);
            }
        },
        [this](QString err, int) { emit captchaSent(false, QString("网络错误: %1").arg(err)); }
    );
}

void UserManager::loginByPhone(const QString &mobile, const QString &code)
{
    if (mobile.isEmpty() || code.isEmpty())
    {
        emit loginFailed("手机号或验证码不能为空");
        return;
    }
    setIsLoading(true);
    postForm(
        "/login/cellphone", {{"mobile", mobile}, {"code", code}},
        [this](QJsonObject root)
        {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1)
            {
                const int errCode = root["error_code"].toInt();
                QString msg       = root["message"].toString();
                if (msg.isEmpty())
                    msg = QString("登录失败 (错误码: %1)").arg(errCode);
                emit loginFailed(msg);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token                = data["token"].toString();
            m_userid               = QString::number(data["userid"].toInt());
            m_nickname             = data["nickname"].toString();
            m_avatarUrl            = data["pic"].toString();
            m_isVip                = data["is_vip"].toInt() == 1;
            m_settings.setValue("lastTokenRefreshMs", QDateTime::currentMSecsSinceEpoch()); // 刚拿到全新 token，同样计入 24h 节流
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit loginSuccess();
        },
        [this](QString err, int)
        {
            setIsLoading(false);
            emit loginFailed(QString("网络错误: %1").arg(err));
        }
    );
}

void UserManager::fetchQrKey()
{
    ApiClient::instance().getJson(
        API_BASE + "/login/qr/key",
        [this](QJsonObject root)
        {
            const QJsonObject data = root["data"].toObject();
            const QString key      = data["qrcode"].toString();
            if (key.isEmpty())
            {
                emit qrKeyFailed("二维码生成失败");
                return;
            }
            // qrcode_img 是 data:image/png;base64,xxx，QML Image 可直接作为 source
            emit qrKeyReady(key, data["qrcode_img"].toString());
        },
        [this](QString err, int)
        {
            emit qrKeyFailed(QString("网络错误: %1").arg(err));
        },
        10000
    );
}

void UserManager::checkQrStatus(const QString &key)
{
    if (key.isEmpty())
        return;
    ApiClient::instance().getJson(
        API_BASE + "/login/qr/check?key=" + key,
        [this](QJsonObject root)
        {
            const int status = root["data"].toObject()["status"].toInt();
            if (status != 4)
            {
                emit qrStatusReady(status);
                return;
            }
            // 授权成功：解析登录态（check 响应含 token+userid；昵称/头像可能为空，成功后补拉用户信息）
            const QJsonObject data = root["data"].toObject();
            m_token                = data["token"].toString();
            m_userid               = QString::number(data["userid"].toInt());
            m_nickname             = data["nickname"].toString();
            m_avatarUrl            = data["pic"].toString();
            m_isVip                = data["is_vip"].toInt() == 1;
            m_settings.setValue("lastTokenRefreshMs", QDateTime::currentMSecsSinceEpoch()); // 刚拿到全新 token，同样计入 24h 节流
            saveToSettings();
            syncTokenToApiClient();
            emit qrStatusReady(4);
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit loginSuccess();
            if (m_nickname.isEmpty())
                fetchUserDetail();  // 回填昵称/头像
        },
        [this](QString err, int) { emit qrStatusReady(-1); Q_UNUSED(err); },
        8000
    );
}

void UserManager::refreshToken()
{
    if (m_token.isEmpty() || m_userid.isEmpty())
    {
        emit tokenRefreshResult(false);
        return;
    }
    // 3 天节流：启动时的 token 刷新太频繁容易触发酷狗风控（账号被踢）；
    // 且酷狗「不到期刷新返回同一个 token」，刷新过密没有收益。参照 MoeKoe 客户端
    // （完全不主动刷新）与上游社区结论，取 3 天。上次刷新时间持久化在 QSettings；
    // 未满 3 天直接按成功跳过（登录态原样保留）。
    constexpr qint64 kMinRefreshIntervalMs = 3LL * 24 * 60 * 60 * 1000;
    const qint64 last = m_settings.value("lastTokenRefreshMs").toLongLong();
    const qint64 now  = QDateTime::currentMSecsSinceEpoch();
    if (last > 0 && now - last < kMinRefreshIntervalMs)
    {
        qDebug() << "[UserManager] 距上次 token 刷新不足 3 天，跳过启动刷新";
        emit tokenRefreshResult(true);
        return;
    }
    setIsLoading(true);
    postForm(
        "/login/token", {{"token", m_token}, {"userid", m_userid}},
        [this](QJsonObject root)
        {
            setIsLoading(false);
            const int status = root["status"].toInt();
            if (status != 1)
            {
                clearSettings();
                m_token.clear();
                m_userid.clear();
                syncTokenToApiClient(); // 登录态清除同步到 ApiClient，后续请求不再携带死 token
                emit loginStatusChanged();
                emit tokenRefreshResult(false);
                return;
            }
            const QJsonObject data = root["data"].toObject();
            m_token                = data["token"].toString();
            m_userid               = QString::number(data["userid"].toInt());
            m_nickname             = data["nickname"].toString();
            m_avatarUrl            = data["pic"].toString();
            m_isVip                = data["is_vip"].toInt() == 1;
            m_settings.setValue("lastTokenRefreshMs", QDateTime::currentMSecsSinceEpoch());
            saveToSettings();
            syncTokenToApiClient();
            emit loginStatusChanged();
            emit userInfoUpdated();
            emit tokenRefreshResult(true);
        },
        [this](QString err, int)
        {
            setIsLoading(false);
            // 网络错误 ≠ token 失效：保留登录态，下次启动/操作再试；
            // 只有服务器明确返回 status != 1（token 真过期）才清空登录态
            emit tokenRefreshResult(false);
        }
    );
}

void UserManager::logout()
{
    m_manualLogout = true; // 主动退出：UI 不弹登录窗
    m_token.clear();
    m_userid.clear();
    m_nickname.clear();
    m_avatarUrl.clear();
    m_isVip = false;
    clearSettings();
    syncTokenToApiClient();
    emit loginStatusChanged();
    emit userInfoUpdated();
}

void UserManager::fetchUserDetail()
{
    if (!isLoggedIn())
        return;
    postForm(
        "/user/detail", {{"token", m_token}, {"userid", m_userid}},
        [this](QJsonObject root)
        {
            writeCacheFile("user_detail_cache.json", QJsonDocument(root));
            // VIP 状态实时刷新：isVip 只在登录时写一次，登录后权益变化（过期/共享 VIP 掉）
            // 徽标不会跟着变——详情接口返回的实时状态才是准的
            const QJsonObject data = root.value("data").toObject();
            const bool vip = data.value("is_vip").toInt() == 1 || data.value("vip_type").toInt() > 0;
            if (vip != m_isVip)
            {
                m_isVip = vip;
                saveToSettings();
                emit userInfoUpdated();
            }
            emit userDetailReceived(root.toVariantMap());
        },
        [](QString, int) {}
    );
}

void UserManager::fetchUserPlaylist(int page, int pagesize)
{
    if (!isLoggedIn())
        return;
    qDebug() << "[UserManager] fetchUserPlaylist called, token:" << m_token.left(10) << "userid:" << m_userid;
    postForm(
        "/user/playlist",
        {{"token", m_token},
         {"userid", m_userid},
         {"page", QString::number(page)},
         {"pagesize", QString::number(pagesize)}},
        [this](QJsonObject root)
        {
            writeCacheFile("playlists_cache.json", QJsonDocument(root));
            emit userPlaylistReceived(root.toVariantMap());
        },
        [](QString, int) {}
    );
}

void UserManager::fetchPlaylistDetail(const QString &globalCollectionId, int page, int pagesize)
{
    if (!isLoggedIn())
        return;
    postForm(
        "/playlist/track/all",
        {{"id", globalCollectionId},
         {"token", m_token},
         {"userid", m_userid},
         {"page", QString::number(page)},
         {"pagesize", QString::number(pagesize)}},
        [this, globalCollectionId, page](QJsonObject root)
        {
            // 缓存按「已加载前缀」维护：page 1 重置，后续页按 hash 追加去重，
            // 重启后进页面缓存不缺不重；emit 仍发原始单页，QML 自行追加显示
            QJsonObject cacheRoot = root;
            if (page > 1)
            {
                QJsonObject data          = cacheRoot["data"].toObject();
                const QJsonDocument oldDoc = readCacheFile("playlist_" + globalCollectionId + ".json");
                const QJsonArray oldSongs  = oldDoc.object().value("data").toObject().value("songs").toArray();
                QSet<QString> seen;
                for (const QJsonValue &v : oldSongs)
                {
                    const QString h = v.toObject().value("hash").toString();
                    if (!h.isEmpty())
                        seen.insert(h);
                }
                QJsonArray merged   = oldSongs;
                const QJsonArray songs = data.value("songs").toArray();
                for (const QJsonValue &v : songs)
                {
                    const QString h = v.toObject().value("hash").toString();
                    if (!h.isEmpty() && !seen.contains(h))
                    {
                        seen.insert(h);
                        merged.append(v);
                    }
                }
                data["songs"]     = merged;
                cacheRoot["data"] = data;
            }
            writeCacheFile("playlist_" + globalCollectionId + ".json", QJsonDocument(cacheRoot));
            emit playlistDetailReceived(root.toVariantMap());
        },
        [](QString, int) {}
    );
}

// 听歌等级/累计听歌时长：查询模式（不带 d_sec/diff_sec）。
// 标准版协议（v4）下服务端按真实播放统计维护时长，增量上报不记账，所以只做查询展示
void UserManager::fetchGradeInfo()
{
    if (!isLoggedIn())
        return;
    postForm(
        "/user/grade/info", {{"token", m_token}, {"userid", m_userid}},
        [this](QJsonObject root)
        {
            const QJsonObject data = root.value("data").toObject();
            if (root.value("status").toInt() != 1 || data.isEmpty())
                return;
            emit gradeInfoReceived(data.toVariantMap());
        },
        [](QString, int) {}
    );
}

// ── 缓存相关（转发到 PlaylistCacheStore，统一缓存目录实现）──

QString UserManager::getCacheDir() const
{
    return PlaylistCacheStore::cacheDir();
}

void UserManager::ensureCacheDir() const
{
    PlaylistCacheStore::ensureCacheDir();
}

void UserManager::writeCacheFile(const QString &fileName, const QJsonDocument &doc) const
{
    ensureCacheDir();
    QString path = PlaylistCacheStore::configPath(fileName);
    QFile file(path);
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
    }
}

QJsonDocument UserManager::readCacheFile(const QString &fileName) const
{
    QString path = PlaylistCacheStore::configPath(fileName);
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
    if (doc.isObject())
        return doc.object().toVariantMap();
    return QVariantMap();
}

QVariantMap UserManager::loadCachedPlaylistDetail(const QString &globalCollectionId)
{
    QJsonDocument doc = readCacheFile("playlist_" + globalCollectionId + ".json");
    if (doc.isObject())
        return doc.object().toVariantMap();
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
    if (doc.isObject())
        return doc.object().toVariantMap();
    return QVariantMap();
}

void UserManager::postForm(
    const QString &path, const QList<QPair<QString, QString>> &params, std::function<void(QJsonObject)> onSuccess,
    std::function<void(QString, int)> onError, int timeoutMs
)
{
    // 旧接口语义：URL query + JSON body（与原 sendPostRequest 一致）
    QUrlQuery query;
    for (const auto &p : params)
    {
        query.addQueryItem(p.first, p.second);
    }
    const QJsonObject body; // 原实现是空 body（POST 表单无 JSON body）
    const QString url = API_BASE + path + "?" + query.toString();

    // 统一拦截：任何用户接口返回 20018（token 被踢/失效）都清登录态并通知 UI，
    // 否则 24h 刷新盲区里 token 被踢后界面仍显示已登录、操作全失败却无人引导重登
    auto guarded = [this, onSuccess = std::move(onSuccess)](QJsonObject root) mutable
    {
        if (root.value("status").toInt() != 1 && root.value("error_code").toInt() == 20018 && !m_token.isEmpty())
        {
            qWarning() << "[UserManager] 登录态已被服务端吊销（20018），清除本地登录";
            m_token.clear();
            m_userid.clear();
            clearSettings();
            syncTokenToApiClient();
            m_manualLogout = false; // 被踢不是主动退出，UI 可弹登录窗引导
            emit loginStatusChanged();
        }
        onSuccess(root);
    };
    ApiClient::instance().postJson(url, body, std::move(guarded), std::move(onError), timeoutMs);
}

void UserManager::saveToSettings()
{
    m_settings.setValue("token", m_token);
    m_settings.setValue("userid", m_userid);
    m_settings.setValue("nickname", m_nickname);
    m_settings.setValue("avatarUrl", m_avatarUrl);
    m_settings.setValue("isVip", m_isVip);
}

void UserManager::loadFromSettings()
{
    m_token     = m_settings.value("token").toString();
    m_userid    = m_settings.value("userid").toString();
    m_nickname  = m_settings.value("nickname").toString();
    m_avatarUrl = m_settings.value("avatarUrl").toString();
    m_isVip     = m_settings.value("isVip").toBool();
}

void UserManager::clearSettings()
{
    m_settings.remove("token");
    m_settings.remove("userid");
    m_settings.remove("nickname");
    m_settings.remove("avatarUrl");
    m_settings.remove("isVip");
}
