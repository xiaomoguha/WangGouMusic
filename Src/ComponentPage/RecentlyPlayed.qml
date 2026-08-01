import QtQuick 2.15
import QtQuick.Controls
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
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: playlistmanager ? playlistmanager.recentPlaylist.count + "首" : "0首"
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== 空状态 =====
    Column {
        visible: !playlistmanager || playlistmanager.recentPlaylist.count === 0
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            width: 64
            height: 64
            radius: 32
            color: AppTheme.accentSubtle
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
            font.pixelSize: AppTheme.fontSizeBodyLg
            font.family: AppTheme.fontFamily
            color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "播放过的歌曲会出现在这里"
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            color: AppTheme.textDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ===== 歌曲列表 =====
    Flickable {
        id: recentFlick
        visible: playlistmanager && playlistmanager.recentPlaylist.count > 0
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

                        Text {
                            width: 30
                            text: (songItem.index + 1).toString().padStart(2, "0")
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }

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
                                    font.pixelSize: AppTheme.fontSizeTitle
                                    font.bold: true
                                }
                            }
                        }

                        Column {
                            width: 0.2 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: modelData.title
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
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

                            IconButton {
                                visible: !isTogetherMode
                                iconSource: "qrc:/image/playnow.png"
                                onClicked: {
                                    // 先缓存 modelData：playNextAndPlay 可能触发 recentPlaylist 刷新，
                                    // 导致 delegate 袘重建、modelData 失效（ReferenceError）
                                    var md = modelData
                                    playlistmanager.playNextAndPlay({
                                        "songname": md.title,
                                        "songhash": md.songhash,
                                        "singername": md.singername,
                                        "union_cover": md.union_cover,
                                        "album_name": md.album_name,
                                        "duration": md.duration
                                    });
                                    BasicConfig.emitSongAdded("正在播放: " + md.title);
                                }
                            }

                            // 添加到列表按钮
                            IconButton {
                                visible: !isTogetherMode
                                iconSource: "qrc:/image/addplaylist.png"
                                onClicked: {
                                    playlistmanager.addSong({
                                        "songname": modelData.title,
                                        "songhash": modelData.songhash,
                                        "singername": modelData.singername,
                                        "union_cover": modelData.union_cover,
                                        "album_name": modelData.album_name,
                                        "duration": modelData.duration
                                    });
                                    BasicConfig.emitSongAdded();
                                }
                            }

                            // 一起听按钮
                            IconButton {
                                id: togetherBtn
                                visible: (websocket && websocket.connected) || isTogetherMode
                                iconSource: "qrc:/image/yinle.png"
                                iconColor: AppTheme.isDark ? (togetherBtn.hovered ? AppTheme.accent : AppTheme.iconDefault) : AppTheme.accent
                                onClicked: websocket.addSongToTogether(modelData.title, modelData.songhash, modelData.singername, modelData.album_name, modelData.duration, modelData.union_cover)
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
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted

                            Behavior on x { NumberAnimation { duration: AppTheme.animFast } }
                        }

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
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
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
                        duration: AppTheme.animThemeTransition
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
