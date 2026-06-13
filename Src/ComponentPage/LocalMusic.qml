pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    objectName: "LocalMusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    property int index: 5
    Text {
        id: liebiaotext
        text: qsTr("播放列表")
        font.pixelSize: 24
        font.family: AppTheme.fontFamily
        color: AppTheme.textPrimary
        font.weight: Font.Bold
        anchors.left: parent.left
        anchors.leftMargin: 0.03 * root.width
        anchors.topMargin: 25
        anchors.top: parent.top
    }
    Text {
        text: "共" + (playlistmanager ? playlistmanager.playlistcount : 0) + "首"
        font.pixelSize: 13
        font.family: AppTheme.fontFamily
        color: AppTheme.textDim
        anchors.left: liebiaotext.right
        anchors.leftMargin: 10
        anchors.bottom: liebiaotext.bottom
    }
    // 搜索框
    Rectangle {
        id: searchContainer
        anchors.verticalCenter: liebiaotext.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0.1 * root.width
        width: 200
        height: 34
        radius: 17
        color: AppTheme.bgInput
        border.width: 1
        border.color: AppTheme.borderDefault

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Image {
                id: searchico
                source: "qrc:/image/search_line.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: searchico
                    color: AppTheme.iconSearch
                }
            }

            TextField {
                width: parent.width - searchico.width - parent.spacing
                height: parent.height
                placeholderText: "搜索播放列表"
                color: "#FFFFFF"
                palette.placeholderText: "#666666"
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 13
                font.family: AppTheme.fontFamily
                background: Rectangle {
                    color: "transparent"
                }
            }
        }
    }
    Flickable {
        id: playlistflick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: liebiaotext.bottom
        anchors.topMargin: 30
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: playlistcolumn.width
        contentHeight: playlistcolumn.height
        Column {
            id: playlistcolumn
            width: playlistflick.width
            spacing: 10
            Repeater {
                model: playlistmanager ? playlistmanager.playlist : 0
                delegate: Rectangle {
                    id: playlistItem
                    required property int index
                    required property var modelData
                    width: playlistcolumn.width
                    height: playlistrow.height + 25
                    radius: 5
                    // 背景色：悬停时或当前播放项时显示
                    color: (itemHoverHandler.hovered || (playlistmanager && !isTogetherMode && playlistmanager.currentIndex === index)) ? AppTheme.bgCardHover : "transparent"

                    // 使用 HoverHandler 控制列表项悬停效果
                    HoverHandler {
                        id: itemHoverHandler
                    }
                    Row {
                        id: playlistrow
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15
                        Text {
                            width: 25
                            text: index + 1 <= 9 ? "0" + String(index + 1) : index + 1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16
                            color: AppTheme.textMuted
                            visible: playlistmanager ? (!isTogetherMode && playlistmanager.currentIndex === index ? false : true) : true
                        }
                        AnimatedImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 25
                            height: 25
                            source: "qrc:/image/isplaying.gif"
                            playing: visible  // 确保动画自动播放
                            visible: playlistmanager ? (!isTogetherMode && playlistmanager.currentIndex === index) : false
                        }

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            source: modelData.union_cover
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                text: modelData.title
                                font.pixelSize: 13
                                color: playlistmanager ? (!isTogetherMode && playlistmanager.currentIndex === index ? AppTheme.accentPlaying : AppTheme.textPrimary) : AppTheme.textPrimary
                                elide: Text.ElideRight
                                width: 0.19 * root.width
                                wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                elide: Text.ElideRight
                                width: 0.19 * root.width
                                wrapMode: Text.NoWrap
                                font.pixelSize: 11
                                color: playlistmanager ? (!isTogetherMode && playlistmanager.currentIndex === index ? AppTheme.accentPlaying : AppTheme.textMuted) : AppTheme.textMuted
                            }
                        }
                    }
                    Row {
                        id: playlistadditemsrow
                        // 悬停时显示按钮，但当前播放项不显示
                        visible: itemHoverHandler.hovered && !(playlistmanager && !isTogetherMode && playlistmanager.currentIndex === index)
                        anchors.left: playlistrow.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // 播放按钮
                        Rectangle {
                            id: playlistplayNowBtn
                            width: 30
                            height: 30
                            radius: 15
                            visible: !(playlistmanager && playlistmanager.type === 1)
                            color: AppTheme.isDark
                                   ? (playNowHoverHandler.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (playNowHoverHandler.hovered ? "#FFCCCC" : "#FFD8D8")

                            Image {
                                id: playlistplayNowImage
                                anchors.centerIn: parent
                                source: "qrc:/image/playnow.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: playlistplayNowImage
                                    color: AppTheme.isDark ? (playNowHoverHandler.hovered ? "#4FC3F7" : "#FFFFFF")
                                           : AppTheme.accent
                                }
                            }

                            HoverHandler {
                                id: playNowHoverHandler
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    playlistmanager.playSongbyindex(index);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // 收藏按钮
                        Rectangle {
                            id: playlistaddloveBtn
                            width: 30
                            height: 30
                            radius: 15
                            visible: !(playlistmanager && playlistmanager.type === 1)
                            color: AppTheme.isDark
                                   ? (addLoveHoverHandler.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (addLoveHoverHandler.hovered ? "#FFCCCC" : "#FFD8D8")

                            Image {
                                id: playlistaddloveImage
                                anchors.centerIn: parent
                                source: "qrc:/image/addlove.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: playlistaddloveImage
                                    color: AppTheme.isDark ? (addLoveHoverHandler.hovered ? AppTheme.accent : "#FFFFFF")
                                           : AppTheme.accent
                                }
                            }

                            HoverHandler {
                                id: addLoveHoverHandler
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    playlistmanager.addToFavoriteByIndex(index);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // 一起听按钮
                        Rectangle {
                            id: playlistaddTogetherBtn
                            width: 30
                            height: 30
                            radius: 15
                            color: AppTheme.isDark
                                   ? (addTogetherHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (addTogetherHover.hovered ? "#FFCCCC" : "#FFD8D8")
                            visible: playlistmanager && playlistmanager.type === 1

                            Image {
                                id: togetherIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/yinle.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: togetherIcon
                                    color: AppTheme.isDark ? (addTogetherHover.hovered ? AppTheme.accent : "#FFFFFF")
                                           : AppTheme.accent
                                }
                            }

                            HoverHandler {
                                id: addTogetherHover
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    websocket.addSongToTogether(
                                        modelData.title,
                                        modelData.songhash,
                                        modelData.singername,
                                        modelData.album_name,
                                        modelData.duration,
                                        modelData.union_cover
                                    );
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }
                    Text {
                        id: playlistalbumText
                        x: 0.4 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: 0.28 * root.width
                        wrapMode: Text.NoWrap
                        text: modelData.album_name
                        font.pixelSize: 14
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textPrimary
                    }
                    Text {
                        id: playlistsonglenText
                        anchors.right: parent.right
                        anchors.rightMargin: 0.05 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration
                        font.pixelSize: 14
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                }
            }
        }
    }

    // 空状态：播放列表为空时
    EmptyState {
        anchors.top: liebiaotext.bottom
        anchors.topMargin: 60
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !playlistmanager || playlistmanager.playlistcount === 0
        iconText: "♪"
        title: "播放列表还是空的"
        subtitle: "去首页发现喜欢的音乐，添加到播放列表吧"
    }
}
