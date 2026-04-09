pragma ComponentBehavior: Bound
import QtQuick 2.15
import "../BasicConfig"

Rectangle {
    property alias rightTopPage: righttoppage
    RightTopPage {
        id: righttoppage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 60
    }

    // 使用 Loader 替代 StackView：更轻量，无需维护导航栈，内存占用恒定
    Loader {
        id: pageLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: righttoppage.bottom
        anchors.bottom: parent.bottom
        source: "qrc:/Src/ComponentPage/HomePage.qml"

        property string _pendingUrl: ""

        // 页面切换淡入过渡
        opacity: 1
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Connections {
            target: BasicConfig
            function urlToObjectName(url) {
                let fileName = url.split('/').pop();
                return fileName.split('.')[0];
            }
            function onPushPage(url) {
                if (!pageLoader.item) {
                    pageLoader.source = url;
                    return;
                }
                let currentName = pageLoader.item.objectName;
                let pushName = urlToObjectName(url);
                if (currentName === pushName)
                    return;
                // 淡出 → 切换 → 淡入
                pageLoader._pendingUrl = url;
                pageLoader.opacity = 0;
            }
            function onPushsearchsongPage(url) {
                if (!pageLoader.item) {
                    pageLoader.source = url;
                    BasicConfig.searchKeywordchange();
                    return;
                }
                let currentName = pageLoader.item.objectName;
                let pushName = urlToObjectName(url);
                if (currentName === pushName) {
                    BasicConfig.searchKeywordchange();
                    return;
                }
                pageLoader.source = url;
                BasicConfig.searchKeywordchange();
            }
        }

        // 监听 opacity 变化：淡出完成后切换页面
        onOpacityChanged: {
            if (opacity === 0 && _pendingUrl !== "") {
                source = _pendingUrl;
                _pendingUrl = "";
            }
        }
        // 页面加载完成后淡入
        onLoaded: opacity = 1
    }
}
