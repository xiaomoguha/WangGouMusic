#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQuickControls2/QQuickStyle>
#include <QQmlContext>
#include <QLoggingCategory>
#include <QIcon>
#include <QQmlComponent>
#include <QTimer>
#include <QQuickWindow>
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#ifdef Q_OS_MAC
#include <Cocoa/Cocoa.h>
#endif

#include "./CPPSrc/gethostsearch.h"
#include "./CPPSrc/searchcomplex.h"
#include "./CPPSrc/playlistmanager.h"
#include "./CPPSrc/HttpGetRequester.h"
#include "./CPPSrc/recommendation.h"
#include "./CPPSrc/trayhandler.h"
#include "./CPPSrc/WebSocketClient.h"
#include "./CPPSrc/lyricsconfigmanager.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QLoggingCategory::setFilterRules("qt.png.warning=false");

    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("QT_FFMPEG_RTSP_TRANSPORT", "tcp");         // 使用 TCP 传输，防止 UDP 丢包
    qputenv("QT_FFMPEG_RTSP_REORDER_QUEUE_SIZE", "20"); // 默认是5
    qputenv("QT_FFMPEG_PLAYER_BUFFER", "15000");        // 提高缓冲

    QApplication app(argc, argv);
    QQuickStyle::setStyle("Fusion");
    app.setWindowIcon(QIcon(":/image/wyymusic.ico"));

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [url](QObject *obj, const QUrl &objUrl)
                     {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    // ---------------- 后端对象（必须在加载 QML 之前创建） ----------------
    GetHostSearch hostSearch;
    SearchComplex complexsearch;
    Recommendation recommendation;
    PlaylistManager playlistmanager(&recommendation);
    WebSocketClient websocket(&playlistmanager);
    LyricsConfigManager lyricsConfig;

    // QML 全局注册
    qRegisterMetaType<SongInfo>("SongInfo");
    qRegisterMetaType<LyricLine>("LyricLine");
    engine.rootContext()->setContextProperty("hostSearch", &hostSearch);
    engine.rootContext()->setContextProperty("complexsearch", &complexsearch);
    engine.rootContext()->setContextProperty("playlistmanager", &playlistmanager);
    engine.rootContext()->setContextProperty("recommendation", &recommendation);
    engine.rootContext()->setContextProperty("websocket", &websocket);
    engine.rootContext()->setContextProperty("lyricsConfig", &lyricsConfig);

    // 加载 DesktopLyrics.qml 独立窗口（跨平台）
    QQmlComponent comp(&engine, QUrl("qrc:/Src/ComponentPage/DesktopLyrics.qml"));
    QObject *desktopLyricsObj = comp.create();
    QWindow *desktopLyricsWindow = qobject_cast<QWindow *>(desktopLyricsObj);

    if (desktopLyricsWindow)
    {
        desktopLyricsWindow->show();

#ifdef Q_OS_WIN
        // Windows 特有：每次显示时设置置顶和鼠标不抢焦点
        QObject::connect(desktopLyricsWindow, &QWindow::visibleChanged, [desktopLyricsWindow]()
                         {
            if(!desktopLyricsWindow->isVisible()) return;

            HWND hwnd = (HWND)desktopLyricsWindow->winId();

            // 总在最上层、不抢焦点
            SetWindowPos(hwnd, HWND_TOPMOST, 0,0,0,0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

            // 不在任务栏，点击不激活主窗口
            LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE); });
#endif

#ifdef Q_OS_MAC
        // macOS: 使用 Cocoa API 设置窗口层级
        // 需要确保窗口已经创建
        desktopLyricsWindow->requestActivate();
        
        // 获取 NSWindow (Qt 6 方式)
        WId winId = desktopLyricsWindow->winId();
        NSView *nsView = reinterpret_cast<NSView *>(winId);
        NSWindow *nsWindow = [nsView window];
        
        if (nsWindow) {
            // 使用更高的层级：Overlay 级别 (1024)
            // 这个级别比普通窗口高很多，甚至超过 Dock
            [nsWindow setLevel:1024];  // kCGOverlayWindowLevel
            
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
#endif
    }

    // 把桌面歌词对象暴露给主窗口 QML
    engine.rootContext()->setContextProperty("desktopLyricsWindow", desktopLyricsObj);

    // ---------------- 加载 QML ----------------
    engine.load(url);
    
    // 获取根窗口 (ApplicationWindow 需要通过 QQuickWindow 获取)
    QQuickWindow *window = nullptr;
    if (!engine.rootObjects().isEmpty())
    {
        QObject *rootObj = engine.rootObjects().first();
        window = qobject_cast<QQuickWindow *>(rootObj);
    }

    // ---------------- 托盘图标（跨平台） ----------------
#ifdef Q_OS_MAC
    // macOS 使用 PNG 格式图标
    QIcon trayIcon(QStringLiteral(":/image/wyyicon.png"));
#else
    QIcon trayIcon(QStringLiteral(":/image/wyymusic.ico"));
#endif
    if (trayIcon.isNull())
        trayIcon = QIcon::fromTheme(QStringLiteral("application-exit"));

    // 在栈上创建 TrayHandler，确保正确的销毁顺序
    TrayHandler trayHandler(window, &app, trayIcon, nullptr);

    return app.exec();
}
