#ifndef MACOSWINDOW_H
#define MACOSWINDOW_H

#include <QWindow>

// macOS 窗口工具函数
#ifdef Q_OS_MAC
void setupMacOSDesktopLyricsWindow(QWindow *window);
void activateMacOSApp();
void makeMacWindowBackgroundClear(QWindow *window);
#else
// 其他平台空实现
inline void setupMacOSDesktopLyricsWindow(QWindow *) {}
inline void activateMacOSApp() {}
inline void makeMacWindowBackgroundClear(QWindow *) {}
#endif

#endif // MACOSWINDOW_H
