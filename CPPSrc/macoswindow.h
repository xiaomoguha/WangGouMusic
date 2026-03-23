#ifndef MACOSWINDOW_H
#define MACOSWINDOW_H

#include <QWindow>

// macOS 窗口工具函数
#ifdef Q_OS_MAC
void setupMacOSDesktopLyricsWindow(QWindow *window);
#else
// 其他平台空实现
inline void setupMacOSDesktopLyricsWindow(QWindow *) {}
#endif

#endif // MACOSWINDOW_H
