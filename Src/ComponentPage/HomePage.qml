import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    id: root
    objectName: "HomePage"
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // 热门推荐行点击：一起听模式下加入房间，否则立即播放
    function playRecommendedSong(song) {
        if (!song) return
        if (root.isTogetherMode) {
            if (websocket) {
                websocket.addSongToTogether(song.songname, song.songhash, song.singername,
                                            song.album_name, song.duration, song.union_cover)
            }
            return
        }
        playlistmanager.playNextAndPlay({
            "songname": song.songname,
            "songhash": song.songhash,
            "singername": song.singername,
            "union_cover": song.union_cover,
            "album_name": song.album_name,
            "duration": song.duration
        })
        BasicConfig.emitSongAdded("正在播放: " + song.songname)
    }

    // 随机榜单歌曲 → 注入热门推荐区
    Connections {
        target: rankList
        function onRandomSongsReady(list) {
            if (recommendation)
                recommendation.showRankSongs(list)
        }
    }


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

            // 入场动效：内容整体淡入 + 轻微上浮（柔和进场），空闲门控时直接落到终态
            opacity: 0
            transform: Translate { id: contentShift; y: 16 }

            Component.onCompleted: {
                if (BasicConfig.uiIdle) {
                    contentColumn.opacity = 1
                    contentShift.y = 0
                } else {
                    entranceAnim.start()
                }
            }

            ParallelAnimation {
                id: entranceAnim
                NumberAnimation {
                    target: contentColumn; property: "opacity"
                    from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: contentShift; property: "y"
                    from: 16; to: 0; duration: 640; easing.type: Easing.OutCubic
                }
            }

            Item { width: 1; height: 5 }

            // ========== 热门推荐 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Row {
                    spacing: 6

                    GlowText {
                        text: "✦ 热门推荐"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        glowColor: AppTheme.accentGlow
                        glowRadius: 16
                    }

                    // 换一批：随机挑一个排行榜，把榜单歌曲注入推荐区（请求期间图标持续旋转）
                    SectionRefreshButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -3
                        busy: rankList && rankList.isLoading
                        onClicked: {
                            if (rankList)
                                rankList.fetchRandomRankSongs()
                        }
                    }
                }

                GridView {
                    id: recommendGrid
                    width: parent.width
                    height: contentHeight
                    cellWidth: width / 3
                    cellHeight: 70
                    interactive: false
                    model: recommendation ? recommendation.topSongsQml : []

                    delegate: RecommendSongRow {
                        width: recommendGrid.cellWidth - 10
                        itemIndex: index
                        itemData: modelData
                        togetherMode: root.isTogetherMode
                        onActivated: root.playRecommendedSong(item)
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
                    spacing: 6

                    GlowText {
                        text: "↑ 精选歌单"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        glowColor: AppTheme.accentGlow
                        glowRadius: 16
                    }

                    SectionRefreshButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -3
                        busy: recommendation && recommendation.playlistsLoading
                        onClicked: {
                            if (recommendation) {
                                playlistRefreshAnim.start()
                                recommendation.refreshTopPlaylists()
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

                            // hover 提起：上浮 + 回弹 + 投影
                            HoverCard {
                                anchors.fill: parent
                                hovered: plHover.hovered
                                hoverScale: 1.015
                                radius: AppTheme.radiusMedium
    
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 12

                                    RetryImage {
                                        id: plCover
                                        width: 80
                                        height: 80
                                        coverSource: plData.imgurl
                                        sourceSize.width: 160
                                        sourceSize.height: 160
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 80; height: 80; radius: 8 }
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
                                    cursorShape: Qt.PointingHandCursor
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

    // 热门推荐行封面（与搜索页单曲行一致）
    component CoverImage: Rectangle {
        id: coverRoot
        property string src: ""
        property int radiusValue: 8
        width: 48
        height: 48
        radius: radiusValue
        clip: true
        color: AppTheme.bgCard

        RetryImage {
            id: coverImg
            anchors.fill: parent
            coverSource: coverRoot.src
            sourceSize.width: Math.max(coverRoot.width * 2, 80)
            sourceSize.height: Math.max(coverRoot.height * 2, 80)
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !coverRoot.src || coverImg.status !== Image.Ready
            text: "♪"
            font.pixelSize: Math.max(14, coverRoot.width * 0.35)
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }
    }

    // 热门推荐单曲行：布局与搜索页「单曲」页签一致
    component RecommendSongRow: HoverRow {
        id: songRowItem
        property var itemData: ({})
        property int itemIndex: 0
        property bool togetherMode: false
        signal activated(var item)

        height: 66
        radius: 8
        color: "transparent"
        hovered: songRowHover.hovered

        readonly property bool isPlaying: !!(playlistmanager && playlistmanager.currentSonghash === itemData.songhash)

        HoverHandler { id: songRowHover }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 9

            Item {
                width: 22
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: (songRowItem.itemIndex + 1).toString().padStart(2, "0")
                    font.pixelSize: AppTheme.fontSizeSmall
                    color: songRowItem.isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }

            CoverImage {
                width: 40
                height: 40
                radiusValue: 8
                src: songRowItem.itemData.union_cover || ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 22 - 40 - 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: songRowItem.itemData.songname || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: true
                    color: (songRowItem.isPlaying || songRowHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                    font.family: AppTheme.fontFamily
                }
                Text {
                    width: parent.width
                    text: songRowItem.itemData.singername || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.bold: true
                    color: songRowItem.isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        // Overlay actions on hover so three columns keep enough title width.
        Rectangle {
            visible: actionRow.visible
            anchors.right: actionRow.right
            anchors.rightMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            width: actionRow.width + 8
            height: 30
            radius: 15
            color: "#E614141C"
            z: 1
        }

        Row {
            id: actionRow
            width: 80
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: songRowHover.hovered || climaxPreviewBtn.active
            z: 2

            HoverHandler { id: actionHover }

            ClimaxPreviewButton {
                id: climaxPreviewBtn
                songHash: songRowItem.itemData.songhash || ""
                songTitle: songRowItem.itemData.songname || ""
                songSinger: songRowItem.itemData.singername || ""
                songCover: songRowItem.itemData.union_cover || ""
                rowHovered: songRowHover.hovered
                compact: true
            }

            IconButton {
                visible: !songRowItem.togetherMode
                iconSource: AppIcon.playCircle
                size: 24
                iconSize: 14
                onClicked: songRowItem.activated(songRowItem.itemData)
            }

            IconButton {
                visible: songRowItem.togetherMode
                iconSource: AppIcon.addTogether
                size: 24
                iconSize: 14
                iconColor: hovered ? AppTheme.accent : AppTheme.iconDefault
                onClicked: songRowItem.activated(songRowItem.itemData)
            }
        }


        function contextSong() {
            return {
                "songname": itemData.songname || "",
                "songhash": itemData.songhash || "",
                "singername": itemData.singername || "",
                "union_cover": itemData.union_cover || "",
                "album_name": itemData.album_name || "",
                "duration": itemData.duration || "",
                "mvhash": itemData.mvhash || ""
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                if (actionHover.hovered || climaxPreviewBtn.active)
                    return
                songRowItem.activated(songRowItem.itemData)
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: BasicConfig.requestSongContextMenu(songRowItem.contextSong(), {
                "togetherMode": songRowItem.togetherMode,
                "showAi": false
            })
        }
    }
}
