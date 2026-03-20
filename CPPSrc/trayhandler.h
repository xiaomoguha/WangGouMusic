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
