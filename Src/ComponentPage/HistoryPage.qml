import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

// 听歌历史（云端）：展示酷狗账号的听歌记录，行样式同歌单详情页
Item {
    id: root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "HistoryPage"


    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    Component.onCompleted: {
        if (historyManager) historyManager.fetchHistory()
    }

    // ===== 顶部标题 =====
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.leftMargin: 0.025 * root.width
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 12

        Text {
            text: "听歌历史"
            font.pixelSize: 22
            font.bold: true
            color: AppTheme.textPrimary
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: historyManager ? historyManager.history.length + "首" : "0首"
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        // 返回按钮
        Rectangle {
            width: 28; height: 28; radius: 14
            color: backHover.hovered ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: backIco
                anchors.centerIn: parent
                source: AppIcon.back
                sourceSize: Qt.size(128, 128)
                mipmap: true
                width: 14; height: 14; fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay { source: backIco; color: AppTheme.iconDefault }
            }
            HoverHandler { id: backHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: BasicConfig.goBack()
            }
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }
    }

    // ===== 列表 =====
    ListView {
        id: historyList
        anchors.top: headerRow.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        cacheBuffer: 2000
        model: historyManager ? historyManager.history : []
        spacing: 2
        leftMargin: 30
        rightMargin: 30

        ScrollBar.vertical: ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 5
            width: 10
            contentItem: Rectangle {
                visible: parent.active
                width: 10
                radius: 4
                color: AppTheme.scrollbarColor
            }
        }

        onContentYChanged: {
            if (historyManager && !historyManager.isLoading && historyManager.hasMore
                && contentHeight > height && contentY >= contentHeight - height - 200) {
                historyManager.fetchMoreHistory()
            }
        }

        // 空状态
        Column {
            visible: historyManager && historyManager.history.length === 0 && !historyManager.isLoading
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
                text: "还没有听歌历史"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "播放的歌曲会自动同步到酷狗"
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 加载中
        Text {
            anchors.centerIn: parent
            visible: historyManager && historyManager.isLoading && historyManager.history.length === 0
            text: "正在加载..."
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }

        delegate: Rectangle {
            id: songRow
            width: historyList.width - 60
            height: 60 + aiExpand.expandedHeight
            radius: 6
            color: "transparent"

            readonly property var songData: modelData
            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

            // 行内容固定在 60 高，下方让位给 AI 展开
            Item {
                width: parent.width
                height: 60

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 15

                Text {
                    width: 25
                    text: (index + 1).toString().padStart(2, "0")
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: AppTheme.fontSizeTitle
                    color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                    visible: !isPlaying
                }

                NowPlayingIndicator {
                    visible: isPlaying
                    playing: playlistmanager ? !playlistmanager.isPaused : true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Image {
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    source: songData.union_cover
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: 40; height: 40; radius: 6 }
                    }
                }

                Column {
                    width: 0.3 * historyList.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: songData.songname
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeBody
                        font.bold: true
                        color: (isPlaying || songHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                        font.family: AppTheme.fontFamily
                    }
                    Text {
                        text: songData.singername
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.bold: true
                        color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                }

                Text {
                    text: songData.play_count ? "播放 " + songData.play_count + " 次" : ""
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }

                // AI 推荐（hover 显示，点击展开/收回生成的 AI 歌单；有数据时切换为箭头）
                IconButton {
                    visible: songHover.hovered

                    iconSource: aiExpand.expanded ? AppIcon.caretDown

                        : (aiExpand.aiSongs.length > 0 ? AppIcon.caretRight : AppIcon.sparkle)
                    size: 30
                    iconSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        aiExpand.toggle(songData.songhash, songData.songname)
                    }
                }

                Text {
                    text: songData.album_name
                    width: 0.2 * historyList.width
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: AppTheme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: songData.duration || "--:--"
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            }   // 行内容固定高容器结束

            // AI 推荐展开（点 ✨ 后在行下方撑开几小行）
            AiRecommendExpand {
                id: aiExpand
                anchors.top: parent.top
                anchors.topMargin: 60
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 44
                anchors.rightMargin: 14
            }

            HoverHandler { id: songHover }
            // 整行点击 = 播放（一起听 = 加入一起听）
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    if (isTogetherMode) {
                        if (websocket) {
                            websocket.addSongToTogether(songData.songname, songData.songhash,
                                songData.singername, songData.album_name,
                                songData.duration, songData.union_cover)
                        }
                    } else {
                        playlistmanager.playNextAndPlay({
                            "songname": songData.songname,
                            "songhash": songData.songhash,
                            "singername": songData.singername,
                            "union_cover": songData.union_cover,
                            "album_name": songData.album_name,
                            "duration": songData.duration
                        })
                        BasicConfig.emitSongAdded("正在播放: " + songData.songname)
                    }
                }
            }
        }
    }
}
