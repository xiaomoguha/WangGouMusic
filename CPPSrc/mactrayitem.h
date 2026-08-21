#ifndef MACTRAYITEM_H
#define MACTRAYITEM_H

#include <functional>
#include <QString>

/**
 * @brief macOS 26+ 原生 NSStatusItem 托盘桥（仅 APPLE 平台生效）
 *
 * Qt 6.10 的 QCocoaSystemTrayIcon 在 macOS 26（Tahoe）上有两个问题：
 * 1. 状态项按钮图像不渲染，看起来是一块空白槽位；
 * 2. 点击展开菜单时 QNSStatusItem 收到 NSMenuDidBeginTrackingNotification，
 *    emitActivated() 对 SysDefined 类型的 currentEvent 调 -[NSEvent clickCount]，
 *    AppKit 直接抛 NSInternalInconsistencyException，进程闪退。
 * 因此 26+ 绕开 QSystemTrayIcon，用原生 NSStatusItem + NSMenu 自建托盘
 * （菜单项回调直接进 TrayHandler，不走 Qt 的状态项信号链路）。
 * 旧版 macOS 仍走 QSystemTrayIcon（老路径正常）。
 */

/// 安装原生托盘项（图标从 qrc 资源路径读取）。重复调用会先移除旧项。
void macInstallNativeTrayItem(const QString &iconResourcePath,
                              const QString &tooltip,
                              std::function<void()> onShow,
                              std::function<void()> onQuit);

/// 移除原生托盘项（退出时调用，幂等）。
void macRemoveNativeTrayItem();

/// 进程级免疫 Qt systray 崩溃：把 QStatusItemDelegate 里读
/// NSApp.currentEvent.clickCount 的两个入口换成 no-op（macOS 26+ 上非鼠标
/// 事件会让 AppKit 抛 NSException）。见 mactrayitem.mm 注释。
void macNeutralizeQtTrayDelegateCrash();

#endif // MACTRAYITEM_H
