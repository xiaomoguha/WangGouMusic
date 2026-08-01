#include "macoswindow.h"

#ifdef Q_OS_MAC
#include <Cocoa/Cocoa.h>

void setupMacOSDesktopLyricsWindow(QWindow *window)
{
    if (!window)
        return;

    window->requestActivate();

    // 获取 NSWindow (Qt 6 方式)
    WId winId          = window->winId();
    NSView *nsView     = reinterpret_cast<NSView *>(winId);
    NSWindow *nsWindow = [nsView window];

    if (nsWindow)
    {
        // 使用更高的层级：Overlay 级别 (1024)
        // 这个级别比普通窗口高很多，甚至超过 Dock
        [nsWindow setLevel:1024]; // kCGOverlayWindowLevel

        // 确保窗口在所有工作空间可见
        [nsWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces |
                                        NSWindowCollectionBehaviorStationary |
                                        NSWindowCollectionBehaviorFullScreenAuxiliary];

        // 设置窗口失去焦点时不隐藏
        [nsWindow setHidesOnDeactivate:NO];

        // 强制显示
        [nsWindow orderFrontRegardless];
        [nsWindow makeKeyAndOrderFront:nil];
    }
}

void activateMacOSApp()
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

// QWK 接管后窗口底色默认是 System windowBackgroundColor（白）。内容铺满整窗后，
// 仅在面板圆角(radius 20)与原生窗口圆角之间留有透明缝隙；把底色设为 clear，让缝隙
// 透出桌面而非白色，保持原本透明圆角的观感。
void makeMacWindowBackgroundClear(QWindow *window)
{
    if (!window)
        return;
    NSView *contentView = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nsWindow  = [contentView window];
    if (!nsWindow)
        return;
    [nsWindow setOpaque:NO];
    [nsWindow setBackgroundColor:[NSColor clearColor]];
}

#endif
