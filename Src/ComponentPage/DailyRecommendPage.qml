import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    id: root
    objectName: "DailyRecommendPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    Component.onCompleted: {
        if (dailyRecommend && dailyRecommend.songs.length === 0)
            dailyRecommend.fetch()
    }

    // 播放全部（直接播每日推荐列表）
    function playAll() {
        var songs = dailyRecommend ? dailyRecommend.songs : []
        if (songs.length === 0) return
        playlistmanager.clearPlaylist()
        for (var i = 0; i < songs.length; i++) {
            var s = songs[i]
            playlistmanager.addSong({
                "songname": s.songname,
                "songhash": s.songhash,
                "singername": s.singername,
                "union_cover": s.union_cover,
                "album_name": s.album_name,
                "duration": s.duration
            })
        }
        playlistmanager.playSongbyindex(0)
        BasicConfig.emitSongAdded("正在播放: 每日推荐")
    }

    Flickable {
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
            spacing: 24
            leftPadding: width * 0.04
            rightPadding: width * 0.04

            Item { width: 1; height: 5 }

            // ========== 头部：封面 + 标题 + 播放全部 ==========
            Row {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 20

                Rectangle {
                    width: 150
                    height: 150
                    radius: 14
                    clip: true
                    color: AppTheme.bgCard

                    Image {
                        anchors.fill: parent
                        source: dailyRecommend ? dailyRecommend.coverUrl : ""
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 150; height: 150; radius: 14 }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "每日推荐"
                        font.pixelSize: AppTheme.fontSizeHeadline
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    Text {
                        text: {
                            var d = dailyRecommend ? dailyRecommend.date : ""
                            if (d.length === 8)
                                return d.slice(0,4) + "-" + d.slice(4,6) + "-" + d.slice(6,8) + " · 每天为你精选好歌"
                            return "每天为你精选好歌"
                        }
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }

                    // 播放全部
                    Rectangle {
                        width: 120
                        height: 34
                        radius: 17
                        color: playAllHover.hovered ? "#533483" : "#e94560"
                        visible: !isTogetherMode
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: (dailyRecommend && dailyRecommend.isLoading) ? "加载中..." : "▶ 播放全部"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                            font.family: AppTheme.fontFamily
                        }
                        HoverHandler { id: playAllHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            enabled: dailyRecommend && !dailyRecommend.isLoading
                            onTapped: root.playAll()
                        }
                    }
                }
            }

            // ========== 推荐歌曲列表 ==========
            ListView {
                id: songsList
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: contentHeight
                interactive: false
                model: dailyRecommend ? dailyRecommend.songs : []
                spacing: 2

                delegate: Rectangle {
                    width: songsList.width
                    height: 60
                    radius: 6
                    color: "transparent"

                    readonly property var songData: modelData
                    readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

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
                            width: 0.3 * songsList.width
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

                        // 操作按钮区（固定占位，悬停时显示；一起听模式只留「加入一起听」）
                        Item {
                            id: actionArea
                            width: isTogetherMode ? 34 : 108
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            HoverHandler { id: actionHover }

                            Row {
                                anchors.fill: parent
                                spacing: 4
                                visible: songHover.hovered && !isPlaying

                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.playCircle
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
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

                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.addToList
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
                                        playlistmanager.addSongNext({
                                            "songname": songData.songname,
                                            "songhash": songData.songhash,
                                            "singername": songData.singername,
                                            "union_cover": songData.union_cover,
                                            "album_name": songData.album_name,
                                            "duration": songData.duration
                                        })
                                        BasicConfig.emitSongAdded("已添加到下一首: " + songData.songname)
                                    }
                                }

                                // 收藏到「我喜欢」
                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.heart
                                    iconColor: AppTheme.textSecondary
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
                                        if (!userManager || !userManager.isLoggedIn) {
                                            BasicConfig.noticeError("请先登录")
                                            return
                                        }
                                        playlistCollection.addToFavorite(songData.songname, songData.songhash, songData.singername)
                                    }
                                }

                                // 加入一起听
                                IconButton {
                                    visible: isTogetherMode
                                    iconSource: AppIcon.addTogether
                                    size: 30
                                    iconSize: 16
                                    onClicked: websocket.addSongToTogether(songData.songname, songData.songhash,
                                                                           songData.singername, songData.album_name,
                                                                           songData.duration, songData.union_cover)
                                }
                            }
                        }

                        // 专辑名（与歌单详情一致的列）
                        Text {
                            text: songData.album_name
                            width: 0.2 * songsList.width
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

                    HoverHandler { id: songHover }
                    // 整行点击 = 播放该曲（一起听模式 = 加入一起听）；
                    // 悬停在操作按钮区时不触发，避免与按钮点击重复
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (actionHover.hovered) return
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

            // 空状态 / 加载失败
            EmptyState {
                visible: !dailyRecommend || dailyRecommend.songs.length === 0
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 240
                iconText: "☀"
                title: dailyRecommend && dailyRecommend.isLoading ? "正在加载每日推荐..." : "每日推荐加载失败"
                subtitle: dailyRecommend && dailyRecommend.isLoading ? "" : "点击重试"
                buttonText: dailyRecommend && dailyRecommend.isLoading ? "" : "重新加载"
                onButtonClicked: {
                    if (dailyRecommend)
                        dailyRecommend.fetch()
                }
            }

            Item { width: 1; height: 20 }
        }
    }
}
