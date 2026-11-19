#include <QApplication>
#include <QFontDatabase>
#include <QIcon>
#include <QLoggingCategory>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QSettings>
#include <QScreen>
#include <QGuiApplication>
#include <QtQuickControls2/QQuickStyle>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QStandardPaths>
#include <QQmlNetworkAccessManagerFactory>
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#include "./CPPSrc/macoswindow.h"
#ifdef Q_OS_MAC
#include <QWKQuick/quickwindowagent.h>
#endif
#include "./CPPSrc/CrashHandler.h"
#include "./CPPSrc/cursortracker.h"
#include "./CPPSrc/windowstatemanager.h"
#include "./CPPSrc/ClickThroughHelper.h"
#include "./CPPSrc/PlaylistCacheStore.h"
#include "./CPPSrc/dailyrecommend.h"
#include "./CPPSrc/DominantColorExtractor.h"
#include "./CPPSrc/HttpGetRequester.h"
#include "./CPPSrc/NowPlayingMediaController.h"
#include "./CPPSrc/WebSocketClient.h"
#include "./CPPSrc/stickermanager.h"
#include "./CPPSrc/appupdater.h"
#include "./CPPSrc/gethostsearch.h"
#include "./CPPSrc/lyricsconfigmanager.h"
#include "./CPPSrc/personalfm.h"
#include "./CPPSrc/ranklist.h"
#include "./CPPSrc/albummanager.h"
#include "./CPPSrc/historymanager.h"
#include "./CPPSrc/discovermanager.h"
#include "./CPPSrc/proxymanager.h"
#include "./CPPSrc/mvmanager.h"
#include "./CPPSrc/airecommendmanager.h"
#include "./CPPSrc/artistmanager.h"
#include "./CPPSrc/songcomments.h"
#include "./CPPSrc/serveradminmanager.h"
#include "./CPPSrc/playlistcollection.h"
#include "./CPPSrc/playlistmanager.h"
#include "./CPPSrc/recommendation.h"
#include "./CPPSrc/searchcomplex.h"
#include "./CPPSrc/searchhistorymanager.h"
#include "./CPPSrc/singleapplication.h"
#include "./CPPSrc/trayhandler.h"
#include "./CPPSrc/usermanager.h"
#include <QQmlEngine>
#include <memory>

// --mobile：桌面端预览移动端 UI（加载 main_mobile.qml，窗口固定手机尺寸）。
static bool isMobilePreviewArg(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i)
    {
        if (QString::fromLocal8Bit(argv[i]).compare(QStringLiteral("--mobile"), Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

class HttpGetRequesterHelper : public HttpGetRequester
{
    Q_OBJECT
public:
    HttpGetRequesterHelper(QObject *parent = nullptr) : HttpGetRequester(10000, parent) {}
};

// QML 网络图片磁盘缓存
class NetworkCacheFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        QNetworkAccessManager *nam = new QNetworkAccessManager(parent);
        QNetworkDiskCache *cache   = new QNetworkDiskCache(nam);
        cache->setCacheDirectory(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/images");
        cache->setMaximumCacheSize(100 * 1024 * 1024); // 100MB
        nam->setCache(cache);
        return nam;
    }
};

// --tour 自截帧助手：Window.contentItem 没有 QML engine，QML 侧 grabToImage 会
// 被 "item has no QML engine" 拒绝；改走 QQuickWindow::grabWindow()——
class TourGrabber : public QObject
{
    Q_OBJECT
public slots:
    bool grab(QObject *windowObj, const QString &path)
    {
        auto *w = qobject_cast<QQuickWindow *>(windowObj);
        if (!w)
            return false;
        return w->grabWindow().save(path);
    }
};

int main(int argc, char *argv[])
{
    // 在 QApplication 之前安装崩溃日志处理器
    CrashHandler::install();

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QLoggingCategory::setFilterRules("qt.png.warning=false");

    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("QT_FFMPEG_RTSP_TRANSPORT", "tcp");         // 使用 TCP 传输，防止 UDP 丢包
    qputenv("QT_FFMPEG_RTSP_REORDER_QUEUE_SIZE", "20"); // 默认是5
    qputenv("QT_FFMPEG_PLAYER_BUFFER", "15000");        // 提高缓冲

    QApplication app(argc, argv);

    const bool mobileMode = isMobilePreviewArg(argc, argv);

    // 缓存目录升级：旧版平铺结构（根目录 .mp3/*.json）迁移到分类目录（songs/128|320|flac、config、lyrics）。
    PlaylistCacheStore::migrateLegacyCache();

    // 注册内嵌中文字体 Sarasa Gothic SC（随包打包，跨平台显示一致）
    QFontDatabase::addApplicationFont(":/fonts/SarasaGothicSC-Regular.ttf");
    QFontDatabase::addApplicationFont(":/fonts/SarasaGothicSC-SemiBold.ttf");
    QFontDatabase::addApplicationFont(":/fonts/SarasaGothicSC-Bold.ttf");
    // 设为应用默认字体：未显式指定 family 的 QML 文本也会统一使用 Sarasa Gothic SC
    app.setFont(QFont(QStringLiteral("Sarasa Gothic SC")));

    // 检测上次崩溃日志，如有则弹窗提示
    CrashHandler::checkPreviousCrash();

    // 单实例检测：如果已有实例在运行，激活其主窗口并退出。
    std::unique_ptr<SingleApplication> singleApp;
    if (!mobileMode)
    {
        singleApp = std::make_unique<SingleApplication>("WangGouMusic");
        if (singleApp->isRunning())
        {
            singleApp->activateRunningInstance();
            return 0;
        }
    }

    QQuickStyle::setStyle("Fusion");
#ifndef Q_OS_MAC
    app.setWindowIcon(QIcon(":/image/wyymusic.ico"));
#endif

    QQmlApplicationEngine engine;

    // 启用网络图片磁盘缓存（QML Image 自动缓存，无需改 QML 代码）
    NetworkCacheFactory cacheFactory;
    engine.setNetworkAccessManagerFactory(&cacheFactory);

    // 注册 HttpGetRequester 为可实例化的 QML 类型
    qmlRegisterType<HttpGetRequesterHelper>("NetworkRequest", 1, 0, "HttpGetRequester");

    // 入口 QML：桌面 main.qml / 移动端 main_mobile.qml
    const QUrl url(mobileMode ? QStringLiteral("qrc:/main_mobile.qml")
                              : QStringLiteral("qrc:/main.qml"));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl)
        {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
    );

    // ---------------- 后端对象（必须在加载 QML 之前创建） ----------------
    GetHostSearch hostSearch;
    SearchComplex complexsearch;
    SearchHistoryManager searchHistory;
    Recommendation recommendation;
    PlaylistManager playlistmanager(&recommendation);
    DominantColorExtractor playlistColorExtractor;   // 歌单页专用（独立于播放页的播放管理器提取器）
    UserManager userManager;
    PlaylistCollection playlistCollection;
    DailyRecommend dailyRecommend;
    PersonalFM personalFM;
    RankList rankList;
    AlbumManager albumManager;
    HistoryManager historyManager;
    DiscoverManager discoverManager;
    MvManager mvManager;
    AiRecommendManager aiRecommendManager;
    ArtistManager artistManager;
    SongComments songComments;
    ServerAdminManager serverAdmin;
    dailyRecommend.setUserManager(&userManager);
    personalFM.setUserManager(&userManager);
    playlistCollection.setUserManager(&userManager);
    historyManager.setUserManager(&userManager);
    WebSocketClient websocket(&playlistmanager, &userManager);
    StickerManager stickers(&userManager);
    // 桌面媒体控制集成（Windows SMTC / macOS NowPlaying）。
    std::unique_ptr<NowPlayingMediaController> mediaController;
    if (!mobileMode)
        mediaController = std::make_unique<NowPlayingMediaController>(&playlistmanager);
    LyricsConfigManager lyricsConfig;
    AppUpdater appUpdater;
    ProxyManager proxyManager;   // 进程级代理（构造即 apply，须早于 engine.load 与任何网络请求）

    // QML 全局注册
    qRegisterMetaType<SongInfo>("SongInfo");
    qRegisterMetaType<LyricLine>("LyricLine");
    engine.rootContext()->setContextProperty("hostSearch", &hostSearch);
    TourGrabber tourGrabber;   // --tour 巡览自截帧（见类注释）
    engine.rootContext()->setContextProperty("tourGrabber", &tourGrabber);
    engine.rootContext()->setContextProperty("complexsearch", &complexsearch);
    engine.rootContext()->setContextProperty("searchHistory", &searchHistory);
    // 全局指针追踪：供 QML 做指针与背景星空的联动（见 StarfieldLayer.qml）。
    std::unique_ptr<CursorTracker> cursorTracker;
    if (!mobileMode)
    {
        cursorTracker = std::make_unique<CursorTracker>();
        engine.rootContext()->setContextProperty("cursorTracker", cursorTracker.get());
    }
    // 主窗口位置记忆：QML 启动时读取、拖动后写回（见 main.qml 的 windowPosSaveTimer）
    WindowStateManager windowState;
    if (!mobileMode)
        engine.rootContext()->setContextProperty("windowState", &windowState);
    engine.rootContext()->setContextProperty("playlistmanager", &playlistmanager);
    engine.rootContext()->setContextProperty("playlistColorExtractor", &playlistColorExtractor);
    engine.rootContext()->setContextProperty("recommendation", &recommendation);
    engine.rootContext()->setContextProperty("websocket", &websocket);
    engine.rootContext()->setContextProperty("stickers", &stickers);
    engine.rootContext()->setContextProperty("lyricsConfig", &lyricsConfig);
    engine.rootContext()->setContextProperty("appUpdater", &appUpdater);
    engine.rootContext()->setContextProperty("userManager", &userManager);
    engine.rootContext()->setContextProperty("playlistCollection", &playlistCollection);
    engine.rootContext()->setContextProperty("dailyRecommend", &dailyRecommend);
    engine.rootContext()->setContextProperty("personalFM", &personalFM);
    engine.rootContext()->setContextProperty("rankList", &rankList);
    engine.rootContext()->setContextProperty("albumManager", &albumManager);
    engine.rootContext()->setContextProperty("historyManager", &historyManager);
    engine.rootContext()->setContextProperty("discoverManager", &discoverManager);
    engine.rootContext()->setContextProperty("mvManager", &mvManager);
    engine.rootContext()->setContextProperty("proxyManager", &proxyManager);
    engine.rootContext()->setContextProperty("aiRecommendManager", &aiRecommendManager);

    // 播放上报听歌历史：歌曲自然播完（EndOfMedia）才上报一次；中途切歌/退出不算
    // 单曲循环每圈播完可再报，次数累加；未登录不上报
    QObject::connect(&playlistmanager, &PlaylistManager::playbackFinished, &historyManager, [&]() {
        if (!userManager.isLoggedIn())
            return;
        historyManager.reportPlayed(playlistmanager.currentTitle(), playlistmanager.currentSongHash());
    });
    engine.rootContext()->setContextProperty("artistManager", &artistManager);
    engine.rootContext()->setContextProperty("songComments", &songComments);
    engine.rootContext()->setContextProperty("serverAdmin", &serverAdmin);

    // 桌面歌词鼠标穿透控制器（锁定时窗口穿透，仅解锁按钮可点击）
    ClickThroughHelper clickThroughHelper;
    engine.rootContext()->setContextProperty("clickThroughHelper", &clickThroughHelper);

    // 加载 DesktopLyrics.qml 独立窗口（跨平台）
    if (!mobileMode)
    QTimer::singleShot(
        0, &engine,
        [&engine, &lyricsConfig, &clickThroughHelper]()
        {
            QQmlComponent comp(&engine, QUrl("qrc:/Src/ComponentPage/DesktopLyrics.qml"));
            QObject *desktopLyricsObj    = comp.create();
            QWindow *desktopLyricsWindow = qobject_cast<QWindow *>(desktopLyricsObj);

            if (desktopLyricsWindow)
            {
                // 可见性由 lyricsConfig.enabled 驱动：初始未开启则不显示
                if (lyricsConfig.enabled())
                    desktopLyricsWindow->show();

#ifdef Q_OS_WIN
                // Windows 特有：每次显示时设置置顶和鼠标不抢焦点
                QObject::connect(
                    desktopLyricsWindow, &QWindow::visibleChanged,
                    [desktopLyricsWindow]()
                    {
                        if (!desktopLyricsWindow->isVisible())
                            return;

                        HWND hwnd = (HWND)desktopLyricsWindow->winId();

                        // 总在最上层、不抢焦点
                        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

                        // 不在任务栏，点击不激活主窗口
                        LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
                        SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
                    }
                );
#endif

#ifdef Q_OS_MAC
                // macOS: 使用 Cocoa API 设置窗口层级
                setupMacOSDesktopLyricsWindow(desktopLyricsWindow);
#endif
            }

            // 把桌面歌词对象暴露给主窗口 QML
            engine.rootContext()->setContextProperty("desktopLyricsWindow", desktopLyricsObj);

            // 将窗口指针交给穿透控制器
            clickThroughHelper.setWindow(desktopLyricsWindow);
        }
    );
    // ---------------- 加载 QML ----------------
    engine.load(url);

    // 获取根窗口 (ApplicationWindow 需要通过 QQuickWindow 获取)
    QQuickWindow *window = nullptr;
    if (!engine.rootObjects().isEmpty())
    {
        QObject *rootObj = engine.rootObjects().first();
        window           = qobject_cast<QQuickWindow *>(rootObj);
    }

    // 把主窗口交给光标追踪（换算窗口局部坐标 / 判断指针是否在窗口内）
    if (window && cursorTracker)
        cursorTracker->attachWindow(window);

#ifdef Q_OS_MAC
    // QWindowKit 接管主窗口：真原生 traffic lights（系统级悬停图案 + 关/最小/缩放动作），
    // 内容铺满到标题栏下方（无透明带）。配置完再 show，避免启动闪烁；QML 在 mac 上不自行 show。
    if (window)
    {
        auto windowAgent = new QWK::QuickWindowAgent(window);
        windowAgent->setup(window);
        window->show();
        makeMacWindowBackgroundClear(window);
    }
#endif

#ifdef Q_OS_WIN
    // Windows 窗口圆角：Win11 优先用 DWM 系统圆角；Win10（无 DWMWA_WINDOW_CORNER_PREFERENCE）
    if (window && !mobileMode) // 预览窗口固定手机尺寸，无需系统圆角
    {
        auto applyRoundedCorners = [window]() {
            HWND hwnd = (HWND)window->winId();
            if (!hwnd)
                return;

            // 1) Win11+：DWM 系统圆角
            typedef HRESULT(WINAPI *DwmSetWindowAttributeFn)(HWND, DWORD, LPCVOID, DWORD);
            static auto dwmSetAttr = (DwmSetWindowAttributeFn)GetProcAddress(
                GetModuleHandleW(L"dwmapi.dll"), "DwmSetWindowAttribute");
            if (dwmSetAttr) {
                DWORD pref = 2; // DWMWCP_ROUND
                if (SUCCEEDED(dwmSetAttr(hwnd, 33, &pref, sizeof(pref)))) // DWMWA_WINDOW_CORNER_PREFERENCE
                    return;
            }

            // 2) Win10 兜底：区域圆角（最大化时取消，半径与 QML 面板 radius:20 对齐）
            if (IsZoomed(hwnd)) {
                SetWindowRgn(hwnd, NULL, TRUE);
                return;
            }
            RECT rc;
            GetClientRect(hwnd, &rc);
            int radius = qRound(20 * window->devicePixelRatio());
            HRGN rgn = CreateRoundRectRgn(0, 0, rc.right + 1, rc.bottom + 1, radius, radius);
            SetWindowRgn(hwnd, rgn, TRUE);
        };
        // 首次 show 后 winId 才有效；resize/再显示时重新应用
        QObject::connect(window, &QQuickWindow::visibleChanged, window, applyRoundedCorners);
        QObject::connect(window, &QQuickWindow::widthChanged, window, applyRoundedCorners);
        QObject::connect(window, &QQuickWindow::heightChanged, window, applyRoundedCorners);
        QTimer::singleShot(0, window, applyRoundedCorners);
    }
#endif

    // 让单实例管理器持有主窗口引用
    if (singleApp)
        singleApp->listen(window);

    // ---------------- 托盘图标（跨平台；移动端无托盘概念，预览模式跳过） ----------------
    if (!mobileMode)
    {
        QIcon trayIcon(QStringLiteral(":/image/tray_icon_mac.png"));
        if (trayIcon.isNull())
            trayIcon = QIcon::fromTheme(QStringLiteral("application-exit"));

        // 堆上创建：生命周期到进程结束，与原栈对象等效（QML 持有引用不悬空）
        auto *trayHandler = new TrayHandler(window, &app, trayIcon, nullptr);

        // 将 trayHandler 暴露给 QML（用于发送系统通知）
        engine.rootContext()->setContextProperty("trayHandler", trayHandler);
    }

    // 退出时保存播放状态
    QObject::connect(
        &app, &QApplication::aboutToQuit, &playlistmanager,
        [&playlistmanager]() { playlistmanager.savePlaylistToCache(); }
    );

    // 恢复上次播放状态（延迟执行，等 QML 加载完成）
    QTimer::singleShot(500, &playlistmanager, [&playlistmanager]() { playlistmanager.restoreLastPlayback(); });

    return app.exec();
}

#include "main.moc"
