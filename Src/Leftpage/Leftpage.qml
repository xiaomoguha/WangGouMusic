pragma ComponentBehavior: Bound
import QtQuick 2.15
import Qt5Compat.GraphicalEffects
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

    // Logo 区域
    Item {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 35
        height: 50

        Row {
            spacing: 12
            anchors.centerIn: parent

            Rectangle {
                width: 40
                height: 40
                radius: 12
                color: "#FF6B6B"

                Image {
                    id: wyyicon
                    anchors.centerIn: parent
                    source: "qrc:/image/wyyicon.png"
                    width: 28
                    height: 28
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }

            Text {
                id: titletext
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("网狗音乐")
                font.pixelSize: 20
                font.family: "黑体"
                font.bold: true
                color: "#FFFFFF"
            }
        }
    }

    // 第一组导航
    Column {
        id: navColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: 40
        spacing: 4

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

        Repeater {
            model: navColumn.navList.length

            delegate: Rectangle {
                id: navItemRect
                required property int index
                width: parent.width - 24
                height: 44
                radius: 12
                anchors.horizontalCenter: parent.horizontalCenter
                color: leftpageRectangle.currentIndex === index ? "#FF6B6B" : (navMouseArea.containsMouse ? "#2A2A35" : "transparent")

                property bool isSelected: leftpageRectangle.currentIndex === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: navIcon
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: navColumn.navList[navItemRect.index].icon
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: navIcon
                            color: navItemRect.isSelected ? "#FFFFFF" : "#AAAAAA"
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn.navList[navItemRect.index].text
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: navItemRect.isSelected ? "#FFFFFF" : "#CCCCCC"
                    }
                }

                MouseArea {
                    id: navMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 已选中时不重复切换
                        if (leftpageRectangle.currentIndex !== navItemRect.index) {
                            leftpageRectangle.currentIndex = navItemRect.index;
                            BasicConfig.pushPage(navColumn.navList[navItemRect.index].pageurl);
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }

    // 分隔线
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 12
        height: 1
        color: "#2A2A35"
    }

    // 第二组导航
    Column {
        id: navColumn2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.topMargin: 20
        spacing: 4

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

        Repeater {
            model: navColumn2.navList.length

            delegate: Rectangle {
                id: navItemRect2
                required property int index
                width: parent.width - 24
                height: 44
                radius: 12
                anchors.horizontalCenter: parent.horizontalCenter
                color: leftpageRectangle.currentIndex - 3 === index ? "#FF6B6B" : (navMouseArea2.containsMouse ? "#2A2A35" : "transparent")

                property bool isSelected: leftpageRectangle.currentIndex - 3 === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: navIcon2
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit
                        source: navColumn2.navList[navItemRect2.index].icon
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: navIcon2
                            color: navItemRect2.isSelected ? "#FFFFFF" : "#AAAAAA"
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn2.navList[navItemRect2.index].text
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: navItemRect2.isSelected ? "#FFFFFF" : "#CCCCCC"
                    }
                }

                MouseArea {
                    id: navMouseArea2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 已选中时不重复切换
                        if (leftpageRectangle.currentIndex !== navItemRect2.index + 3) {
                            leftpageRectangle.currentIndex = navItemRect2.index + 3;
                            BasicConfig.pushPage(navColumn2.navList[navItemRect2.index].pageurl);
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }

    // 检查更新按钮（底部）
    Rectangle {
        id: updateBtn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        anchors.bottomMargin: 32
        height: 40
        radius: 10
        color: updateMouseArea.containsMouse ? "#2A2A35" : "transparent"

        Row {
            spacing: 8
            anchors.centerIn: parent

            Text {
                text: "\u21BB"
                color: "#888899"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "检查更新"
                color: "#888899"
                font.pixelSize: 13
                font.family: "黑体"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: appUpdater ? "v" + appUpdater.currentVersion : ""
                color: "#555566"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: updateMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (appUpdater) {
                    appUpdater.checkForUpdate();
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
