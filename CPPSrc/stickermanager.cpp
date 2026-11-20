#include "stickermanager.h"

#include "PlaylistCacheStore.h"
#include "usermanager.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace
{
const QString kBase = QStringLiteral("https://music.special520.com");
const int kMaxStickerBytes = 2 * 1024 * 1024;

QString extFromMagic(const QByteArray &data)
{
    if (data.startsWith("GIF87a") || data.startsWith("GIF89a"))
        return QStringLiteral("gif");
    if (data.startsWith("\x89PNG\r\n\x1a\n"))
        return QStringLiteral("png");
    if (data.startsWith("\xff\xd8\xff"))
        return QStringLiteral("jpg");
    if (data.size() > 12 && data.startsWith("RIFF") && data.mid(8, 4) == "WEBP")
        return QStringLiteral("webp");
    return QString();
}
} // namespace

StickerManager::StickerManager(UserManager *userManager, QObject *parent)
    : QObject(parent), m_userManager(userManager)
{
    // 最近使用：本地单文件，切换账号也保留
    QFile f(PlaylistCacheStore::cacheDir() + QStringLiteral("/config/sticker_recent.json"));
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).array();
        for (const QJsonValue &v : arr)
            m_recent.append(v.toString());
    }
}

void StickerManager::refresh()
{
    if (userid().isEmpty()) {
        emit errorOccurred(QStringLiteral("请先登录再使用表情包"));
        return;
    }
    QNetworkRequest req(QUrl(kBase + QStringLiteral("/sticker/list?userid=") + userid()));
    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        m_library.clear();
        const QJsonArray ids = obj.value("ids").toArray();
        for (const QJsonValue &v : ids) {
            const QString id = v.toString();
            m_library.append(id);
            if (!QFile::exists(cachePath(id)))
                download(id);
        }
        emit libraryChanged();
        bump();
    });
}

void StickerManager::addFile(const QString &path)
{
    addFileInternal(path, false);
}

void StickerManager::addFileAndSend(const QString &path)
{
    addFileInternal(path, true);
}

void StickerManager::addFileInternal(const QString &path, bool send)
{
    qDebug() << "[Sticker] addFile path:" << path << "userid:" << userid() << "send:" << send;
    if (userid().isEmpty()) {
        emit errorOccurred(QStringLiteral("请先登录再使用表情包"));
        return;
    }
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        qDebug() << "[Sticker] addFile open failed:" << f.errorString();
        emit errorOccurred(QStringLiteral("无法读取文件"));
        return;
    }
    const QByteArray data = f.readAll();
    qDebug() << "[Sticker] addFile bytes:" << data.size() << "ext:" << extFromMagic(data);
    if (data.size() > kMaxStickerBytes) {
        emit errorOccurred(QStringLiteral("表情不能超过 2MB"));
        return;
    }
    if (extFromMagic(data).isEmpty()) {
        emit errorOccurred(QStringLiteral("仅支持 GIF / WebP / PNG / JPG"));
        return;
    }

    QNetworkRequest req(QUrl(kBase + QStringLiteral("/sticker/upload")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/octet-stream"));
    req.setRawHeader("X-Userid", userid().toUtf8());
    setBusy(true);
    QNetworkReply *reply = m_nam.post(req, data);
    connect(reply, &QNetworkReply::finished, this, [this, reply, data, send]() {
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("上传失败，请稍后重试"));
            return;
        }
        const QString id = QJsonDocument::fromJson(reply->readAll())
                               .object().value("id").toString();
        if (id.isEmpty()) {
            emit errorOccurred(QStringLiteral("上传失败"));
            return;
        }
        // 本地落盘，省一次下载
        QDir().mkpath(cacheDir());
        QFile out(cachePath(id));
        if (out.open(QIODevice::WriteOnly))
            out.write(data);
        if (!m_library.contains(id)) {
            m_library.append(id);
            emit libraryChanged();
        }
        bump();
        emit notice(send ? QStringLiteral("已发送表情") : QStringLiteral("已添加表情"));
        emit fileAdded(id, send);
    });
}

void StickerManager::addSticker(const QString &id)
{
    if (userid().isEmpty() || id.isEmpty())
        return;
    QJsonObject body;
    body["userid"] = userid();
    body["id"] = id;
    QNetworkRequest req(QUrl(kBase + QStringLiteral("/sticker/add")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QNetworkReply *reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("添加表情失败"));
            return;
        }
        if (!m_library.contains(id)) {
            m_library.append(id);
            emit libraryChanged();
        }
        emit notice(QStringLiteral("已添加到表情包"));
    });
}

void StickerManager::removeSticker(const QString &id)
{
    if (userid().isEmpty() || id.isEmpty())
        return;
    QJsonObject body;
    body["userid"] = userid();
    body["id"] = id;
    QNetworkRequest req(QUrl(kBase + QStringLiteral("/sticker/remove")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QNetworkReply *reply = m_nam.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();
        m_library.removeAll(id);
        m_recent.removeAll(id);
        saveRecent();
        emit libraryChanged();
        emit recentChanged();
    });
}

QString StickerManager::pathFor(const QString &id)
{
    if (id.isEmpty())
        return QString();
    const QString path = cachePath(id);
    if (QFile::exists(path))
        return QUrl::fromLocalFile(path).toString();
    download(id);
    return QString();
}

void StickerManager::markRecent(const QString &id)
{
    if (id.isEmpty())
        return;
    m_recent.removeAll(id);
    m_recent.prepend(id);
    while (m_recent.size() > 30)
        m_recent.removeLast();
    saveRecent();
    emit recentChanged();
}

void StickerManager::download(const QString &id)
{
    if (id.isEmpty() || m_downloading.contains(id) || QFile::exists(cachePath(id)))
        return;
    m_downloading.insert(id);
    QNetworkRequest req(QUrl(kBase + QStringLiteral("/stickers/") + id));
    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();
        m_downloading.remove(id);
        if (reply->error() != QNetworkReply::NoError)
            return;
        QDir().mkpath(cacheDir());
        QFile out(cachePath(id));
        if (out.open(QIODevice::WriteOnly)) {
            out.write(reply->readAll());
            bump();
        }
    });
}

QString StickerManager::userid() const
{
    return m_userManager ? m_userManager->userid() : QString();
}

QString StickerManager::cacheDir() const
{
    return PlaylistCacheStore::cacheDir() + QStringLiteral("/stickers");
}

QString StickerManager::cachePath(const QString &id) const
{
    return cacheDir() + QStringLiteral("/") + id;
}

void StickerManager::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void StickerManager::bump()
{
    ++m_revision;
    emit revisionChanged();
}

void StickerManager::saveRecent()
{
    QDir().mkpath(PlaylistCacheStore::cacheDir() + QStringLiteral("/config"));
    QFile f(PlaylistCacheStore::cacheDir() + QStringLiteral("/config/sticker_recent.json"));
    if (!f.open(QIODevice::WriteOnly))
        return;
    QJsonArray arr;
    for (const QVariant &v : m_recent)
        arr.append(v.toString());
    f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}
