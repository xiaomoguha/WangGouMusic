#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQuickControls2/QQuickStyle>
#include <QQmlContext>
#include <QLoggingCategory>
#include <QIcon>
#include <QQmlComponent>
#ifdef Q_OS_WIN
#include <windows.h>
#endif

#include "./CPPSrc/gethostsearch.h"
#include "./CPPSrc/searchcomplex.h"
#include "./CPPSrc/playlistmanager.h"
#include "./CPPSrc/HttpGetRequester.h"
#include "./CPPSrc/recommendation.h"
#include "./CPPSrc/trayhandler.h"
#include "./CPPSrc/WebSocketClient.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QLoggingCategory::setFilterRules("qt.png.warning=false");

    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("QT_FFMPEG_RTSP_TRANSPORT", "tcp");  // 使用 TCP 传输，防止 UDP 丢包
    qputenv("QT_FFMPEG_RTSP_REORDER_QUEUE_SIZE", "20");   // 默认是5
    qputenv("QT_FFMPEG_PLAYER_BUFFER", "15000");          // 提高缓冲

    QApplication app(argc, argv);
    QQuickStyle::setStyle("Fusion");


    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
#ifdef Q_OS_WIN
    // 加载 DesktopLyrics.qml 独立窗口
    QQmlComponent comp(&engine, QUrl("qrc:/Src/ComponentPage/DesktopLyrics.qml"));
    QObject *desktopLyricsObj = comp.create();
    QWindow *desktopLyricsWindow = qobject_cast<QWindow*>(desktopLyricsObj);

    if (desktopLyricsWindow)
    {
        desktopLyricsWindow->show();

        // 每次显示时设置置顶和鼠标不抢焦点
        QObject::connect(desktopLyricsWindow, &QWindow::visibleChanged, [desktopLyricsWindow]() {
            if(!desktopLyricsWindow->isVisible()) return;

            HWND hwnd = (HWND)desktopLyricsWindow->winId();

            // 总在最上层、不抢焦点
            SetWindowPos(hwnd, HWND_TOPMOST, 0,0,0,0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

            // 不在任务栏，点击不激活主窗口
            LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
        });
    }


    // 把桌面歌词对象暴露给主窗口 QML
    engine.rootContext()->setContextProperty("desktopLyricsWindow", desktopLyricsObj);
#endif
    // ---------------- 后端对象 ----------------
    GetHostSearch hostSearch;
    SearchComplex complexsearch;
    Recommendation recommendation;
    PlaylistManager playlistmanager(&recommendation);
    WebSocketClient websocket(&playlistmanager);


    // QML 全局注册
    qRegisterMetaType<SongInfo>("SongInfo");
    qRegisterMetaType<LyricLine>("LyricLine");
    engine.rootContext()->setContextProperty("hostSearch", &hostSearch);
    engine.rootContext()->setContextProperty("complexsearch", &complexsearch);
    engine.rootContext()->setContextProperty("playlistmanager", &playlistmanager);
    engine.rootContext()->setContextProperty("recommendation", &recommendation);
    engine.rootContext()->setContextProperty("websocket", &websocket);

    // ---------------- 加载 QML ----------------
    engine.load(url);
#ifdef Q_OS_WIN
    // 获取根窗口
    QWindow *window = nullptr;
    if (!engine.rootObjects().isEmpty())
    {
        QObject *rootObj = engine.rootObjects().first();
        window = qobject_cast<QWindow *>(rootObj);
    }


    new MediaKeyFilter(&playlistmanager);


    // ---------------- 托盘图标 ----------------
    QIcon trayIcon(QStringLiteral(":/image/wyymusic.ico"));
    if (trayIcon.isNull())
        trayIcon = QIcon::fromTheme(QStringLiteral("application-exit"));

    new TrayHandler(window, &app, trayIcon, &app);

#endif
    return app.exec();
}
