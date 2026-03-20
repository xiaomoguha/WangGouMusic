#include "trayhandler.h"
#include <QAction>
#include <QDebug>
#include <QEvent>
#include <QTimer>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QWindow>

TrayHandler::TrayHandler(QQuickWindow *win, QApplication *app, const QIcon &icon,
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

  // 监听应用程序激活事件（macOS 点击 Dock 图标）
  m_app->installEventFilter(this);

  m_tray->show();
}

TrayHandler::~TrayHandler()
{
  // 先移除事件过滤器，避免在销毁过程中处理事件
  if (m_app)
    m_app->removeEventFilter(this);
  if (m_window)
    m_window->removeEventFilter(this);
}

bool TrayHandler::eventFilter(QObject *watched, QEvent *event)
{
  // 处理窗口关闭事件
  if (watched == m_window && event->type() == QEvent::Close)
  {
    if (m_quitRequested)
      return QObject::eventFilter(watched, event);
    m_window->hide();
    return true; // 阻止关闭
  }

  // 处理应用程序激活事件（macOS 点击 Dock 图标）
  if (event->type() == QEvent::ApplicationActivate)
  {
    if (m_window && !m_window->isVisible())
    {
      onShowRequested();
    }
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

  // 先断开所有连接，避免信号触发
  disconnect();

  // 移除事件过滤器
  if (m_app)
    m_app->removeEventFilter(this);
  if (m_window)
    m_window->removeEventFilter(this);

  // 隐藏托盘图标
  if (m_tray)
  {
    m_tray->hide();
    m_tray->setContextMenu(nullptr);
  }

  // 隐藏所有窗口（不调用 close，避免触发 QML 的 onClosing）
  const auto windows = QGuiApplication::topLevelWindows();
  for (QWindow *w : windows)
  {
    w->hide();
  }

  m_window = nullptr;

  // 直接退出事件循环
  QCoreApplication::exit(0);
}
