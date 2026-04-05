#ifndef APPUPDATER_H
#define APPUPDATER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QJsonObject>

class AppUpdater : public QObject
{
    Q_OBJECT

    // QML 可读属性
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY updateInfoChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY updateInfoChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateInfoChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)

public:
    explicit AppUpdater(QObject *parent = nullptr);
    ~AppUpdater();

    QString currentVersion() const;
    QString latestVersion() const;
    QString releaseNotes() const;
    bool updateAvailable() const;
    double downloadProgress() const;
    bool downloading() const;

    // QML 可调用方法
    Q_INVOKABLE void checkForUpdate();
    Q_INVOKABLE void downloadUpdate();
    Q_INVOKABLE void installUpdate();
    Q_INVOKABLE void cancelDownload();

signals:
    void updateInfoChanged();
    void downloadProgressChanged();
    void downloadingChanged();
    void checkFinished(bool hasUpdate);
    void checkFailed(const QString &error);
    void downloadFinished();
    void downloadFailed(const QString &error);
    void installStarted();

private slots:
    void onCheckReplyFinished();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onDownloadFinished();

private:
    // 比较版本号，返回 >0 表示 v1 > v2
    static int compareVersions(const QString &v1, const QString &v2);

    QNetworkAccessManager *m_networkManager;

    // 版本信息
    QString m_currentVersion;
    QString m_latestVersion;
    QString m_releaseNotes;
    QString m_downloadUrl;
    QString m_fileMd5;
    bool m_updateAvailable = false;

    // 下载状态
    QNetworkReply *m_downloadReply = nullptr;
    QFile *m_downloadFile = nullptr;
    QString m_downloadedFilePath;
    double m_downloadProgress = 0.0;
    bool m_downloading = false;

    // 配置
    QString m_checkUrl;
};

#endif // APPUPDATER_H
