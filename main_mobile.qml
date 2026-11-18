// 版本无关导入（不带 2.15）：SafeArea 是 Qt 6.9 新增类型，
// 版本化导入会把它锁在旧版本清单之外导致 "not defined"
import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import "./Src/BasicConfig"
import "./Src_Mobile"
import "./Src_Mobile/pages"

// 移动端主窗口（Android/iOS 真机 + 桌面 --mobile 预览共用入口）。
//
// 结构：
//   ApplicationWindow
//   ├─ StackView（4 个 Tab 页；后续详情页在此压栈）
//   ├─ bottomChrome = MiniPlayer + MTabBar（常驻底部）
//   └─ NowPlayingPage（全屏播放页，上滑展开/下拉收起，z 最高）
//
// 沉浸式：背景色铺满全屏（root.color），内容通过 SafeArea.margins
// 避让刘海/手势条 —— 安全区数值统一注入 MTheme，页面只读 MTheme.safeTop 等。
ApplicationWindow
{
    id: root

    visible: true
    color: MTheme.bgPage
    title: qsTr("网狗音乐")

    readonly property bool onDevice: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // ===== 沉浸式（状态栏/手势条背景由应用绘制） =====
    // 真机：扩展客户区到系统栏后方（Android 15+ 默认强制 edge-to-edge，旧版本靠此标志）；
    // 桌面预览：普通窗口保持系统标题栏
    flags: onDevice ? (Qt.Window | Qt.ExpandedClientAreaHint) : Qt.Window
    // 关闭 ApplicationWindow 的自动安全区内缩：由本文件手动统一控制，
    // 这样 TabBar 背景可以铺到手势条下方、NowPlayingPage 背景铺到状态栏下方
    topPadding: onDevice ? 0 : undefined
    bottomPadding: onDevice ? 0 : undefined
    leftPadding: onDevice ? 0 : undefined
    rightPadding: onDevice ? 0 : undefined

    // ===== 全窗不透明底（页面根节点多为透明 Item；此层保证窗口始终有底色，
    //       也让 tour 自截帧不会出现透明底） =====
    Rectangle {
        anchors.fill: parent
        color: MTheme.bgPage
        z: -1
    }

    // ===== 安全区探针 + 注入（全工程唯一来源） =====
    // SafeArea 附加属性只能挂在 Item 上（挂 Window 取不到值）。
    // 探针铺满全窗、内部不做任何布局，因此它报告的就是系统级避让值
    // （刘海状态栏高度/手势条高度）；桌面预览恒为 0。
    Item {
        id: safeProbe
        anchors.fill: parent
    }
    Binding { target: MTheme; property: "safeTop";    value: safeProbe.SafeArea.margins.top }
    Binding { target: MTheme; property: "safeBottom"; value: safeProbe.SafeArea.margins.bottom }
    Binding { target: MTheme; property: "safeLeft";   value: safeProbe.SafeArea.margins.left }
    Binding { target: MTheme; property: "safeRight";  value: safeProbe.SafeArea.margins.right }

    // 桌面预览：固定 iPhone 逻辑分辨率窗口；真机：不设宽高即全屏
    width: onDevice ? undefined : 400
    height: onDevice ? undefined : Math.min(860, Screen.desktopAvailableHeight - 80)
    minimumWidth: onDevice ? 0 : 400
    maximumWidth: onDevice ? 16777215 : 400
    minimumHeight: onDevice ? 0 : height
    maximumHeight: onDevice ? 16777215 : height
    x: onDevice ? 0 : (Screen.width - width) / 2
    y: onDevice ? 0 : (Screen.height - height) / 2

    // ===== 安全区注入（旧实现，已由探针方案取代） =====

    // ===== 星空时间基准（与桌面 main.qml 同款；失焦/最小化即停） =====
    readonly property bool appActive: visible && visibility !== Window.Minimized
    onAppActiveChanged: BasicConfig.uiIdle = !appActive

    Timer {
        interval: 100
        repeat: true
        running: !BasicConfig.uiIdle
        onTriggered: BasicConfig.bgTime += 0.1
    }

    // 启动后刷新 token + 预取红心集合（与桌面 main.qml 同款策略）
    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            if (userManager && userManager.isLoggedIn) {
                userManager.refreshToken()
                playlistCollection.refreshFavoriteHashes()
            }
        }
    }

    // ===== Tab 页面（三页常驻缓存：切换不销毁不重载，秒回；首页已并入音乐馆） =====
    property int currentTab: 0

    Component { id: browseComp;   BrowsePage {} }
    Component { id: togetherComp; TogetherPage {} }
    Component { id: mineComp;     MinePage {} }

    // ===== 导航钩子注入（页面统一通过 MTheme.pushPage / MTheme.popPage 导航） =====
    Component.onCompleted: {
        MTheme.pushPage = function(url, props) {
            if (props)
                detailStack.push(url, props)
            else
                detailStack.push(url)
        }
        MTheme.popPage = function() {
            // pop() 不会弹出栈中最初推入的那一页：只剩初页时改用 clear()
            if (detailStack.depth > 1)
                detailStack.pop()
            else if (detailStack.depth === 1)
                detailStack.clear(StackView.Immediate)
        }
        MTheme.toast = function(msg) {
            if (!msg)
                return
            toastText.text = msg
            toastAnim.restart()
        }
    }

    // ===== 轻提示（MTheme.toast 注入目标；一起听点播回执等也走这里） =====
    Rectangle {
        id: toast

        z: 200
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 140
        width: toastText.implicitWidth + 36
        height: 38
        radius: 19
        color: "#E6333333"
        opacity: 0

        Text {
            id: toastText

            anchors.centerIn: parent
            color: "#FFFFFF"
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontCaption + 1
        }

        SequentialAnimation on opacity {
            id: toastAnim

            NumberAnimation { to: 1; duration: 150 }
            PauseAnimation { duration: 1800 }
            NumberAnimation { to: 0; duration: 250 }
        }
    }

    // 一起听服务端通知（点播回执：正在添加/已添加 n 首...）与连接错误 → toast
    Connections {
        target: websocket

        function onServerNotice(message, mode) {
            MTheme.toast(message)
        }

        function onErrorOccurred(error) {
            MTheme.toast(qsTr("一起听连接异常"))
        }
    }

    // Android 物理返回键：先退详情栈，栈底才退出应用（初页需 clear()，见 popPage 注释）
    onClosing: function(close) {
        if (detailStack.depth > 1) {
            close.accepted = false
            detailStack.pop()
        } else if (detailStack.depth === 1) {
            close.accepted = false
            detailStack.clear(StackView.Immediate)
        }
    }

    function switchTab(index)
    {
        root.currentTab = index
        // 切 Tab 时清空详情栈（回该 Tab 根页）。
        // 注意：pop() 永远不会弹出最初推入的那一页（Qt 设计如此），
        // 只剩初页时 while+pop 会无限循环挂死 UI，必须用 clear()
        detailStack.clear(StackView.Immediate)
    }

    // ===== 自动巡览（--tour 参数开启；配合离屏窗口 + PrintWindow 抓帧，不占鼠标） =====
    readonly property bool tourMode: Qt.application.arguments.indexOf("--tour") >= 0
    property int tourStep: 0

    Timer {
        id: tourTimer

        interval: 2200
        running: root.tourMode
        repeat: true
        onTriggered: root.tourNext()
    }

    function tourNext()
    {
        // 先自截上一步执行后的稳定画面（grabWindow 同步整窗渲染，与窗口可见性无关；
        // 离屏窗口用 PrintWindow 会抓到 DWM 节流后的陈旧表面）
        if (tourStep > 0) {
            var n = tourStep - 1
            console.log("[tour] grab q_" + n + " begin (next step " + tourStep + ")")
            tourGrabber.grab(root, "D:/WangGouMusic/build/q_" + n + ".png")
            console.log("[tour] grab q_" + n + " ok")
        }
        var page = detailStack.currentItem
        var browse = browseLoader.item
        switch (tourStep) {
        case 0: // 音乐馆中部
            if (browse && browse.contentFlick) browse.contentFlick.contentY = 430
            break
        case 1: // 音乐馆底部（歌单发现列表）
            if (browse && browse.contentFlick) browse.contentFlick.contentY = Math.max(0, browse.contentFlick.contentHeight - browse.contentFlick.height)
            break
        case 2: // 再滚底部（此时歌单/新歌数据已加载，能拍到横滑新歌区）
            if (browse && browse.contentFlick) browse.contentFlick.contentY = Math.max(0, browse.contentFlick.contentHeight - browse.contentFlick.height)
            break
        case 3: // 每日推荐
            MTheme.pushPage("qrc:/Src_Mobile/pages/DailyRecommendPage.qml")
            break
        case 4: // 返回
            MTheme.popPage()
            break
        case 5: // 排行榜宫格
            MTheme.pushPage("qrc:/Src_Mobile/pages/RankPage.qml")
            break
        case 6: // 返回
            MTheme.popPage()
            break
        case 7: // 搜索页
            MTheme.pushPage("qrc:/Src_Mobile/pages/SearchPage.qml")
            break
        case 8: // 搜索结果
            if (page && page.doSearch) page.doSearch("周杰伦")
            break
        case 9: // 停留看结果
            break
        case 10: // 再停留（等结果封面下载完成）
            break
        case 11: // 返回
            MTheme.popPage()
            break
        case 12: // 一起听
            switchTab(1)
            break
        case 13: // 我的
            switchTab(2)
            break
        case 14: // 打开播放页
            nowPlaying.openPage()
            break
        case 15: // 歌词模式
            nowPlaying.lyricsMode = true
            break
        case 16: // 关闭播放页，巡览结束
            nowPlaying.lyricsMode = false
            nowPlaying.closePage()
            tourTimer.running = false
            break
        }
        console.log("[tour] step " + tourStep + " done")
        tourStep++
    }

    // ===== Tab 容器（三页常驻，可见性切换 + 淡入淡出过渡） =====
    Item {
        id: tabHolder

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // 内容整体避让：顶部安全区 + 底部常驻区（MiniPlayer/TabBar/手势条）
        anchors.topMargin: MTheme.safeTop
        anchors.bottomMargin: MTheme.safeBottom
                              + MTheme.tabBarHeight
                              + (miniPlayer.visible ? MTheme.miniPlayerHeight : 0)

        Loader {
            id: browseLoader

            anchors.fill: parent
            sourceComponent: browseComp
            opacity: root.currentTab === 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        Loader {
            id: togetherLoader

            anchors.fill: parent
            sourceComponent: togetherComp
            opacity: root.currentTab === 1 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        Loader {
            id: mineLoader

            anchors.fill: parent
            sourceComponent: mineComp
            opacity: root.currentTab === 2 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // ===== 详情页底层背景（详情页根节点是透明 Item，须有不透明底衬，
    //       否则常驻 Tab 页会从下面透出来形成叠影；空栈时隐藏露出 Tab 页） =====
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomChrome.top
        color: MTheme.bgPage
        visible: detailStack.depth > 0
    }

    // ===== 详情页栈（推入/弹出带过渡动画；空栈时不拦截任何输入） =====
    StackView {
        id: detailStack

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: MTheme.safeTop
        anchors.bottomMargin: MTheme.safeBottom
                              + MTheme.tabBarHeight
                              + (miniPlayer.visible ? MTheme.miniPlayerHeight : 0)
    }

    // ===== 底部常驻区 =====
    Item {
        id: bottomChrome

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: MTheme.tabBarHeight + (miniPlayer.visible ? MTheme.miniPlayerHeight : 0)
        z: 10

        MiniPlayer {
            id: miniPlayer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: tabBar.top
            onOpenNowPlaying: nowPlaying.openPage()
        }

        MTabBar {
            id: tabBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: MTheme.safeBottom
            currentIndex: root.currentTab        // 高亮跟随页面（否则切 Tab 后高亮不动）
            onTabSelected: (index) => root.switchTab(index)
        }
    }

    // ===== 全屏播放页 =====
    // 注意：不能用 anchors（锚点会接管 y，内部"下滑收起"定位就失效了）
    NowPlayingPage {
        id: nowPlaying

        x: 0
        z: 100
    }
}
