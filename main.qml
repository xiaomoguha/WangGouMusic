import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls
import "./Src/BasicConfig"
import "./Src/Leftpage"
import "./Src/Rightpage"
import "./Src/Bottompage"
import "./Src/PlayingPage"
import "./Src/ToolWindow"
import "./Src/ComponentPage" as ComponentPage

ApplicationWindow {
    id: root
    objectName: "mainWindow"
    width: 1057
    height: 752
    minimumWidth: 960
    minimumHeight: 680
    visible: false  // 延迟到 Component.onCompleted 计算居中后再显示，避免 (0,0) 闪烁
    title: qsTr("WYYMUSIC")
    color: "transparent"
    // mac 由 QWindowKit (main.cpp) 接管窗口：真原生 traffic lights + 内容铺满标题栏下方（无带）；
    // 其他平台保持无边框 + 自定义按钮。
    flags: Qt.platform.os === "osx" ? Qt.Window : (Qt.FramelessWindowHint | Qt.Window)
    NoteWindow {
        id: loadingToast
        Connections {
            target: websocket  // 指定监听哪个C++对象
            function onConnectionStateChanged(connectstate) {
                if (connectstate === 2) {
                    loadingToast.showSuccess("连接成功啦!", 1000);
                } else if (connectstate === 1) {
                    loadingToast.showLoading("正在连接websocket服务器....");
                }
            }
            function onConnectFail() {
                loadingToast.showError("websocket 连接失败");
            }
        }
        Connections {
            target: BasicConfig
            function onNoticeError(errormessages) {
                loadingToast.showError(errormessages);
            }
            function onNoticeSuccess(messages) {
                loadingToast.showSuccess(messages, 2000);
            }
        }
        Connections {
            target: playlistCollection
            function onOperationFinished(success, message) {
                if (success) {
                    loadingToast.showSuccess(message, 2000);
                    // 加歌/删歌后刷新「我喜欢」hash 集合（红心状态）
                    playlistCollection.refreshFavoriteHashes();
                } else {
                    loadingToast.showError(message);
                }
            }
        }
        Connections {
            target: websocket
            function onServerNotice(message, mode) {
                if (mode === "loading") {
                    loadingToast.showLoading(message);
                } else if (mode === "error") {
                    loadingToast.showError(message);
                } else {
                    loadingToast.showSuccess(message, 1500);
                }
            }
        }
    }

    // 当前是否展开歌词
    property bool lyricsOpened: false

    // 启动后延迟拉取热搜与推荐数据，让首屏先渲染完
    Timer {
        id: startupFetchTimer
        interval: 250
        running: true
        repeat: false
        onTriggered: {
            //获取热搜数据
            if (hostSearch)
                hostSearch.fetchhostserachData("https://api.special520.com/search/hot")
            //启动时加载推荐数据（仅首次，后续由 C++ 缓存）
            if (recommendation) {
                if (recommendation.topSongsQml.length === 0)
                    recommendation.fetchTopSongs()
                if (recommendation.topPlaylistsQml.length === 0)
                    recommendation.fetchTopPlaylists()
            }
        }
    }

    // 窗口启动时计算居中位置
    Component.onCompleted: {
        root.x = (Screen.width - root.width) / 2;
        root.y = (Screen.height - root.height) / 2;
        if (Qt.platform.os === "osx") {
            // ApplicationWindow 在 mac 上会按标题栏高度把 contentItem 下移 ~32px（顶部白带根源）。
            // 仅 mac 清零 padding 让内容回到 y=0；其他平台一律不动，保证零影响。
            root.topPadding = 0
            root.bottomPadding = 0
            root.leftPadding = 0
            root.rightPadding = 0
        } else {
            // 非 mac 直接显示；mac 由 main.cpp 配置完原生窗口后再 show（避免闪烁）
            root.visible = true
        }
    }
    // 注意：关闭事件已被 TrayHandler 拦截，这里不会执行
    // 真正退出时由 TrayHandler 处理关闭桌面歌词
    onClosing: {
        close.accepted = false;  // 阻止默认关闭行为
    }

    // ── 启动时刷新用户 token ──
    Connections {
        target: userManager
        function onTokenRefreshResult(success) {
            // 仅真过期（C++ 已清空登录态）才弹登录页；
            // 网络错误会保留登录态（token 可能还有效），不弹窗避免误登出
            if (!success && userManager && !userManager.isLoggedIn) {
                loginPopup.open()
            }
        }
    }
    Timer {
        id: tokenRefreshTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            if (userManager && userManager.isLoggedIn) {
                userManager.refreshToken()
                // 登录态就绪后预取「我喜欢」hash 集合（红心状态）
                playlistCollection.refreshFavoriteHashes()
            }
        }
    }
    MouseArea {
        id: windowDragArea
        anchors.fill: parent
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        property real dragThreshold: 5 // 判断是否真的拖动的最小距离
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            dragged = false;
        }
        onPositionChanged: mouse => {
            // 判断是否拖动超过阈值
            if (!dragged && (Math.abs(mouse.x - pressX) > dragThreshold || Math.abs(mouse.y - pressY) > dragThreshold)) {
                dragged = true;
                if (root.visibility === Window.Maximized) {
                    root.showNormal();
                    leftrect.radius = 20;
                    rightrect.radius = 20;
                    bottomrect.radius = 20;
                }
                root.startSystemMove();
            }
        }
        onReleased: mouse => {
            if (!dragged) {
                // 没有拖动就是点击
                BasicConfig.bkanAreaClicked();
            }
        }
    }
    // 内容容器：直接铺满窗口（窗口投影方案在本机 Qt6.10.1 下渲染不稳定，已移除）。
    // 播放详情页打开时禁用底层交互：否则点击会沿 z 序穿透到下面页面的 TapHandler
    // （曾导致点「展开回复」误触底层歌曲卡片，直接切歌）
    Item {
        id: windowShell
        anchors.fill: parent
        enabled: !root.lyricsOpened
    Leftpage {
        id: leftrect
        width: 200
        anchors.top: parent.top
        anchors.bottom: bottomrect.top
        // 整窗渐变激活时面板色转透明，露出内嵌的 WindowTintGradient 切片
        color: BasicConfig.playlistCoverColor !== "" ? "transparent" : AppTheme.bgSidebar
        radius: 20
        clip: true
        // 盖住其他角
        Rectangle {
            // 右上角遮挡（在窗口顶，随渐变混入主色保持一致）
            // z:-1 垫到内容之下：只补圆角接缝，不遮挡按钮 hover 遮罩
            anchors.top: parent.top
            anchors.right: parent.right
            width: 20
            height: 20
            z: -1
            color: BasicConfig.mixTint(BasicConfig.playlistCoverColor, AppTheme.bgSidebar, 0.5)
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 左下角遮挡
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgSidebar
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 右下角遮挡
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgSidebar
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animThemeTransition
            }
        }
    }
    Rightpage {
        id: rightrect
        anchors.left: leftrect.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: bottomrect.top
        color: BasicConfig.playlistCoverColor !== "" ? "transparent" : AppTheme.bgContent
        radius: 20
        clip: true
        Rectangle {
            // 左下角遮挡
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgContent
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 右下角遮挡
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgContent
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 左上角遮挡（在窗口顶，随渐变混入主色保持一致）
            // z:-1 垫到内容之下：只补圆角接缝，不遮挡后退按钮 hover 遮罩
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
            z: -1
            color: BasicConfig.mixTint(BasicConfig.playlistCoverColor, AppTheme.bgContent, 0.5)
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animThemeTransition
            }
        }
    }
    Bottompage {
        id: bottomrect
        height: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: BasicConfig.playlistCoverColor !== "" ? "transparent" : AppTheme.bgBottomBar
        radius: 20
        clip: true
        Rectangle {
            // 左上角角遮挡
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgBottomBar
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 右上角遮挡
            anchors.top: parent.top
            anchors.right: parent.right
            width: 20
            height: 20
            z: -1
            color: AppTheme.bgBottomBar
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animThemeTransition
            }
        }
    }
    }
    // 整窗统一渐变：三个面板（Leftpage/Rightpage/Bottompage）各自内嵌 WindowTintGradient
    // 切片，把封面主色按全局纵向位置混入面板底色（纯不透明渐变，内容不糊）。
    // 有渐变时面板根色转透明让切片露出来；无渐变时面板恢复主题底色。
    // 窗口高度同步给 BasicConfig，供切片换算「整窗 50% 淡出」的位置。
    Binding {
        target: BasicConfig
        property: "windowHeight"
        value: root.height
    }
    // 非歌单页时的渐变来源：正在播放（有歌且未暂停）→ 用当前歌曲封面主色。
    // dominantColor 由 PlaylistManager 内部提取器维护（播放页主题同源）。
    Binding {
        target: BasicConfig
        property: "playingActive"
        value: playlistmanager && playlistmanager.currentSonghash !== "" && !playlistmanager.isPaused
    }
    Binding {
        target: BasicConfig
        property: "playingCoverColor"
        value: playlistmanager ? playlistmanager.dominantColor : ""
    }
    // 使用 Loader 延迟加载歌词页，减少启动内存
    Loader {
        id: lyricsPageLoader
        // 铺满整个窗口，与主页面（windowShell）大小、位置完全一致（窗口投影已移除）
        x: 0
        width: root.width
        height: root.height
        y: root.lyricsOpened ? 0 : root.height
        z: 10
        // 首次打开后保持活跃
        active: root.lyricsOpened || lyricsPageLoader.item !== null
        source: "qrc:/Src/PlayingPage/PlayingPage.qml"

        Behavior on y {
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
            }
        }
    }
    // 暴露歌词页给外部访问
    property alias lyricsPage: lyricsPageLoader.item

    // 歌曲添加成功提示（放在最后确保在最上层）
    SongAddedToast {
        id: songAddedToast
        anchors.centerIn: parent
        Connections {
            target: BasicConfig
            function onSongAdded(songname) {
                songAddedToast.show(songname);
            }
        }
    }

    // 一起听播放列表切换提示
    Connections {
        target: playlistmanager
        function onPlaylist_typeChanged() {
            if (!playlistmanager) return
            if (playlistmanager.type === 1) {
                songAddedToast.show("已切换到一起听播放列表")
            } else {
                songAddedToast.show("已切回本地播放列表")
            }
        }
    }

    // ── 登录弹窗 ──
    ComponentPage.LoginPage {
        id: loginPopup
    }

    // ── 自动更新弹窗 ──
    ComponentPage.UpdateDialog {
        id: updateDialog
        updater: appUpdater
    }

    // 是否为自动检查（启动时静默检查，无更新不弹窗）
    property bool autoCheckUpdate: true

    // 启动后延迟检查更新
    Timer {
        id: checkUpdateTimer
        interval: 5000
        running: true
        repeat: false
        onTriggered: {
            if (appUpdater) {
                root.autoCheckUpdate = true;
                appUpdater.checkForUpdate();
            }
        }
    }

    Connections {
        target: appUpdater
        function onCheckFinished(hasUpdate) {
            // 自动检查：仅有更新时弹窗；手动检查：始终弹窗
            if (hasUpdate || !root.autoCheckUpdate) {
                updateDialog.hasUpdate = hasUpdate;
                updateDialog.state_ = "idle";
                updateDialog.open();
            }
        }
    }

    // MV 播放窗口：打开时暂停主播放器，关闭后按原状态恢复（playstop 是 toggle）
    ComponentPage.MvWindow {
        id: mvWindow
        transientParent: root
    }

    property bool mvPausedOnOpen: false
    Connections {
        target: BasicConfig
        function onRequestMvPlay(songhash, title) {
            mvPausedOnOpen = playlistmanager && !playlistmanager.isPaused
            if (mvPausedOnOpen)
                playlistmanager.playstop()
            mvWindow.mvHash = songhash
            mvWindow.mvTitle = title
            mvWindow.show()
        }
    }
    Connections {
        target: mvWindow
        function onVisibleChanged() {
            if (!mvWindow.visible && mvPausedOnOpen) {
                mvPausedOnOpen = false
                if (playlistmanager)
                    playlistmanager.playstop()
            }
        }
    }
}
