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
        anchors.leftMargin: 0.025 * recentPage.width
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
                    height: 60
                    radius: 5
                    // hover/播放改为文字高亮（背景透明，渐变下无块状覆盖层）
                    color: "transparent"

                    // 与歌单详情页一致的「正在播放」高亮：♪/动图 + 强调色
                    readonly property bool isPlaying: !!(playlistmanager && playlistmanager.currentSonghash === modelData.songhash)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 0.025 * recentPage.width
                        anchors.rightMargin: 0.05 * recentPage.width
                        spacing: 15

                        Text {
                            width: 25
                            text: (songItem.index + 1).toString().padStart(2, "0")
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: AppTheme.fontSizeTitle
                            color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                            visible: !isPlaying
                        }

                        NowPlayingIndicator {
                            visible: isPlaying
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Image {
                            width: 40
                            height: 40
                            source: modelData.union_cover || ""
                            sourceSize.width: 80
                            sourceSize.height: 80
                            fillMode: Image.PreserveAspectCrop
                            anchors.verticalCenter: parent.verticalCenter
                            asynchronous: true
                            cache: true

                            // ponytail: 封面缺失时的占位（历史记录更易缺封面），不占额外布局
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: AppTheme.bgCard
                                visible: !modelData.union_cover
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
                            width: 0.3 * recentPage.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: modelData.title
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                font.bold: true
                                // hover 歌曲名高亮（网易云风格），播放行保持强调色
                                color: (isPlaying || itemHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                            }
                            Text {
                                text: modelData.singername
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                font.bold: true
                                color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                            }
                        }

                        // 操作按钮区（固定宽度占位，悬停时显示；专辑/时长不再随悬停跳动）
                        Item {
                            width: isTogetherMode ? 34 : 68
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.fill: parent
                                spacing: 4
                                visible: itemHover.hovered && !isPlaying

                                IconButton {
                                    id: playBtn
                                    visible: !isTogetherMode
                                    size: 30
                                    iconSize: 16
                                    iconSource: AppIcon.playCircle
                                    iconColor: AppTheme.isDark ? (playBtn.hovered ? "#4FC3F7" : "#FFFFFF") : AppTheme.iconDefault
                                    onClicked: {
                                        // 先读取为基本类型：playNextAndPlay 会触发 recentPlaylist 重置，
                                        // 之后 modelData 按失效下标取值会得到 undefined（toast 显示“正在播放 undefined”）。
                                        var title = modelData.title
                                        var songhash = modelData.songhash
                                        var singername = modelData.singername
                                        var union_cover = modelData.union_cover
                                        var album_name = modelData.album_name
                                        var duration = modelData.duration
                                        playlistmanager.playNextAndPlay({
                                            "songname": title,
                                            "songhash": songhash,
                                            "singername": singername,
                                            "union_cover": union_cover,
                                            "album_name": album_name,
                                            "duration": duration
                                        })
                                        BasicConfig.emitSongAdded("正在播放: " + title)
                                    }
                                }

                                IconButton {
                                    id: addBtn
                                    visible: !isTogetherMode
                                    size: 30
                                    iconSize: 16
                                    iconSource: AppIcon.addToList
                                    iconColor: AppTheme.isDark ? (addBtn.hovered ? AppTheme.accent : "#FFFFFF") : AppTheme.iconDefault
                                    onClicked: {
                                        var md = modelData
                                        playlistmanager.addSong({
                                            "songname": md.title,
                                            "songhash": md.songhash,
                                            "singername": md.singername,
                                            "union_cover": md.union_cover,
                                            "album_name": md.album_name,
                                            "duration": md.duration
                                        })
                                        BasicConfig.emitSongAdded("已添加到播放列表: " + md.title)
                                    }
                                }

                                IconButton {
                                    id: togetherBtn
                                    visible: isTogetherMode
                                    size: 30
                                    iconSize: 16
                                    iconSource: AppIcon.addTogether
                                    iconColor: AppTheme.isDark ? (togetherBtn.hovered ? AppTheme.accent : "#FFFFFF") : AppTheme.iconDefault
                                    onClicked: {
                                        var md = modelData
                                        websocket.addSongToTogether(md.title, md.songhash, md.singername, md.album_name, md.duration, md.union_cover)
                                    }
                                }
                            }
                        }

                        Text {
                            text: modelData.album_name
                            width: 0.2 * recentPage.width
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.family: AppTheme.fontFamily
                            font.bold: true
                            color: AppTheme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: {
                                var d = modelData.duration
                                if (!d) return "--:--"
                                if (d.indexOf(":") !== -1) return d
                                var sec = parseInt(d)
                                if (isNaN(sec)) return d
                                var m = Math.floor(sec / 60)
                                var s = sec % 60
                                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                            }
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: itemHover }
                }
            }
        }
    }
}
