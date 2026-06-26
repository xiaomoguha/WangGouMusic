#include "appupdater.h"
#include "ApiClient.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QCryptographicHash>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

// APP_VERSION 通过 CMake 注入，未定义时使用默认值
#ifndef APP_VERSION
#define APP_VERSION "0.1"
#endif

// 版本检测 API 地址
static const QString CHECK_UPDATE_URL =
    QStringLiteral("https://xjt-togethertracks.top/api/app/checkupdate");

AppUpdater::AppUpdater(QObject *parent)
    : QObject(parent),
      m_downloadManager(new QNetworkAccessManager(this)),
      m_currentVersion(QStringLiteral(APP_VERSION)),
      m_checkUrl(CHECK_UPDATE_URL)
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

// ─── 1. 检查更新（用 ApiClient） ─────────────────────
void AppUpdater::checkForUpdate()
{
    QUrl url(m_checkUrl);
    QUrlQuery query;
    query.addQueryItem("platform", "windows");
    query.addQueryItem("current_version", m_currentVersion);
    url.setQuery(query);

    ApiClient::instance().setUserAgent(QStringLiteral("WangGouMusic/%1").arg(m_currentVersion));

    ApiClient::instance().getJson(url.toString(),
        [this](QJsonObject obj) {
            // 兼容 { code, data: { ... } } 格式
            if (obj.contains("data") && obj.value("data").isObject())
                obj = obj.value("data").toObject();

            m_latestVersion = obj.value("latest_version").toString();
            m_downloadUrl   = obj.value("download_url").toString();
            m_releaseNotes  = obj.value("release_notes").toString();
            m_fileMd5       = obj.value("md5").toString();

            const bool hasUpdate = compareVersions(m_latestVersion, m_currentVersion) > 0;
            m_updateAvailable = hasUpdate;
            emit updateInfoChanged();
            emit checkFinished(hasUpdate);
        },
        [this](QString err, int) {
            emit checkFailed(err);
        },
        10000);
}

// ─── 2. 下载更新文件（保留独立 m_downloadManager，需要流式） ─────
void AppUpdater::downloadUpdate()
{
    if (m_downloadUrl.isEmpty() || m_downloading)
        return;

    // 下载到临时目录
    const QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
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

    m_downloadReply = m_downloadManager->get(request);
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
        errorMsg = m_downloadReply->errorString();

    if (m_downloadFile)
        m_downloadFile->close();

    // 校验 MD5
    if (success && !m_fileMd5.isEmpty())
    {
        QFile file(m_downloadedFilePath);
        if (file.open(QIODevice::ReadOnly))
        {
            QCryptographicHash hash(QCryptographicHash::Md5);
            hash.addData(&file);
            const QString fileMd5 = hash.result().toHex().toLower();
            file.close();

            if (fileMd5 != m_fileMd5.toLower())
            {
                success = false;
                errorMsg = QStringLiteral("MD5 checksum mismatch");
                QFile::remove(m_downloadedFilePath);
            }
        }
    }

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

// ─── 3. 启动安装器并退出应用 ────────────────────────
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

    // InnoSetup 静默安装参数
    QStringList args;
    args << "/SILENT"
         << "/CLOSEAPPLICATIONS"
         << "/RESTARTAPPLICATIONS"
         << "/NORESTART";

    const bool started = QProcess::startDetached(m_downloadedFilePath, args);

    if (started)
    {
        emit installStarted();
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
