import QtQuick 2.15
import "../BasicConfig"

Rectangle {
    id: leftpageRectangle
    property int currentIndex: 0
    Connections {
        target: BasicConfig
        function onIndexchange(index) {
            leftpageRectangle.currentIndex = index;
        }
    }
    Item {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 30
        height: wyyicon.height + 40
        Row {
            spacing: 10
            anchors.centerIn: parent
            Image {
                id: wyyicon
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/image/wyyicon.png"
                smooth: true       // 启用高质量插值
                mipmap: true       // 启用多级纹理过滤
                layer.enabled: true // 强制硬件加速
                width: 35
                height: 35
                fillMode: Image.PreserveAspectFit
            }
            Text {
                id: titletext
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("网狗音乐")
                font.pixelSize: 22
                font.family: "黑体"
                color: "#dddddd"
            }
        }
    }
    Column {
        id: navColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: 50
        spacing: 5

        // 导航数据
        property var navList: [
            {
                icon: "qrc:/image/jingxuan_xuanzhong.png",
                text: "云音乐精选",
                pageurl: "qrc:/Src/ComponentPage/HomePage.qml"
            },
            {
                icon: "qrc:/image/yinle.png",
                text: "一起听歌",
                pageurl: "qrc:/Src/ComponentPage/musictogether.qml"
            }
        ]

        // 创建多个导航按钮
        Repeater {
            model: navColumn.navList.length
            delegate: Rectangle {
                id: navItemRect
                width: parent.width
                height: 50
                radius: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                Binding {
                    target: navItemRect
                    property: "color"
                    value: leftpageRectangle.currentIndex === index ? "#e74f50" : "transparent"
                }
                Row {
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: 10
                        height: 1
                    }

                    Image {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: navColumn.navList[index].icon
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn.navList[index].text
                        font.pixelSize: 15
                        font.family: "黑体"
                        color: "white"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        leftpageRectangle.currentIndex = index;
                        BasicConfig.pushPage(navColumn.navList[index].pageurl);
                    }
                    onEntered: {
                        if (leftpageRectangle.currentIndex !== index)
                            parent.color = "#393943";
                    }
                    onExited: {
                        if (leftpageRectangle.currentIndex !== index)
                            parent.color = "transparent";
                    }
                }
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 10
        height: 1
        color: "#535C6B"
    }
    Column {
        id: navColumn2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.topMargin: 40
        spacing: 5
        // 导航数据
        property var navList: [
            {
                icon: "qrc:/image/shoucang.png",
                text: "收藏",
                pageurl: "qrc:/Src/ComponentPage/MyfavoriteMusic.qml"
            },
            {
                icon: "qrc:/image/liebiao.png",
                text: "播放列表",
                pageurl: "qrc:/Src/ComponentPage/LocalMusic.qml"
            },
            {
                icon: "qrc:/image/zuijinbofang.png",
                text: "最近播放",
                pageurl: "qrc:/Src/ComponentPage/RecentlyPlayed.qml"
            }
        ]

        // 创建多个导航按钮
        Repeater {
            model: navColumn2.navList.length
            delegate: Rectangle {
                id: navItemRect2
                width: parent.width
                height: 50
                radius: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                Binding {
                    target: navItemRect2
                    property: "color"
                    value: leftpageRectangle.currentIndex - 3 === index ? "#e74f50" : "transparent"
                }
                Row {
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: 10
                        height: 1
                    }

                    Image {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: navColumn2.navList[index].icon
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn2.navList[index].text
                        font.pixelSize: 15
                        font.family: "黑体"
                        color: "white"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        leftpageRectangle.currentIndex = index + 3;
                        BasicConfig.pushPage(navColumn2.navList[index].pageurl);
                    }
                    onEntered: {
                        if (leftpageRectangle.currentIndex - 3 !== index)
                            parent.color = "#393943";
                    }
                    onExited: {
                        if (leftpageRectangle.currentIndex - 3 !== index)
                            parent.color = "transparent";
                    }
                }
            }
        }
    }
}
