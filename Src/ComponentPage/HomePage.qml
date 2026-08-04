import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    objectName: "HomePage"
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ===================== 滚动容器 =====================
    Flickable {
        id: flickable
        anchors.fill: parent
        clip: true
        contentHeight: contentColumn.height
        contentWidth: width

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

        Column {
            id: contentColumn
            width: parent.width
            spacing: 30
            leftPadding: width * 0.04
            rightPadding: width * 0.04

            Item { width: 1; height: 5 }

            // ========== 热门推荐 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Text {
                    text: "✦ 热门推荐"
                    font.pixelSize: AppTheme.fontSizeTitleLg
                    font.bold: true
                    color: AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }

                GridView {
                    id: songsGrid
                    width: parent.width
                    height: contentHeight
                    // 按窗口宽度自适应列数：约 150px 一列，3~7 列
                    readonly property int colCount: Math.max(3, Math.min(7, Math.floor((width + 12) / 150)))
                    cellWidth: width / colCount
                    // 横版圆角矩形封面（高 = 宽 × 3/4）+ 下方歌名/歌手文字区
                    cellHeight: (cellWidth - 22) * 3 / 4 + 62
                    interactive: false
                    model: recommendation ? recommendation.topSongsQml : []

                    delegate: Item {
                        width: songsGrid.cellWidth - 6
                        height: songsGrid.cellHeight - 6

                        property var songData: modelData
                        readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

                        Rectangle {
                            anchors.fill: parent
                            // hover 改为歌曲名高亮（背景透明，渐变下无块状覆盖层）
                            color: "transparent"
                            radius: 12

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    width: parent.width
                                    // 横版圆角矩形封面（高 = 宽 × 3/4，圆角 12）
                                    height: width * 3 / 4
                                    radius: 12
                                    clip: true

                                    Image {
                                        id: songCoverImage
                                        anchors.fill: parent
                                        source: songData.union_cover
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 400
                                        sourceSize.height: 300
                                        fillMode: Image.PreserveAspectCrop
                                        // clip 只裁矩形不裁圆角，这里用 OpacityMask 做真正圆角
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: songCoverImage.width
                                                height: songCoverImage.height
                                                radius: 12
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#40000000"
                                        visible: songCardHover.hovered || isPlaying
                                        radius: 12

                                        NowPlayingIndicator {
                                            anchors.centerIn: parent
                                            visible: isPlaying
                                        }

                                        Image {
                                            id: cardPlayIcon
                                            anchors.centerIn: parent
                                            // 一起听模式下图标换成「加入一起听」，点击行为已由 TapHandler 区分
                                            source: isTogetherMode ? AppIcon.addTogether : AppIcon.playCircle
                                            width: 32
                                            height: 32
                                            fillMode: Image.PreserveAspectFit
                                            visible: !isPlaying && songCardHover.hovered
                                            sourceSize: Qt.size(128, 128)
                                            mipmap: true
                                            layer.enabled: true
                                            // 遮罩是深色压暗，播放按钮一律用白色（浅色主题下也清晰）
                                            layer.effect: ColorOverlay { source: cardPlayIcon; color: "#FFFFFF" }
                                        }
                                    }
                                }

                                Text {
                                    text: songData.songname
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.bold: true
                                    // hover 歌曲名高亮（网易云风格），播放行保持强调色
                                    color: (isPlaying || songCardHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                    font.family: AppTheme.fontFamily
                                }

                                Text {
                                    text: songData.singername
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.bold: true
                                    color: AppTheme.textMuted
                                    font.family: AppTheme.fontFamily
                                }
                            }

                            HoverHandler { id: songCardHover }

                            TapHandler {
                                cursorShape: Qt.PointingCursor
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

                EmptyState {
                    visible: !recommendation || recommendation.topSongsQml.length === 0
                    width: parent.width
                    height: 220
                    iconText: "♪"
                    title: "暂无推荐内容"
                    subtitle: "点击下方按钮刷新试试"
                    buttonText: "刷新推荐"
                    onButtonClicked: {
                        if (recommendation) {
                            recommendation.fetchTopSongs()
                            recommendation.fetchTopPlaylists()
                        }
                    }
                }
            }

            // ========== 精选歌单 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Row {
                    spacing: 10

                    Text {
                        text: "↑ 精选歌单"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    Item { width: 10; height: 1 }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: refreshHover.hovered ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: refreshIcon
                            anchors.centerIn: parent
                            source: AppIcon.refresh
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: refreshIcon
                                color: AppTheme.iconDefault
                            }

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 600
                                loops: Animation.Infinite
                                running: playlistRefreshAnim.running
                            }
                        }

                        HoverHandler { id: refreshHover }
                        TapHandler {
                            cursorShape: Qt.PointingCursor
                            onTapped: {
                                if (recommendation) {
                                    playlistRefreshAnim.start()
                                    recommendation.refreshTopPlaylists()
                                }
                            }
                        }
                    }
                }

                // 刷新时的淡出淡入过渡
                Item {
                    width: parent.width
                    height: playlistsGrid.height

                    GridView {
                        id: playlistsGrid
                        width: parent.width
                        height: contentHeight
                        cellWidth: width / 2
                        cellHeight: 100
                        interactive: false
                        model: recommendation ? recommendation.topPlaylistsQml : []
                        opacity: 1

                        Behavior on opacity {
                            NumberAnimation { duration: AppTheme.animThemeTransition; easing.type: Easing.OutCubic }
                        }

                        SequentialAnimation {
                            id: playlistRefreshAnim
                            NumberAnimation { target: playlistsGrid; property: "opacity"; to: 0; duration: AppTheme.animFast; easing.type: Easing.InCubic }
                            NumberAnimation { target: playlistsGrid; property: "opacity"; to: 1; duration: AppTheme.animThemeTransition; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            width: playlistsGrid.cellWidth - 10
                            height: playlistsGrid.cellHeight - 10

                            property var plData: modelData

                            Rectangle {
                                anchors.fill: parent
                                // hover 改为歌单名高亮（背景透明，渐变下无块状覆盖层）
                                color: "transparent"
                                radius: 12

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 12

                                    Image {
                                        id: plCover
                                        width: 80
                                        height: 80
                                        source: plData.imgurl
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 160
                                        sourceSize.height: 160
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 80; height: 80; radius: 10 }
                                        }
                                    }

                                    Column {
                                        width: parent.width - plCover.width - 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: plData.specialname
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.pixelSize: AppTheme.fontSizeBody
                                            font.bold: true
                                            // hover 歌单名高亮（网易云风格）
                                            color: plHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                                            font.family: AppTheme.fontFamily
                                        }
                                        Text {
                                            text: plData.intro
                                            width: parent.width
                                            height: 32
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            font.pixelSize: AppTheme.fontSizeCaption
                                            color: AppTheme.textMuted
                                            font.family: AppTheme.fontFamily
                                        }
                                        Row {
                                            spacing: 8
                                            Text {
                                                text: (plData.play_count / 10000).toFixed(1) + "万播放"
                                                font.pixelSize: AppTheme.fontSizeXs
                                                color: AppTheme.textMuted
                                                font.family: AppTheme.fontFamily
                                            }
                                            Rectangle {
                                                visible: plData.tags !== ""
                                                height: 16
                                                width: tagText.width + 10
                                                radius: 8
                                                color: AppTheme.bgNavHover
                                                Text {
                                                    id: tagText
                                                    text: plData.tags
                                                    font.pixelSize: AppTheme.fontSizeXs
                                                    color: AppTheme.textMuted
                                                    anchors.centerIn: parent
                                                    font.family: AppTheme.fontFamily
                                                }
                                            }
                                        }
                                    }
                                }

                                HoverHandler { id: plHover }
                                TapHandler {
                                    cursorShape: Qt.PointingCursor
                                    onTapped: {
                                        BasicConfig.openPlaylistDetail(
                                            plData.global_collection_id,
                                            plData.specialname,
                                            plData.imgurl,
                                            plData.intro
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 20 }
        }
    }
}
