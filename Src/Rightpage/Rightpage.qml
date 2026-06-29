pragma ComponentBehavior: Bound
import QtQuick 2.15
import "../BasicConfig"

Rectangle {
    id: rightPage
    property alias rightTopPage: righttoppage

    // 导航栈：记录页面历史，最后一个是当前页面
    property var navStack: []

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
            onLoaded: opacity = 1
            onOpacityChanged: {
                if (opacity === 0 && !activeOverlay) {
                    visible = false;
                }
            }
            property bool activeOverlay: false
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
    }

    function hideOverlay() {
        if (currentOverlayUrl !== "" && pageLoaders[currentOverlayUrl]) {
            pageLoaders[currentOverlayUrl].activeOverlay = false;
            pageLoaders[currentOverlayUrl].opacity = 0;
        }
        currentOverlayUrl = "";
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
            BasicConfig.indexchange(0);
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

        function onPushsearchsongPage(url) {
            navigateTo(url);
            BasicConfig.searchKeywordchange();
        }
    }
}
