import QtQuick 2.15
import QtQuick.Window 2.15
import "./Src/BasicConfig"
import "./Src/Leftpage"
import "./Src/Rightpage"
import "./Src/Bottompage"
import "./Src/PlayingPage"
import "./Src/ToolWindow"
import QtQuick.Controls

ApplicationWindow {
    id: root
    objectName: "mainWindow"
    width: 1057
    height: 752
    visible: true
    title: qsTr("WYYMUSIC")
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window
    NoteWindow{
        id: loadingToast
        Connections {
            target: websocket  // 指定监听哪个C++对象
            function onConnectionStateChanged(connectstate){
                if(connectstate === 2)
                {
                    loadingToast.showSuccess("连接成功啦!",1000)
                }
                else if(connectstate === 1)
                {
                    loadingToast.showLoading("正在连接websocket服务器....")
                }
            }
            function onConnectFail(){
                loadingToast.showError("websocket 连接失败");
            }
        }
        Connections{
            target: BasicConfig
            function onNotice_error(errormessages){
                loadingToast.showError(errormessages)
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
        hostSearch.fetchhostserachData("https://xjt-togethertracks.top/api/search/hot");
        //获取推荐歌曲数据
        for (let i = 0; i < 7; i++) {
            recommendation.getdatabygetdatarange(i);
        }
    }
    onClosing: {
        if (Qt.platform.os === "windows")
            desktopLyricsWindow.close();
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
                    root.y = mouse.y - 20;
                    leftrect.radius = 20;
                    rightrect.radius = 20;
                    bottomrect.radius = 20;
                }
                Qt.callLater(() => {
                    root.startSystemMove();
                });
            }
        }
        onReleased: mouse => {
            if (!dragged) {
                // 没有拖动就是点击
                BasicConfig.bkanAreaClicked();
            }
        }
    }
    Leftpage {
        id: leftrect
        width: 200
        anchors.top: parent.top
        anchors.bottom: bottomrect.top
        color: "#1a1a21"
        radius: 20
        clip: true
        // 盖住其他角
        Rectangle {
            // 右上角遮挡
            anchors.top: parent.top
            anchors.right: parent.right
            width: 20
            height: 20
            color: "#1a1a21"
        }
        Rectangle {
            // 左下角遮挡
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            color: "#1a1a21"
        }
        Rectangle {
            // 右下角遮挡
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            color: "#1a1a21"
        }
    }
    Rightpage {
        id: rightrect
        anchors.left: leftrect.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: bottomrect.top
        color: "#13131a"
        radius: 20
        clip: true
        Rectangle {
            // 左下角遮挡
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            color: "#13131a"
        }
        Rectangle {
            // 右下角遮挡
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 20
            height: 20
            color: "#13131a"
        }
        Rectangle {
            // 左上角角遮挡
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
            color: "#13131a"
        }
    }
    Bottompage {
        id: bottomrect
        height: 100
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#2d2d37"
        radius: 20
        clip: true
        Rectangle {
            // 左上角角遮挡
            anchors.left: parent.left
            anchors.top: parent.top
            width: 20
            height: 20
            color: "#2d2d37"
        }
        Rectangle {
            // 右上角遮挡
            anchors.top: parent.top
            anchors.right: parent.right
            width: 20
            height: 20
            color: "#2d2d37"
        }
    }
    PlayingPage {
        id: lyricsPage

        width: root.width
        height: root.height

        y: root.lyricsOpened ? 0 : root.height

        z: 9999

        Behavior on y {
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
            }
        }
    }

}
