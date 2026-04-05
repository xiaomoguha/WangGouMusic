#include "appupdater.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QCryptographicHash>
#include <QUrlQuery>
#include <QTimer>
#include <QDebug>

// APP_VERSION 通过 CMake 注入，未定义时使用默认值
#ifndef APP_VERSION
#define APP_VERSION "0.1"
#endif

// 版本检测 API 地址，可根据实际后端修改
static const QString CHECK_UPDATE_URL =
    QStringLiteral("https://xjt-togethertracks.top/api/app/check-update");

AppUpdater::AppUpdater(QObject *parent)
    : QObject(parent), m_networkManager(new QNetworkAccessManager(this)), m_currentVersion(QStringLiteral(APP_VERSION)), m_checkUrl(CHECK_UPDATE_URL)
{
}

AppUpdater::~AppUpdater()
{
    cancelDownload();
}

// ─── 属性访问器 ──────────────────────────────────────

QString AppUpdater::currentVersion() const { return m_currentVersion; }
QString AppUpdater::latestVersion() const { return m_latestVersion; }
QString AppUpdater::releaseNotes() const { return m_releaseNotes; }
bool AppUpdater::updateAvailable() const { return m_updateAvailable; }
double AppUpdater::downloadProgress() const { return m_downloadProgress; }
bool AppUpdater::downloading() const { return m_downloading; }

// ─── 版本号比较 ──────────────────────────────────────
// 支持形如 "1.2.3" 的版本号，逐段比较
int AppUpdater::compareVersions(const QString &v1, const QString &v2)
{
    QStringList parts1 = v1.split('.');
    QStringList parts2 = v2.split('.');
    int maxLen = qMax(parts1.size(), parts2.size());

    for (int i = 0; i < maxLen; ++i)
    {
        int num1 = (i < parts1.size()) ? parts1[i].toInt() : 0;
        int num2 = (i < parts2.size()) ? parts2[i].toInt() : 0;
        if (num1 != num2)
            return num1 - num2;
    }
    return 0;
}

// ─── 1. 检查更新 ─────────────────────────────────────
void AppUpdater::checkForUpdate()
{
    QUrl url(m_checkUrl);
    QUrlQuery query;
    query.addQueryItem("platform", "windows");
    query.addQueryItem("current_version", m_currentVersion);
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("WangGouMusic/%1").arg(m_currentVersion));

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &AppUpdater::onCheckReplyFinished);
}

void AppUpdater::onCheckReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply)
        return;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError)
    {
        emit checkFailed(reply->errorString());
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
    {
        emit checkFailed(QStringLiteral("Invalid response format"));
        return;
    }

    QJsonObject obj = doc.object();

    /*
     * 期望的 JSON 格式:
     * {
     *   "latest_version": "0.2",
     *   "download_url": "https://...setup.exe",
     *   "release_notes": "修复了...",
     *   "force_update": false,
     *   "md5": "abc123..."
     * }
     */
    m_latestVersion = obj.value("latest_version").toString();
    m_downloadUrl = obj.value("download_url").toString();
    m_releaseNotes = obj.value("release_notes").toString();
    m_fileMd5 = obj.value("md5").toString();

    bool hasUpdate = compareVersions(m_latestVersion, m_currentVersion) > 0;
    m_updateAvailable = hasUpdate;
    emit updateInfoChanged();
    emit checkFinished(hasUpdate);
}

// ─── 2. 下载更新文件 ─────────────────────────────────
void AppUpdater::downloadUpdate()
{
    if (m_downloadUrl.isEmpty() || m_downloading)
        return;

    // 下载到临时目录
    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QDir dir(tempDir);
    m_downloadedFilePath = dir.filePath(
        QStringLiteral("WangGouMusic_%1_setup.exe").arg(m_latestVersion));

    m_downloadFile = new QFile(m_downloadedFilePath, this);
    if (!m_downloadFile->open(QIODevice::WriteOnly))
    {
        emit downloadFailed(
            QStringLiteral("Cannot write to temp file: %1").arg(m_downloadFile->errorString()));
        delete m_downloadFile;
        m_downloadFile = nullptr;
        return;
    }

    m_downloading = true;
    m_downloadProgress = 0.0;
    emit downloadingChanged();
    emit downloadProgressChanged();

    QNetworkRequest request{QUrl(m_downloadUrl)};
    request.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("WangGouMusic/%1").arg(m_currentVersion));

    m_downloadReply = m_networkManager->get(request);
    connect(m_downloadReply, &QNetworkReply::downloadProgress,
            this, &AppUpdater::onDownloadProgress);
    connect(m_downloadReply, &QNetworkReply::finished,
            this, &AppUpdater::onDownloadFinished);

    // 边下载边写入
    connect(m_downloadReply, &QIODevice::readyRead, this, [this]()
            {
        if (m_downloadFile && m_downloadReply) {
            m_downloadFile->write(m_downloadReply->readAll());
        } });
}

void AppUpdater::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal > 0)
    {
        m_downloadProgress = static_cast<double>(bytesReceived) / bytesTotal;
        emit downloadProgressChanged();
    }
}

void AppUpdater::onDownloadFinished()
{
    if (!m_downloadReply)
        return;

    bool success = (m_downloadReply->error() == QNetworkReply::NoError);
    QString errorMsg;

    if (!success)
    {
        errorMsg = m_downloadReply->errorString();
    }

    // 关闭文件
    if (m_downloadFile)
    {
        m_downloadFile->close();
    }

    // 校验 MD5（如果服务端提供了）
    if (success && !m_fileMd5.isEmpty())
    {
        QFile file(m_downloadedFilePath);
        if (file.open(QIODevice::ReadOnly))
        {
            QCryptographicHash hash(QCryptographicHash::Md5);
            hash.addData(&file);
            QString fileMd5 = hash.result().toHex().toLower();
            file.close();

            if (fileMd5 != m_fileMd5.toLower())
            {
                success = false;
                errorMsg = QStringLiteral("MD5 checksum mismatch");
                QFile::remove(m_downloadedFilePath);
            }
        }
    }

    // 清理
    m_downloadReply->deleteLater();
    m_downloadReply = nullptr;
    delete m_downloadFile;
    m_downloadFile = nullptr;

    m_downloading = false;
    emit downloadingChanged();

    if (success)
    {
        m_downloadProgress = 1.0;
        emit downloadProgressChanged();
        emit downloadFinished();
    }
    else
    {
        m_downloadProgress = 0.0;
        emit downloadProgressChanged();
        emit downloadFailed(errorMsg);
    }
}

// ─── 3. 启动安装器并退出应用 ──────────────────────────
void AppUpdater::installUpdate()
{
    if (m_downloadedFilePath.isEmpty())
        return;

    QFileInfo fi(m_downloadedFilePath);
    if (!fi.exists())
    {
        emit downloadFailed(QStringLiteral("Installer file not found"));
        return;
    }

    // InnoSetup 静默安装参数:
    //   /SILENT              - 静默安装（只显示进度条，不显示向导页面）
    //   /CLOSEAPPLICATIONS   - 自动关闭正在运行的旧版本
    //   /RESTARTAPPLICATIONS - 安装完成后重新启动应用
    //   /NORESTART           - 不重启系统
    QStringList args;
    args << "/SILENT"
         << "/CLOSEAPPLICATIONS"
         << "/RESTARTAPPLICATIONS"
         << "/NORESTART";

    bool started = QProcess::startDetached(m_downloadedFilePath, args);

    if (started)
    {
        emit installStarted();
        // 给 QML 一点时间处理 installStarted 信号后再退出
        QTimer::singleShot(500, qApp, &QCoreApplication::quit);
    }
    else
    {
        emit downloadFailed(QStringLiteral("Failed to start installer"));
    }
}

// ─── 4. 取消下载 ─────────────────────────────────────
void AppUpdater::cancelDownload()
{
    if (m_downloadReply)
    {
        m_downloadReply->abort();
        m_downloadReply->deleteLater();
        m_downloadReply = nullptr;
    }

    if (m_downloadFile)
    {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
        QFile::remove(m_downloadedFilePath);
    }

    if (m_downloading)
    {
        m_downloading = false;
        m_downloadProgress = 0.0;
        emit downloadingChanged();
        emit downloadProgressChanged();
    }
}
