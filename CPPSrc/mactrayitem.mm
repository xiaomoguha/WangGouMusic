#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>
#include "mactrayitem.h"

#include <QFile>

@class WGMTrayMenuTarget;

namespace {
NSStatusItem *g_statusItem = nil;
WGMTrayMenuTarget *g_menuTarget = nil;
}

/// Qt 崩溃路径的安全替换体：什么都不做
/// （原本要读 NSApp.currentEvent.clickCount 判断激活原因，我们不需要那个信号）
static void wgm_safeNoOp(id self, SEL _cmd, id arg)
{
    Q_UNUSED(self) Q_UNUSED(_cmd) Q_UNUSED(arg)
}

/// NSEvent.clickCount 保险丝：原实现只允许鼠标事件读 clickCount，
/// 其他事件类型直接抛 NSInternalInconsistencyException（macOS 26+ 行为）。
/// Qt 的 systray 代码会在菜单跟踪等时刻拿非鼠标 currentEvent 读 clickCount → 必炸。
/// 这里换成：鼠标事件照常走原实现；非鼠标事件安全返回 0。
static IMP g_origClickCount = nullptr;

static NSInteger wgm_safeClickCount(id self, SEL _cmd)
{
    const NSEventType t = ((NSEvent *)self).type;
    switch (t)
    {
    case NSEventTypeLeftMouseDown: case NSEventTypeRightMouseDown: case NSEventTypeOtherMouseDown:
    case NSEventTypeLeftMouseUp: case NSEventTypeRightMouseUp: case NSEventTypeOtherMouseUp:
    case NSEventTypeLeftMouseDragged: case NSEventTypeRightMouseDragged: case NSEventTypeOtherMouseDragged:
        return ((NSInteger (*)(id, SEL))g_origClickCount)(self, _cmd);
    default:
        return 0;
    }
}

void macNeutralizeQtTrayDelegateCrash()
{
    // 1) NSEvent.clickCount 保险丝（根治，覆盖 Qt 所有调用路径）
    Method m = class_getInstanceMethod([NSEvent class], @selector(clickCount));
    if (m)
    {
        g_origClickCount = method_getImplementation(m);
        method_setImplementation(m, (IMP)wgm_safeClickCount);
        NSLog(@"[WGM] NSEvent.clickCount 已加保险丝（非鼠标事件返回 0）");
    }

    // 2) 顺手把 Qt 委托的两个入口换成 no-op（双保险；我们不用 Qt 托盘信号）
    Class cls = objc_getClass("QStatusItemDelegate");
    if (cls)
    {
        class_replaceMethod(cls, @selector(statusItemMenuBeganTracking:), (IMP)wgm_safeNoOp, "v@:@");
        class_replaceMethod(cls, @selector(statusItemClicked), (IMP)wgm_safeNoOp, "v@:");
        NSLog(@"[WGM] QStatusItemDelegate 入口已替换为 no-op");
    }
    else
    {
        NSLog(@"[WGM] 未找到 QStatusItemDelegate（qcocoa 未加载？仅保留 clickCount 保险丝）");
    }
}

/// 菜单动作目标：把 NSMenuItem 回调转回 C++ std::function
@interface WGMTrayMenuTarget : NSObject
@property (copy) void (^showHandler)(void);
@property (copy) void (^quitHandler)(void);
- (void)showAction:(id)sender;
- (void)quitAction:(id)sender;
@end

@implementation WGMTrayMenuTarget
- (void)showAction:(id)sender
{
    Q_UNUSED(sender)
    if (self.showHandler) self.showHandler();
}
- (void)quitAction:(id)sender
{
    Q_UNUSED(sender)
    if (self.quitHandler) self.quitHandler();
}
@end

void macInstallNativeTrayItem(const QString &iconResourcePath,
                              const QString &tooltip,
                              std::function<void()> onShow,
                              std::function<void()> onQuit)
{
    macRemoveNativeTrayItem();

    NSStatusItem *item = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSVariableStatusItemLength];

    // 图标从 qrc 资源读出再喂 NSData（AppKit 不认识 ":/" 路径）
    QFile f(iconResourcePath);
    if (f.open(QIODevice::ReadOnly)) {
        const QByteArray bytes = f.readAll();
        NSImage *img = [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes.constData()
                                                                    length:bytes.size()]];
        if (img) {
            [img setSize:NSMakeSize(18, 18)];
            item.button.image = img;
        }
    }
    if (tooltip.isEmpty()) {
        item.button.toolTip = @"网狗音乐";
    } else {
        item.button.toolTip = tooltip.toNSString();
    }

    WGMTrayMenuTarget *target = [[WGMTrayMenuTarget alloc] init];
    target.showHandler = ^{ onShow(); };
    target.quitHandler = ^{ onQuit(); };

    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *showItem =
        [[NSMenuItem alloc] initWithTitle:@"显示主界面"
                                   action:@selector(showAction:)
                            keyEquivalent:@""];
    showItem.target = target;
    [menu addItem:showItem];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem =
        [[NSMenuItem alloc] initWithTitle:@"退出网狗音乐"
                                   action:@selector(quitAction:)
                            keyEquivalent:@""];
    quitItem.target = target;
    [menu addItem:quitItem];

    item.menu = menu;
    g_menuTarget = target; // 全局持有，target 与菜单同生命周期
    g_statusItem = item;
}

void macRemoveNativeTrayItem()
{
    if (g_statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:g_statusItem];
        g_statusItem = nil;
        g_menuTarget = nil;
    }
}

void macShowNotification(const QString &title, const QString &message)
{
    // UNUserNotificationCenter：请求授权幂等（系统只弹一次），未授权时静默丢弃
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert
                          completionHandler:^(BOOL granted, NSError *error) {
                              Q_UNUSED(granted) Q_UNUSED(error)
                          }];
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title.toNSString();
    content.body = message.toNSString();
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:@"wanggou-chat"
                                              content:content
                                              trigger:nil];
    [center addNotificationRequest:request withCompletionHandler:nil];
}
