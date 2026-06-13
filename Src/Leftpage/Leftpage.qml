pragma ComponentBehavior: Bound
import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

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
            spacing: 8
            anchors.centerIn: parent

            Rectangle {
                width: 44
                height: 44
                radius: 12
                color: "transparent"

                Image {
                    id: wyyicon
                    anchors.centerIn: parent
                    source: "qrc:/image/wyyicon.png"
                    width: 36
                    height: 36
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                        }
                    }
                }
            }

            Text {
                id: titletext
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("网狗音乐")
                font.pixelSize: 20
                font.family: AppTheme.fontFamily
                font.bold: true
                color: AppTheme.textPrimary
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
                iconType: "discover",
                text: "云音乐精选",
                pageurl: "qrc:/Src/ComponentPage/HomePage.qml"
            },
            {
                iconType: "together",
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
                color: leftpageRectangle.currentIndex === index ? AppTheme.accent : (navMouseArea.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

                property bool isSelected: leftpageRectangle.currentIndex === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    NavIcon {
                        iconType: navColumn.navList[navItemRect.index].iconType
                        selected: navItemRect.isSelected
                        iconColor: navItemRect.isSelected ? AppTheme.iconActive : AppTheme.iconNav
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn.navList[navItemRect.index].text
                        font.pixelSize: 14
                        font.family: AppTheme.fontFamily
                        color: navItemRect.isSelected ? AppTheme.textPrimary : AppTheme.textSecondary
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

                scale: navMouseArea.containsMouse && !isSelected ? 1.03 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
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
        color: AppTheme.borderSubtle

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animThemeTransition
            }
        }
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
                iconType: "playlist",
                text: "我的歌单",
                pageurl: "qrc:/Src/ComponentPage/UserPlaylistPage.qml"
            },
            {
                iconType: "list",
                text: "播放列表",
                pageurl: "qrc:/Src/ComponentPage/LocalMusic.qml"
            },
            {
                iconType: "recent",
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
                color: leftpageRectangle.currentIndex - 3 === index ? AppTheme.accent : (navMouseArea2.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

                property bool isSelected: leftpageRectangle.currentIndex - 3 === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    NavIcon {
                        iconType: navColumn2.navList[navItemRect2.index].iconType
                        selected: navItemRect2.isSelected
                        iconColor: navItemRect2.isSelected ? AppTheme.iconActive : AppTheme.iconNav
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn2.navList[navItemRect2.index].text
                        font.pixelSize: 14
                        font.family: AppTheme.fontFamily
                        color: navItemRect2.isSelected ? AppTheme.textPrimary : AppTheme.textSecondary
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

                scale: navMouseArea2.containsMouse && !isSelected ? 1.03 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
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
        color: updateMouseArea.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar

        Row {
            spacing: 8
            anchors.centerIn: parent

            Text {
                text: "\u21BB"
                color: AppTheme.textMuted
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "检查更新"
                color: AppTheme.textMuted
                font.pixelSize: 13
                font.family: AppTheme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: appUpdater ? "v" + appUpdater.currentVersion : ""
                color: AppTheme.textDim
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
                    root.autoCheckUpdate = false;
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
