#pragma once
#include <QObject>
#include <QWindow>
#include <QQuickWindow>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QApplication>
#include <QIcon>

class TrayHandler : public QObject
{
    Q_OBJECT
public:
    TrayHandler(QQuickWindow *win, QApplication *app, const QIcon &icon, QObject *parent = nullptr);
    ~TrayHandler() override;

    // 显示系统通知（跨平台：Windows 右下角横幅 / macOS 通知中心）
    Q_INVOKABLE void showMessage(const QString &title, const QString &message, int timeoutMs = 3000);

private slots:
    void onShowRequested();
    void onQuitRequested();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    QQuickWindow *m_window;
    QApplication *m_app;
    QSystemTrayIcon *m_tray;
    QMenu *m_menu;
    bool m_quitRequested;
};
