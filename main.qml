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
    visible: false  // 延迟到 Component.onCompleted 定位（恢复上次位置或居中）后再显示，避免 (0,0) 闪烁
    title: qsTr("WYYMUSIC")
    color: "transparent"
    // mac 由 QWindowKit (main.cpp) 接管窗口：真原生 traffic lights + 内容铺满标题栏下方（无带）；
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

    // 窗口真实可见（非最小化且未隐藏）：常驻动画的统一开关。
    readonly property bool appActive: visible && visibility !== Window.Minimized

    // 窗口拖动/移动中：暂停星空等装饰动画，拖动结束后 180ms 自动恢复
    property bool windowMoving: false
    function markWindowMoving() {
        if (!visible || visibility === Window.Minimized)
            return
        windowMoving = true;
        moveEndTimer.restart();
    }
    Timer {
        id: moveEndTimer
        interval: 180
        onTriggered: root.windowMoving = false
    }

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

    // 位置落盘：拖动过程中 x/y 每帧都在变，不逐次写配置，停手 600ms 后写一次。
    Timer {
        id: windowPosSaveTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (!windowState || root.visibility !== Window.Windowed)
                return;
            windowState.savePosition(root.x, root.y);
        }
    }
    onXChanged: { windowPosSaveTimer.restart(); root.markWindowMoving(); }
    onYChanged: { windowPosSaveTimer.restart(); root.markWindowMoving(); }

    // 窗口启动时定位：有上次记录且那块屏幕还在就恢复原位，否则按默认居中。
    Component.onCompleted: {
        if (windowState && windowState.hasSavedPosition && windowState.isSavedPositionOnScreen(root.width, root.height)) {
            root.x = windowState.savedX;
            root.y = windowState.savedY;
        } else {
            root.x = (Screen.width - root.width) / 2;
            root.y = (Screen.height - root.height) / 2;
        }
        if (Qt.platform.os === "osx") {
            // ApplicationWindow 在 mac 上会按标题栏高度把 contentItem 下移 ~32px（顶部白带根源）。
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
            if (!success && userManager && !userManager.isLoggedIn) {
                loginPopup.open()
            }
        }
        // 使用中途被服务端踢下线（任何用户接口返回 20018）：清登录态后自动弹登录窗引导重登
        // （主动退出登录 manualLogout=true 不弹）
        property bool everLoggedIn: userManager ? userManager.isLoggedIn : false
        function onLoginStatusChanged() {
            if (userManager.isLoggedIn)
                everLoggedIn = true
            else if (everLoggedIn && !userManager.manualLogout && !loginPopup.visible)
                loginPopup.open()
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
    // ===================== 星空时间基准 =====================
    // 累加秒数供星点计算"生命"节奏（0.1s 精度足够，变化本就缓慢）；失焦/被遮挡时停走
    Timer {
        interval: 100
        repeat: true
        running: !BasicConfig.uiIdle
        onTriggered: BasicConfig.bgTime += 0.1
    }

    // ===================== 左栏 / 内容区 分隔线 =====================
    // 一条两端淡出的极淡竖线，标出这是两块界面
    Rectangle {
        x: 200
        width: 1
        anchors.top: parent.top
        anchors.bottom: bottomrect.top
        z: 500
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.12; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.88; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.0) }
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
    Item {
        id: windowShell
        anchors.fill: parent
        enabled: !root.lyricsOpened && !BasicConfig.modalInputLock
        // 播放详情页完全展开后整块隐藏：否则三个面板（含当前页全部节点/离屏 layer）
        visible: !root.lyricsOpened || lyricsSlideAnim.running
    Leftpage {
        id: leftrect
        width: 200
        anchors.top: parent.top
        anchors.bottom: bottomrect.top
        // 整窗渐变激活时面板色转透明，露出内嵌的 WindowTintGradient 切片
        // 左栏：底色/极光/封面主色三层都由 WindowTintGradient 负责，这里保持透明
        color: "transparent"
        radius: 20
        clip: true
        // 盖住其他角
        Rectangle {
            // 右上角遮挡（在窗口顶，随渐变混入主色保持一致）
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
        // 内容区：底色/极光/封面主色三层都由 WindowTintGradient 负责，这里保持透明
        color: "transparent"
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
        // 底部栏：底色/极光/封面主色三层都由 WindowTintGradient 负责，这里保持透明
        color: "transparent"
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
    Binding {
        target: BasicConfig
        property: "windowHeight"
        value: root.height
    }
    // 窗口宽度同步给 BasicConfig：背景切片按窗口尺寸取密度需要
    Binding {
        target: BasicConfig
        property: "windowWidth"
        value: root.width
    }
    // 窗口遮蔽状态（最小化或关闭到托盘）同步给 BasicConfig：一起听聊天通知的判断依据。
    Binding {
        target: BasicConfig
        property: "windowObscured"
        value: root.visibility === Window.Minimized || root.visibility === Window.Hidden || !root.visible
    }
    // 装饰性动画总闸：被遮蔽或应用失焦（用户切到别的 App）时停掉跑马灯等无限动画。
    // 拖动窗口期间也暂停，减少整窗重绘带来的卡顿。
    Binding {
        target: BasicConfig
        property: "uiIdle"
        value: BasicConfig.windowObscured || Qt.application.state !== Qt.ApplicationActive || root.windowMoving
    }
    // 同一把闸同步给 C++：失焦时停掉进度条 10fps 发射（桌面歌词 60Hz 定时器不受影响）
    Binding {
        target: playlistmanager
        property: "uiIdle"
        value: BasicConfig.uiIdle
    }
    // 主页不跟随播放歌曲取色：星空背景 + 主题色；取色只在播放详情页内使用
    // （歌单/专辑等沉浸页仍由 playlistPageActive 单独驱动）
    Binding {
        target: BasicConfig
        property: "playingActive"
        value: false
    }
    Binding {
        target: BasicConfig
        property: "playingCoverColor"
        value: ""
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

        // 收起滑动动画结束后整页 visible=false（不销毁）：从场景图摘除，
        // 页面内所有渲染/动画/绑定链路彻底停止（暂停语义而非销毁）
        visible: root.lyricsOpened || lyricsSlideAnim.running

        Behavior on y {
            NumberAnimation {
                id: lyricsSlideAnim
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
        function onRequestMvPlay(song) {
            mvPausedOnOpen = playlistmanager && !playlistmanager.isPaused
            if (mvPausedOnOpen)
                playlistmanager.playstop()
            mvWindow.mvHash = song.mvhash || ""
            mvWindow.mvTitle = song.title || "MV"
            mvWindow.mvSinger = song.singername || ""
            mvWindow.mvCover = song.cover || ""
            mvWindow.songHash = song.songhash || ""
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

    // 全局「添加到歌单」弹窗：歌曲行右键菜单/收藏入口统一调用
    AddToPlaylistPopup {
        id: addToPlaylistPopup
    }
    Connections {
        target: BasicConfig
        function onRequestAddToPlaylist(song) {
            addToPlaylistPopup.song = song
            addToPlaylistPopup.open()
        }
    }

    // 全局歌曲右键菜单：所有歌曲行共用一套，避免每个 delegate 实例化整套菜单
    SongContextMenu {
        id: globalSongContextMenu
    }
    Connections {
        target: BasicConfig
        function onRequestSongContextMenu(song, options) {
            globalSongContextMenu.openFor(null, song, 0, 0, options || ({}))
        }
    }

}
