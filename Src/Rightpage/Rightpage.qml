pragma ComponentBehavior: Bound
import QtQuick 2.15
import "../BasicConfig"

Rectangle {
    id: rightPage
    property alias rightTopPage: righttoppage

    // 导航栈：记录页面历史，最后一个是当前页面
    property var navStack: []

    // 整窗统一渐变：本面板切片（面板根色在 main.qml 改为透明时生效）
    WindowTintGradient {
        baseColor: AppTheme.bgContent
        panelTopY: 0
    }

    RightTopPage {
        id: righttoppage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 60
        canGoBack: navStack.length > 0
        onGoBack: rightPage.goBack()
    }

    // 主页：始终保留
    Loader {
        id: homePageLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: righttoppage.bottom
        anchors.bottom: parent.bottom
        source: "qrc:/Src/ComponentPage/HomePage.qml"
        visible: currentOverlayUrl === ""
    }

    // 子页面 Loader 池：每个 URL 一个 Loader，切换时只隐藏不销毁
    property var pageLoaders: ({})
    property string currentOverlayUrl: ""

    Component {
        id: pageLoaderComponent
        Loader {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: righttoppage.bottom
            anchors.bottom: parent.bottom
            z: 1
            opacity: 0
            visible: false

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            onLoaded: {
                opacity = 1
                console.log("[Rightpage] loader loaded:", source)
            }
            onOpacityChanged: {
                if (opacity === 0 && !activeOverlay) {
                    visible = false;
                }
            }
            property bool activeOverlay: false

            // 调试：Loader 加载状态（1=Loading 2=Ready 3=Error）
            onStatusChanged: {
                console.log("[Rightpage] loader status:", status, "url:", source)
                if (status === Loader.Error)
                    console.log("[Rightpage] loader ERROR:", source, "->", lastError ? lastError.toString() : "unknown")
            }
        }
    }

    // 内部：显示页面（不操作导航栈）
    function showOverlay(url) {
        if (currentOverlayUrl !== "" && pageLoaders[currentOverlayUrl]) {
            pageLoaders[currentOverlayUrl].activeOverlay = false;
            pageLoaders[currentOverlayUrl].opacity = 0;
        }

        if (!pageLoaders[url]) {
            var loader = pageLoaderComponent.createObject(rightPage, { "source": url });
            pageLoaders[url] = loader;
        }

        var target = pageLoaders[url];
        target.activeOverlay = true;
        target.visible = true;
        if (target.item) {
            target.opacity = 1;
        }
        currentOverlayUrl = url;

        // 切到非渐变页时关闭渐变（回落到播放歌曲色），渐变页（歌单/专辑/歌手/搜索/每日推荐）自行控制
        var fileName = url.split('/').pop().split('.')[0];
        if (fileName === "HomePage" || fileName === "RankPage" ||
            fileName === "musictogether" || fileName === "HistoryPage") {
            BasicConfig.playlistPageActive = false;
        }
    }

    function hideOverlay() {
        if (currentOverlayUrl !== "" && pageLoaders[currentOverlayUrl]) {
            pageLoaders[currentOverlayUrl].activeOverlay = false;
            pageLoaders[currentOverlayUrl].opacity = 0;
        }
        currentOverlayUrl = "";
        // 回首页：没有详情页显示，关闭页面渐变（详情页隐藏时不再自行关闭）
        BasicConfig.playlistPageActive = false;
    }

    // 导航：更新栈 + 显示页面（用新数组赋值确保绑定更新）
    function navigateTo(url) {
        var current = navStack.length > 0 ? navStack[navStack.length - 1] : "";
        if (url === current) return;

        navStack = [...navStack, url];

        BasicConfig.previousPageUrl = current !== "" ? current : homePageLoader.source.toString();

        if (url === "") {
            hideOverlay();
        } else {
            showOverlay(url);
        }
    }

    function goBack() {
        if (navStack.length === 0) return;

        navStack = navStack.slice(0, -1);

        var target = navStack.length > 0 ? navStack[navStack.length - 1] : "";
        BasicConfig.previousPageUrl = target !== "" ? target : homePageLoader.source.toString();

        if (target === "") {
            hideOverlay();
            // 回到首页，左栏导航高亮同步到"云音乐精选"
            BasicConfig.indexChange(0);
        } else {
            showOverlay(target);
        }
    }

    Connections {
        target: BasicConfig

        function onPushPage(url) {
            let fileName = url.split('/').pop().split('.')[0];
            if (fileName === "HomePage") {
                navigateTo("");
            } else {
                navigateTo(url);
            }
        }

        function onPushSearchSongPage(url) {
            navigateTo(url);
            BasicConfig.searchKeywordChange();
        }
    }
}
