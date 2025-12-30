#include "trayhandler.h"
#include <QAction>
#include <QDebug>
#include <QEvent>

TrayHandler::TrayHandler(QWindow *win, QApplication *app, const QIcon &icon,
                         QObject *parent)
    : QObject(parent), m_window(win), m_app(app), m_quitRequested(false)
{
  // 创建托盘图标和菜单
  m_tray = new QSystemTrayIcon(icon, this);
  m_menu = new QMenu();

  QAction *showAction = new QAction(QStringLiteral("显示主界面"), m_menu);
  QAction *quitAction = new QAction(QStringLiteral("退出网狗音乐"), m_menu);

  m_menu->addAction(showAction);
  m_menu->addSeparator();
  m_menu->addAction(quitAction);

  m_tray->setContextMenu(m_menu);
  m_tray->setToolTip(QStringLiteral("网狗音乐"));

  connect(showAction, &QAction::triggered, this, &TrayHandler::onShowRequested);
  connect(quitAction, &QAction::triggered, this, &TrayHandler::onQuitRequested);

  // 双击托盘图标显示窗口
  connect(m_tray, &QSystemTrayIcon::activated, this,
          [this](QSystemTrayIcon::ActivationReason reason)
          {
            if (reason == QSystemTrayIcon::DoubleClick ||
                reason == QSystemTrayIcon::Trigger)
            {
              onShowRequested();
            }
          });

  // 安装事件过滤器拦截关闭事件
  if (m_window)
    m_window->installEventFilter(this);

  m_tray->show();
}

TrayHandler::~TrayHandler()
{
  if (m_window)
    m_window->removeEventFilter(this);
}

bool TrayHandler::eventFilter(QObject *watched, QEvent *event)
{
  if (watched == m_window && event->type() == QEvent::Close)
  {
    if (m_quitRequested)
      return QObject::eventFilter(watched, event);
    m_window->hide();
    return true; // 阻止关闭
  }
  return QObject::eventFilter(watched, event);
}

void TrayHandler::onShowRequested()
{
  if (!m_window)
    return;
  m_window->show();
  m_window->raise();
  m_window->requestActivate();
}

void TrayHandler::onQuitRequested()
{
  m_quitRequested = true;
  if (m_window)
    m_window->close();
  else
    m_app->quit();
}
