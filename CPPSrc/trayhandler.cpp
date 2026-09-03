#include "trayhandler.h"
#include <QAction>
#include <QDebug>
#include <QEvent>
#include <QTimer>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QSysInfo>
#include <QWindow>
#ifdef Q_OS_MAC
#include "mactrayitem.h"
#endif

TrayHandler::TrayHandler(QQuickWindow *win, QApplication *app, const QIcon &icon, QObject *parent)
    : QObject(parent), m_window(win), m_app(app), m_quitRequested(false)
{
#ifdef Q_OS_MAC
    // macOS 26（Tahoe）+：Qt systray 状态项空白渲染，点击/拖动展开菜单时
    // QStatusItemDelegate 对非鼠标事件读 clickCount 抛 NSException 闪退。
    // 且 QSystemTrayIcon 构造即创建 QPA 托盘对象（qsystemtrayicon_qpa.cpp），
    // 光"不 show"也躲不开——26+ 上完全不建 QSystemTrayIcon，改用原生
    // NSStatusItem（见 mactrayitem.mm）。旧版 macOS 保持 QSystemTrayIcon 老路径。
    // 注意 productVersion() 形如 "27.0"，toInt() 对带小数点的串返回 0，
    // 必须先 section('.') 取主版本号再比
    const int macosMajor = QSysInfo::productVersion().section('.', 0, 0).toInt();
    qDebug() << "[TrayHandler] macOS 版本:" << QSysInfo::productVersion()
             << "主版本:" << macosMajor << "原生托盘:" << (macosMajor >= 26);
    if (macosMajor >= 26)
    {
        m_nativeTray = true;
        // 先免疫 Qt 内部 systray 委托的崩溃路径（26+ 上我们不用 Qt 托盘，
        // 详见 mactrayitem.mm：NSEvent.clickCount 保险丝 + 委托入口 no-op）
        macNeutralizeQtTrayDelegateCrash();

        // 安装事件过滤器拦截关闭事件
        if (m_window)
            m_window->installEventFilter(this);

        // 监听应用程序激活事件（macOS 点击 Dock 图标）
        m_app->installEventFilter(this);

        macInstallNativeTrayItem(
            QStringLiteral(":/image/tray_icon_mac.png"),
            QStringLiteral("网狗音乐"),
            [this]() { onShowRequested(); },
            [this]() { onQuitRequested(); }
        );
        return;
    }
#endif

    // 创建托盘图标和菜单
    m_tray = new QSystemTrayIcon(icon, this);
    // QMenu 需 QWidget* 作为 parent，TrayHandler 是 QObject 不是 QWidget，
    // 不能直接 parent；在 ~TrayHandler 中显式 delete（m_tray 的动作以 m_menu 为 parent）。
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
    connect(
        m_tray, &QSystemTrayIcon::activated, this,
        [this](QSystemTrayIcon::ActivationReason reason)
        {
            if (reason == QSystemTrayIcon::DoubleClick || reason == QSystemTrayIcon::Trigger)
            {
                onShowRequested();
            }
        }
    );

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
#ifdef Q_OS_MAC
    if (m_nativeTray)
        macRemoveNativeTrayItem();
#endif
    if (m_window)
        m_window->removeEventFilter(this);
    // m_menu 无 Qt parent（QMenu 需 QWidget*），手动释放以避免泄漏。
    // 子 QAction 以 m_menu 为 parent，会被 Qt 自动连带释放。
    if (m_menu)
    {
        delete m_menu;
        m_menu = nullptr;
    }
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

void TrayHandler::showMessage(const QString &title, const QString &message, int timeoutMs)
{
#ifdef Q_OS_MAC
    // macOS 26+ 无 QSystemTrayIcon（原生 NSStatusItem 路径），托盘消息改走系统通知
    if (m_nativeTray)
    {
        macShowNotification(title, message);
        return;
    }
#endif
    if (m_tray && m_tray->isVisible())
        m_tray->showMessage(title, message, QSystemTrayIcon::Information, timeoutMs);
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
#ifdef Q_OS_MAC
    if (m_nativeTray)
        macRemoveNativeTrayItem();
#endif
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
