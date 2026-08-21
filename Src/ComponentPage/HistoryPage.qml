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

    // 纯云端听歌历史：以 /user/listen（listenservice）为准，不做本地合并
    // historyModel 作缓冲：historyReset/historyAppended 增量填充，避免整体替换导致 ListView 弹回顶部
    ListModel { id: historyModel }

    function setSongs(songs) {
        historyModel.clear()
        for (var i = 0; i < songs.length; i++)
            historyModel.append(songs[i])
    }

    Component.onCompleted: {
        if (historyManager) historyManager.fetchHistory()
    }

    onVisibleChanged: {
        if (root.visible && historyManager)
            historyManager.fetchHistory()
    }

    Connections {
        target: historyManager
        function onHistoryReset(songs) { setSongs(songs) }
        function onHistoryAppended(songs) {
            for (var i = 0; i < songs.length; i++)
                historyModel.append(songs[i])
        }
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
            // 接口无 total：加载完显示「共 N 首」，未完显示「已加载 N 首」
            text: {
                if (!historyManager) return "0首"
                // 后台计数完成后显示总数；计数中显示已加载
                return historyManager.total > 0 ? ("共 " + historyManager.total + " 首")
                                                 : ("已加载 " + historyModel.count + " 首")
            }
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

        // 刷新按钮（点击重新拉云端；加载中图标转圈）
        Rectangle {
            width: 28; height: 28; radius: 14
            color: refreshHover.hovered ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: refreshIco
                anchors.centerIn: parent
                source: AppIcon.refresh
                sourceSize: Qt.size(128, 128)
                mipmap: true
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay { source: refreshIco; color: AppTheme.iconDefault }
                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    running: historyManager && historyManager.isLoading
                }
            }
            HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: if (historyManager) historyManager.fetchHistory()
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
        cacheBuffer: 400
        model: historyModel
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

        // 下拉到底加载更多（playhistory 分页；hasMore 由已加载页数决定）
        onContentYChanged: {
            if (historyManager && !historyManager.isLoading && historyManager.hasMore
                && contentHeight > height && contentY >= contentHeight - height - 200) {
                historyManager.fetchMoreHistory()
            }
        }

        // 底部加载动画（hasMore 才显示：加载中转圈 + 文案，否则不占位）
        footer: Item {
            width: historyList.width
            height: historyManager && historyManager.hasMore ? 44 : 0
            visible: historyManager && historyManager.hasMore
            Row {
                anchors.centerIn: parent
                spacing: 8
                Image {
                    id: moreSpinner
                    source: AppIcon.refresh
                    sourceSize: Qt.size(48, 48)
                    width: 14; height: 14
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: historyManager && historyManager.isLoading
                    layer.enabled: true
                    layer.effect: ColorOverlay { source: moreSpinner; color: AppTheme.textMuted }
                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                        running: moreSpinner.visible
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (historyManager && historyManager.isLoading) ? "加载中..." : "上拉加载更多"
                    color: AppTheme.textMuted
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
            }
        }

        // 空状态
        Column {
            visible: historyModel.count === 0 && (!historyManager || !historyManager.isLoading)
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
            visible: historyManager && historyManager.isLoading && historyModel.count === 0
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

            readonly property var songData: model
            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === model.songhash

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
                    source: model.union_cover
                    asynchronous: true
                    cache: true
                    sourceSize.width: 80
                    sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: 40; height: 40; radius: 6 }
                    }
                }

                Column {
                    width: 0.22 * historyList.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: model.songname
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeBody
                        font.bold: true
                        color: (isPlaying || songHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                        font.family: AppTheme.fontFamily
                    }
                    Text {
                        text: model.singername
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.bold: true
                        color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                }

                // 播放次数（歌名/歌手右侧）
                Text {
                    text: model.play_count ? "播放 " + model.play_count + " 次" : ""
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textDim
                    font.family: AppTheme.fontFamily
                    visible: model.play_count > 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 操作按钮区（固定宽度占位，悬停时显示；布局同歌单详情页）
                Item {
                    width: isTogetherMode ? 70 : 170
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.fill: parent
                        spacing: 4
                        visible: songHover.hovered

                        IconButton {
                            visible: !isTogetherMode && !isPlaying
                            iconSource: AppIcon.playCircle
                            size: 30
                            iconSize: 16
                            onClicked: {
                                playlistmanager.playNextAndPlay({
                                    "songname": model.songname,
                                    "songhash": model.songhash,
                                    "singername": model.singername,
                                    "union_cover": model.union_cover,
                                    "album_name": model.album_name,
                                    "duration": model.duration
                                })
                                BasicConfig.emitSongAdded("正在播放: " + model.songname)
                            }
                        }

                        // AI 推荐（点击展开/收回生成的 AI 歌单；有数据时切换为箭头）
                        IconButton {
                            iconSource: aiExpand.expanded ? AppIcon.caretDown
                                : (aiExpand.aiSongs.length > 0 ? AppIcon.caretRight : AppIcon.sparkle)
                            size: 30
                            iconSize: 16
                            onClicked: aiExpand.toggle(model.songhash, model.songname)
                        }

                        IconButton {
                            visible: !isTogetherMode && !isPlaying
                            iconSource: AppIcon.addToList
                            size: 30
                            iconSize: 16
                            onClicked: {
                                playlistmanager.addSongNext({
                                    "songname": model.songname,
                                    "songhash": model.songhash,
                                    "singername": model.singername,
                                    "union_cover": model.union_cover,
                                    "album_name": model.album_name,
                                    "duration": model.duration
                                })
                                BasicConfig.emitSongAdded("已添加到下一首: " + model.songname)
                            }
                        }

                        IconButton {
                            visible: !isTogetherMode && !isPlaying
                            iconSource: AppIcon.heart
                            iconColor: AppTheme.textSecondary
                            size: 30
                            iconSize: 16
                            onClicked: {
                                if (!userManager || !userManager.isLoggedIn) {
                                    BasicConfig.noticeError("请先登录")
                                    return
                                }
                                playlistCollection.addToFavorite(model.songname, model.songhash, model.singername)
                            }
                        }

                        IconButton {
                            visible: isTogetherMode && !isPlaying
                            iconSource: AppIcon.addTogether
                            size: 30
                            iconSize: 16
                            onClicked: websocket.addSongToTogether(model.songname, model.songhash,
                                                                   model.singername, model.album_name,
                                                                   model.duration, model.union_cover)
                        }
                    }
                }

                Text {
                    text: model.album_name
                    width: 0.15 * historyList.width
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: AppTheme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: model.duration || "--:--"
                    width: 45
                    elide: Text.ElideRight
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
                            websocket.addSongToTogether(model.songname, model.songhash,
                                model.singername, model.album_name,
                                model.duration, model.union_cover)
                        }
                    } else {
                        playlistmanager.playNextAndPlay({
                            "songname": model.songname,
                            "songhash": model.songhash,
                            "singername": model.singername,
                            "union_cover": model.union_cover,
                            "album_name": model.album_name,
                            "duration": model.duration
                        })
                        BasicConfig.emitSongAdded("正在播放: " + model.songname)
                    }
                }
            }
        }
    }
}
