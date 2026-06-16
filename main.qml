import QtQuick 2.15
import QtQuick.Window 2.15
import "./Src/BasicConfig"
import "./Src/Leftpage"
import "./Src/Rightpage"
import "./Src/Bottompage"
import "./Src/PlayingPage"
import "./Src/ToolWindow"
import "./Src/ComponentPage" as ComponentPage
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

ApplicationWindow {
    id: root
    objectName: "mainWindow"
    width: 1057
    height: 752
    minimumWidth: 960
    minimumHeight: 680
    visible: true
    title: qsTr("WYYMUSIC")
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window
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
            function onNotice_error(errormessages) {
                loadingToast.showError(errormessages);
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

    // 窗口启动时计算居中位置
    Component.onCompleted: {
        root.x = (Screen.width - root.width) / 2;
        root.y = (Screen.height - root.height) / 2;
        //获取热搜数据
        if (hostSearch) {
            hostSearch.fetchhostserachData("https://xjt-togethertracks.top/api/search/hot");
        }
        //启动时加载推荐数据（仅首次，后续由 C++ 缓存）
        if (recommendation) {
            if (recommendation.topSongsQml.length === 0)
                recommendation.fetchTopSongs()
            if (recommendation.topPlaylistsQml.length === 0)
                recommendation.fetchTopPlaylists()
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
            if (!success) {
                // token 过期或无效，弹出登录页
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
            }
        }
    }
    MouseArea {
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
    // 内容容器：四周留出投影空间；最大化时自动贴边、无阴影
    Item {
        id: windowShell
        anchors.fill: parent
        anchors.margins: root.visibility === Window.Maximized ? 0 : 10

        // 阴影源：与窗口同形状的圆角矩形（不可见，仅用于生成投影）
        Rectangle {
            id: shadowSource
            anchors.fill: parent
            radius: root.visibility === Window.Maximized ? 0 : 20
            color: "#000000"
            visible: false
        }
        DropShadow {
            anchors.fill: parent
            source: shadowSource
            horizontalOffset: 0
            verticalOffset: 4
            radius: 16
            samples: 33
            color: AppTheme.isDark ? "#A0000000" : "#26000000"
            transparentBorder: true
        }
    Leftpage {
        id: leftrect
        width: 200
        anchors.top: parent.top
        anchors.bottom: bottomrect.top
        color: AppTheme.bgSidebar
        radius: 20
        clip: true
        // 盖住其他角
        Rectangle {
            // 右上角遮挡
            anchors.top: parent.top
            anchors.right: parent.right
            width: 20
            height: 20
            color: AppTheme.bgSidebar
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
        color: AppTheme.bgContent
        radius: 20
        clip: true
        Rectangle {
            // 左下角遮挡
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 20
            height: 20
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
            color: AppTheme.bgContent
            Behavior on color {
                ColorAnimation {
                    duration: AppTheme.animThemeTransition
                }
            }
        }
        Rectangle {
            // 左上角角遮挡
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
            color: AppTheme.bgContent
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
        color: AppTheme.bgBottomBar
        radius: 20
        clip: true
        Rectangle {
            // 左上角角遮挡
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
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
    // 使用 Loader 延迟加载歌词页，减少启动内存
    Loader {
        id: lyricsPageLoader
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
}
