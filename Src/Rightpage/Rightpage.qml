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

    // 主页：始终保留，不销毁，避免图片重新加载
    Loader {
        id: homePageLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: righttoppage.bottom
        anchors.bottom: parent.bottom
        source: "qrc:/Src/ComponentPage/HomePage.qml"
        visible: !overlayLoader.active || overlayLoader.opacity === 0
    }

    // 其他页面：叠加在主页之上
    Loader {
        id: overlayLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: righttoppage.bottom
        anchors.bottom: parent.bottom
        z: 1
        opacity: 0
        active: false

        property string _pendingUrl: ""

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Connections {
            target: BasicConfig
            function urlToObjectName(url) {
                return url.split('/').pop().split('.')[0];
            }
            function onPushPage(url) {
                let fileName = urlToObjectName(url);
                if (fileName === "HomePage") {
                    // 返回主页：淡出覆盖层
                    BasicConfig.previousPageUrl = homePageLoader.source.toString();
                    overlayLoader._pendingUrl = "";
                    overlayLoader.opacity = 0;
                } else if (overlayLoader.active && overlayLoader.item) {
                    let currentName = overlayLoader.item.objectName;
                    if (currentName === fileName) return;
                    // 非主页之间切换
                    BasicConfig.previousPageUrl = overlayLoader.source.toString();
                    overlayLoader._pendingUrl = url;
                    overlayLoader.opacity = 0;
                } else {
                    // 从主页进入子页面
                    BasicConfig.previousPageUrl = homePageLoader.source.toString();
                    overlayLoader._pendingUrl = "";
                    overlayLoader.source = url;
                    overlayLoader.active = true;
                }
            }
            function onPushsearchsongPage(url) {
                BasicConfig.previousPageUrl = overlayLoader.active
                    ? overlayLoader.source.toString()
                    : homePageLoader.source.toString();
                overlayLoader._pendingUrl = "";
                overlayLoader.source = url;
                overlayLoader.active = true;
                BasicConfig.searchKeywordchange();
            }
        }

        // 淡出完成后：切换页面或卸载
        onOpacityChanged: {
            if (opacity === 0) {
                if (_pendingUrl !== "") {
                    source = _pendingUrl;
                    _pendingUrl = "";
                } else {
                    active = false;
                    source = "";
                }
            }
        }
        // 页面加载完成后淡入
        onLoaded: opacity = 1
    }
}
