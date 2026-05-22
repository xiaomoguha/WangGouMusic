import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    objectName: "HomePage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    /* ===================== 滚动容器 ===================== */
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

            // ========== Hero Banner ==========
            Rectangle {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 180
                radius: 16
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#1a1a2e" }
                    GradientStop { position: 0.5; color: "#16213e" }
                    GradientStop { position: 1.0; color: "#0f3460" }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "每日推荐"
                        font.pixelSize: 11
                        color: "#aaaacc"
                        font.family: "黑体"
                        font.bold: true
                    }
                    Text {
                        text: "发现你的专属旋律"
                        font.pixelSize: 26
                        color: "#ffffff"
                        font.bold: true
                        font.family: "黑体"
                    }
                    Text {
                        text: "精选音乐，为你的每一个时刻匹配最完美的声音"
                        font.pixelSize: 12
                        color: "#aaaacc"
                        font.family: "黑体"
                        width: 300
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: 100
                        height: 34
                        radius: 17
                        color: playAllBtnHover.hovered ? "#533483" : "#e94560"

                        Text {
                            anchors.centerIn: parent
                            text: "▶ 立即播放"
                            font.pixelSize: 13
                            color: "#ffffff"
                            font.family: "黑体"
                            font.bold: true
                        }

                        HoverHandler { id: playAllBtnHover }

                        TapHandler {
                            cursorShape: Qt.PointingCursor
                            onTapped: {
                                var songs = recommendation ? recommendation.topSongsQml : []
                                if (songs.length > 0) {
                                    playlistmanager.clearPlaylist()
                                    for (var i = 0; i < songs.length; i++) {
                                        var s = songs[i]
                                        playlistmanager.addSong(s.songname, s.songhash, s.singername, s.union_cover, s.album_name, s.duration)
                                    }
                                    playlistmanager.playSongbyindex(0)
                                    BasicConfig.emitSongAdded("正在播放热门推荐")
                                }
                            }
                        }

                        Behavior on color { ColorAnimation { duration: 150 } }
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
                        font.pixelSize: 18
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: "黑体"
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
                            source: "qrc:/image/shuaxin.png"
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
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
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        SequentialAnimation {
                            id: playlistRefreshAnim
                            NumberAnimation { target: playlistsGrid; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                            NumberAnimation { target: playlistsGrid; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            width: playlistsGrid.cellWidth - 10
                            height: playlistsGrid.cellHeight - 10

                            property var plData: modelData

                            Rectangle {
                                anchors.fill: parent
                                color: plHover.hovered ? AppTheme.bgCard : "transparent"
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
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: AppTheme.textPrimary
                                            font.family: "黑体"
                                        }
                                        Text {
                                            text: plData.intro
                                            width: parent.width
                                            height: 32
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            font.pixelSize: 11
                                            color: AppTheme.textMuted
                                            font.family: "黑体"
                                        }
                                        Row {
                                            spacing: 8
                                            Text {
                                                text: (plData.play_count / 10000).toFixed(1) + "万播放"
                                                font.pixelSize: 10
                                                color: AppTheme.textMuted
                                                font.family: "黑体"
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
                                                    font.pixelSize: 10
                                                    color: AppTheme.textMuted
                                                    anchors.centerIn: parent
                                                    font.family: "黑体"
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

            // ========== 热门推荐 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Text {
                    text: "✦ 热门推荐"
                    font.pixelSize: 18
                    font.bold: true
                    color: AppTheme.textPrimary
                    font.family: "黑体"
                }

                GridView {
                    id: songsGrid
                    width: parent.width
                    height: contentHeight
                    cellWidth: width / 6
                    cellHeight: cellWidth + 50
                    interactive: false
                    model: recommendation ? recommendation.topSongsQml : []

                    delegate: Item {
                        width: songsGrid.cellWidth - 6
                        height: songsGrid.cellHeight - 6

                        property var songData: modelData
                        readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

                        Rectangle {
                            anchors.fill: parent
                            color: songCardHover.hovered ? AppTheme.bgCard : "transparent"
                            radius: 12

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    width: parent.width
                                    height: width
                                    radius: 10
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: songData.union_cover
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 300
                                        sourceSize.height: 300
                                        fillMode: Image.PreserveAspectCrop
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#40000000"
                                        visible: songCardHover.hovered || isPlaying
                                        radius: 10

                                        AnimatedImage {
                                            anchors.centerIn: parent
                                            source: "qrc:/image/isplaying.gif"
                                            width: 32
                                            height: 32
                                            playing: isPlaying
                                            visible: isPlaying
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            source: "qrc:/image/playnow.png"
                                            width: 32
                                            height: 32
                                            fillMode: Image.PreserveAspectFit
                                            visible: !isPlaying && songCardHover.hovered
                                        }
                                    }
                                }

                                Text {
                                    text: songData.songname
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    color: isPlaying ? AppTheme.accentPlaying : AppTheme.textPrimary
                                    font.family: "黑体"
                                }

                                Text {
                                    text: songData.singername
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                    color: AppTheme.textMuted
                                    font.family: "黑体"
                                }
                            }

                            HoverHandler { id: songCardHover }

                            TapHandler {
                                cursorShape: Qt.PointingCursor
                                onTapped: {
                                    playlistmanager.addandplay(songData.songname, songData.songhash,
                                                               songData.singername, songData.union_cover,
                                                               songData.album_name, songData.duration)
                                    BasicConfig.emitSongAdded("正在播放: " + songData.songname)
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
