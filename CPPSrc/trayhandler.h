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
    QSystemTrayIcon *m_tray = nullptr; // macOS 26+ 原生路径下不创建（见 mactrayitem.h）
    QMenu *m_menu = nullptr;
    bool m_quitRequested;
    /// macOS 26+ 原生托盘（Qt systray 在 26 上空白渲染 + 点击闪退，见 mactrayitem.h）
    bool m_nativeTray = false;
};
