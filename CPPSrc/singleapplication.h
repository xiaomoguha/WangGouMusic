#pragma once

#include <QObject>

class QLocalServer;
class QLockFile;
class QQuickWindow;

class SingleApplication : public QObject
{
    Q_OBJECT
public:
    explicit SingleApplication(const QString &appName, QObject *parent = nullptr);
    ~SingleApplication() override;

    bool isRunning() const;
    bool activateRunningInstance();
    void listen(QQuickWindow *window);

private:
    void onNewConnection();
    void bringWindowToFront();

    QLockFile *m_lockFile;
    QLocalServer *m_server;
    QQuickWindow *m_window;
    bool m_isRunning;
    QString m_serverName;
};
