#ifndef MACTRAYITEM_H
#define MACTRAYITEM_H

#include <functional>
#include <QString>

// macOS 26+ 原生 NSStatusItem 托盘桥（仅 APPLE 平台生效）

// 安装原生托盘项（图标从 qrc 资源路径读取）。重复调用会先移除旧项。
void macInstallNativeTrayItem(const QString &iconResourcePath,
                              const QString &tooltip,
                              std::function<void()> onShow,
                              std::function<void()> onQuit);

// 移除原生托盘项（退出时调用，幂等）。
void macRemoveNativeTrayItem();

// 进程级免疫 Qt systray 崩溃：把 QStatusItemDelegate 里读
// NSApp.currentEvent.clickCount 的两个入口换成 no-op（macOS 26+ 上非鼠标
void macNeutralizeQtTrayDelegateCrash();

// 原生系统通知（UNUserNotificationCenter）。macOS 26+ 无 QSystemTrayIcon，
// 托盘 showMessage 不可用，聊天通知从这里走；首次调用触发系统授权弹窗。
void macShowNotification(const QString &title, const QString &message);

#endif // MACTRAYITEM_H
