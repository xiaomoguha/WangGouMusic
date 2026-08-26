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

    // 封面主色（hex，暂存用；空 = 未就绪/无封面）。真正驱动渐变的是
    // BasicConfig.playlistCoverColor——渐变在主窗口根部，页面只负责同步。
    property string coverColor: ""
    property string requestedCoverUrl: ""   // 本次请求的封面 URL：回调核对防串扰

    // 把当前颜色同步到窗口级：仅当本页处于显示状态时生效。
    function syncWindowTint() {
        if (!root.visible)
            return
        if (root.coverColor !== "") {
            BasicConfig.playlistPageActive = true
            BasicConfig.playlistPageCoverColor = root.coverColor
        }
    }

    // 请求封面主色（异步）。每日推荐封面来自网络，数据到达后才提取。
    function requestCoverColor() {
        var cover = dailyRecommend ? dailyRecommend.coverUrl : ""
        if (!cover || cover === "")
            return
        requestedCoverUrl = cover
        playlistColorExtractor.extract(cover)
    }

    onVisibleChanged: {
        syncWindowTint()
        // 可见且尚无颜色时，若数据已就绪（非首进），补提取一次
        if (root.visible && root.coverColor === "")
            requestCoverColor()
    }

    Connections {
        target: playlistColorExtractor
        // 只接受自己发起的请求结果（imageUrl 匹配），其他页面的结果不污染本页
        function onDominantColorReady(imageUrl, color) {
            if (imageUrl !== root.requestedCoverUrl)
                return
            coverColor = color
            syncWindowTint()
        }
    }

    // 数据加载完成（coverUrl 随 songsChanged 一起 emit）后提取封面主色
    Connections {
        target: dailyRecommend
        function onSongsChanged() {
            requestCoverColor()
        }
    }

    function refreshDaily() {
        if (dailyRecommend) dailyRecommend.fetch()
    }

    Component.onCompleted: {
        if (dailyRecommend && dailyRecommend.songs.length === 0)
            refreshDaily()
        else
            requestCoverColor()
    }

    // 播放全部 / 从指定下标播放：把整个每日推荐列表载入播放列表（双击切歌用）
    function playListFromIndex(startIndex) {
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
        playlistmanager.playSongbyindex(Math.max(0, Math.min(startIndex, songs.length - 1)))
        BasicConfig.emitSongAdded("已切换播放列表: 每日推荐")
    }
    function playAll() {
        playListFromIndex(0)
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

                    RetryImage {
                        anchors.fill: parent
                        coverSource: dailyRecommend ? dailyRecommend.coverUrl : ""
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

                        RetryImage {
                            width: 40
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            coverSource: songData.union_cover
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
                    // 整行双击 = 载入整个每日推荐列表并从该曲开始播放（同「我喜欢」歌单页交互）。
                    // 普通模式单击不动作：此前单击直接播放 + 双击载列表，一次双击会
                    // 打出「2 次单击播放 + 1 次双击」共 3 次 /song/url 请求
                    // 一起听模式保留单击 = 把歌曲加入房间
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onTapped: {
                            if (!isTogetherMode) return
                            if (actionHover.hovered) return
                            if (websocket) {
                                websocket.addSongToTogether(songData.songname, songData.songhash,
                                    songData.singername, songData.album_name,
                                    songData.duration, songData.union_cover)
                            }
                        }
                        onDoubleTapped: {
                            if (isTogetherMode) return
                            root.playListFromIndex(index)
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
                    refreshDaily()
                }
            }

            Item { width: 1; height: 20 }
        }
    }
}
