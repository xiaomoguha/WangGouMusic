#include "singleapplication.h"
#include "macoswindow.h"

#include <QLocalServer>
#include <QLocalSocket>
#include <QLockFile>
#include <QStandardPaths>
#include <QQuickWindow>
#include <QDebug>

SingleApplication::SingleApplication(const QString &appName, QObject *parent)
    : QObject(parent), m_lockFile(nullptr), m_server(nullptr), m_window(nullptr),
      m_isRunning(false), m_serverName(appName)
{
    QString lockPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_lockFile = new QLockFile(lockPath + "/" + appName + ".lock");
    m_lockFile->setStaleLockTime(0);

    if (!m_lockFile->tryLock(100)) {
        m_isRunning = true;
        m_server = nullptr;
    } else {
        m_isRunning = false;
        QLocalServer::removeServer(m_serverName);
        m_server = new QLocalServer(this);
        m_server->listen(m_serverName);
        connect(m_server, &QLocalServer::newConnection, this, &SingleApplication::onNewConnection);
    }
}

SingleApplication::~SingleApplication()
{
    if (m_server) {
        m_server->close();
    }
    if (m_lockFile) {
        if (m_lockFile->isLocked())
            m_lockFile->unlock();
        delete m_lockFile;
    }
}

bool SingleApplication::isRunning() const
{
    return m_isRunning;
}

bool SingleApplication::activateRunningInstance()
{
    QLocalSocket socket;
    socket.connectToServer(m_serverName, QIODevice::WriteOnly);
    if (socket.waitForConnected(1000)) {
        socket.waitForBytesWritten(100);
        socket.close();
        return true;
    }
    return false;
}

void SingleApplication::listen(QQuickWindow *window)
{
    m_window = window;
}

void SingleApplication::onNewConnection()
{
    QLocalSocket *socket = m_server->nextPendingConnection();
    if (socket) {
        socket->waitForReadyRead(100);
        delete socket;
    }
    bringWindowToFront();
}

void SingleApplication::bringWindowToFront()
{
    if (!m_window)
        return;

    m_window->show();
    m_window->raise();
    m_window->requestActivate();

    activateMacOSApp();
}
