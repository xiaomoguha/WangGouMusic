import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Page {
    id: recentPage
    background: Rectangle { color: "transparent" }

    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    // ===== 顶部标题 =====
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.leftMargin: 0.025 * root.width
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 12

        Text {
            text: "最近播放"
            font.pixelSize: 22
            font.bold: true
            color: AppTheme.textPrimary
            font.family: "黑体"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: playlistmanager ? playlistmanager.recentPlaylist.length + "首" : "0首"
            font.pixelSize: 13
            color: AppTheme.textMuted
            font.family: "黑体"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== 空状态 =====
    Column {
        visible: !playlistmanager || playlistmanager.recentPlaylist.length === 0
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            width: 64
            height: 64
            radius: 32
            color: AppTheme.isDark ? AppTheme.accentDim : "#10FF8A80"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 28
                color: AppTheme.accent
            }
        }
        Text {
            text: "还没有播放记录"
            font.pixelSize: 14
            font.family: "黑体"
            color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "播放过的歌曲会出现在这里"
            font.pixelSize: 12
            font.family: "黑体"
            color: AppTheme.textDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ===== 歌曲列表 =====
    Flickable {
        id: recentFlick
        visible: playlistmanager && playlistmanager.recentPlaylist.length > 0
        anchors.top: headerRow.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: recentCol.height

        Column {
            id: recentCol
            width: recentFlick.width
            spacing: 2

            Repeater {
                model: playlistmanager ? playlistmanager.recentPlaylist : []

                delegate: Rectangle {
                    id: songItem
                    required property int index
                    required property var modelData
                    width: recentCol.width
                    height: 56
                    radius: 8
                    color: itemHover.hovered ? AppTheme.bgCardHover : "transparent"

                    property bool showActions: itemHover.hovered

                    HoverHandler { id: itemHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 0.025 * root.width
                        anchors.rightMargin: 0.05 * root.width
                        spacing: 12

                        // 序号
                        Text {
                            width: 30
                            text: songItem.index + 1 <= 9 ? "0" + String(songItem.index + 1) : songItem.index + 1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            color: AppTheme.textMuted
                            font.family: "黑体"
                        }

                        // 封面
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            source: modelData.union_cover || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 80
                            sourceSize.height: 80

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: "transparent"
                                border.width: 0
                                visible: modelData.union_cover === ""

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.title ? modelData.title.substring(0, 1) : "♪"
                                    color: AppTheme.accent
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }
                        }

                        // 歌名 + 歌手
                        Column {
                            width: 0.2 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: modelData.title
                                font.pixelSize: 13
                                font.family: "黑体"
                                color: AppTheme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                font.pixelSize: 11
                                font.family: "黑体"
                                color: AppTheme.textMuted
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                        }

                        // 操作按钮（悬停显示）
                        Row {
                            visible: songItem.showActions
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // 播放按钮
                            Rectangle {
                                visible: !isTogetherMode
                                width: 28; height: 28; radius: 14
                                color: AppTheme.isDark
                                       ? (playHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                       : (playHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                Image {
                                    id: playIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/image/playnow.png"
                                    width: 12; height: 12
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: playIcon
                                        color: AppTheme.isDark ? AppTheme.iconDefault : AppTheme.accent
                                    }
                                }
                                HoverHandler { id: playHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: {
                                        playlistmanager.addandplay(modelData.title, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                        BasicConfig.emitSongAdded("正在播放: " + modelData.title);
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // 添加到列表按钮
                            Rectangle {
                                visible: !isTogetherMode
                                width: 28; height: 28; radius: 14
                                color: AppTheme.isDark
                                       ? (addHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                       : (addHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                Image {
                                    id: addIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/image/addplaylist.png"
                                    width: 12; height: 12
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: addIcon
                                        color: AppTheme.isDark ? AppTheme.iconDefault : AppTheme.accent
                                    }
                                }
                                HoverHandler { id: addHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: {
                                        playlistmanager.addSong(modelData.title, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                        BasicConfig.emitSongAdded();
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // 一起听按钮
                            Rectangle {
                                visible: (websocket && websocket.connected) || isTogetherMode
                                width: 28; height: 28; radius: 14
                                color: AppTheme.isDark
                                       ? (togetherHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                       : (togetherHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                Image {
                                    id: togetherIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/image/yinle.png"
                                    width: 12; height: 12
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: togetherIcon
                                        color: AppTheme.isDark ? (togetherHover.hovered ? AppTheme.accent : AppTheme.iconDefault)
                                               : AppTheme.accent
                                    }
                                }
                                HoverHandler { id: togetherHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: {
                                        websocket.addSongToTogether(
                                            modelData.title, modelData.songhash, modelData.singername,
                                            modelData.album_name, modelData.duration, modelData.union_cover
                                        );
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // 喜欢按钮
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: AppTheme.isDark
                                       ? (loveHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                       : (loveHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                Image {
                                    id: loveIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/image/addlove.png"
                                    width: 12; height: 12
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: loveIcon
                                        color: AppTheme.isDark ? (loveHover.hovered ? AppTheme.accent : AppTheme.iconDefault)
                                               : AppTheme.accent
                                    }
                                }
                                HoverHandler { id: loveHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // 专辑
                        Text {
                            x: songItem.showActions ? 0.48 * root.width : 0.4 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: 0.28 * root.width
                            wrapMode: Text.NoWrap
                            text: modelData.album_name
                            font.pixelSize: 13
                            font.family: "黑体"
                            color: AppTheme.textMuted

                            Behavior on x { NumberAnimation { duration: 150 } }
                        }

                        // 时长
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var d = modelData.duration;
                                if (!d) return "--:--";
                                if (d.indexOf(":") !== -1) return d;
                                var sec = parseInt(d);
                                if (isNaN(sec)) return d;
                                var m = Math.floor(sec / 60);
                                var s = sec % 60;
                                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                            }
                            font.pixelSize: 13
                            font.family: "黑体"
                            color: AppTheme.textMuted
                        }
                    }

                    // 入场动画
                    opacity: 0
                    Component.onCompleted: itemAnim.start()
                    NumberAnimation on opacity {
                        id: itemAnim
                        from: 0
                        to: 1
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
