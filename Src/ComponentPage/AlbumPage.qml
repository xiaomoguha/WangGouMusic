import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 专辑页：顶部专辑信息 + 歌曲列表（数据来自 albumManager，样式同歌单详情页）
Item {
    id: root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "AlbumPage"

    property string albumId: BasicConfig.albumId
    property string albumName: BasicConfig.albumName
    property string albumCover: BasicConfig.albumCover
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    // 封面主色 → 整窗渐变（机制同歌单详情页）
    property string coverColor: ""
    property string requestedCoverUrl: ""   // 本次请求的封面 URL：回调核对防串扰

    function syncWindowTint() {
        // 隐藏时不操作 BasicConfig：多个详情页同色时隐藏页误关会杀掉显示页的渐变；
        // 回首页由 Rightpage.hideOverlay 统一关闭。
        if (!root.visible)
            return
        if (root.coverColor !== "") {
            BasicConfig.playlistPageActive = true
            BasicConfig.playlistPageCoverColor = root.coverColor
        }
    }

    function requestCoverColor() {
        var cover = albumManager && albumManager.album ? albumManager.album.cover : albumCover
        if (!cover || cover === "") {
            requestedCoverUrl = ""
            coverColor = ""
            syncWindowTint()
            return
        }
        requestedCoverUrl = cover
        playlistColorExtractor.extract(cover)
    }

    onVisibleChanged: syncWindowTint()

    Connections {
        target: playlistColorExtractor
        // 只接受自己发起的请求结果（imageUrl 匹配），其他页面的结果不污染本页
        function onDominantColorReady(imageUrl, color) {
            if (imageUrl !== root.requestedCoverUrl)
                return
            root.coverColor = color
            root.syncWindowTint()
        }
    }

    Connections {
        target: albumManager
        function onAlbumChanged() {
            root.requestCoverColor()
        }
    }

    Component.onCompleted: {
        if (albumManager && albumId !== "")
            albumManager.fetchAlbum(albumId)
    }

    onAlbumIdChanged: {
        if (albumManager && albumId !== "")
            albumManager.fetchAlbum(albumId)
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ===== 顶部专辑信息 =====
        Rectangle {
            width: parent.width
            height: 168
            color: "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 30
                anchors.topMargin: 12
                spacing: 15

                // 返回按钮
                Rectangle {
                    id: backBtn
                    width: 36
                    height: 36
                    radius: 18
                    color: backHover.hovered ? (BasicConfig.playlistCoverColor !== "" ? "#1EFFFFFF" : AppTheme.bgCard) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: backIcon
                        anchors.centerIn: parent
                        source: AppIcon.back
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: backIcon
                            // 渐变时随背景挑白/深色，与全局返回键一致
                            color: BasicConfig.playlistCoverColor !== ""
                                ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                                : AppTheme.textPrimary
                        }
                    }
                    HoverHandler { id: backHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: BasicConfig.goBack()
                    }
                }

                // 专辑封面
                Image {
                    id: albumCoverImg
                    width: 120
                    height: 120
                    source: albumManager && albumManager.album ? albumManager.album.cover : albumCover
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize.width: 240
                    sourceSize.height: 240
                    fillMode: Image.PreserveAspectCrop
                    anchors.verticalCenter: parent.verticalCenter
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 120
                            height: 120
                            radius: 12
                        }
                    }
                }

                Column {
                    width: parent.width - 120 - backBtn.width - 45
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: albumManager && albumManager.album ? albumManager.album.name : albumName
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeHeadline
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    Text {
                        text: (albumManager && albumManager.album ? albumManager.album.author : "")
                              + (albumManager && albumManager.album && albumManager.album.language ? " · " + albumManager.album.language : "")
                              + (albumManager && albumManager.album && albumManager.album.publish_date ? " · " + albumManager.album.publish_date : "")
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }

                    Text {
                        text: albumManager && albumManager.album ? albumManager.album.intro : ""
                        width: parent.width
                        height: 34
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }

                    // 播放全部
                    Rectangle {
                        width: 100
                        height: 32
                        radius: 16
                        color: playAllHover.hovered ? "#533483" : "#e94560"
                        visible: !isTogetherMode

                        Text {
                            anchors.centerIn: parent
                            text: (albumManager && albumManager.isLoading && albumManager.songs.length === 0) ? "加载中..." : "▶ 播放全部"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                            font.family: AppTheme.fontFamily
                        }
                        HoverHandler { id: playAllHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (!albumManager || albumManager.songs.length === 0) return
                                playlistmanager.clearPlaylist()
                                for (var i = 0; i < albumManager.songs.length; i++) {
                                    var s = albumManager.songs[i]
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
                                BasicConfig.emitSongAdded("正在播放: " + (albumManager.album ? albumManager.album.name : albumName))
                            }
                        }
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }
                }
            }
        }

        // 分隔线
        Rectangle {
            width: parent.width - 60
            height: 1
            color: AppTheme.bgNavHover
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ===== 歌曲列表 =====
    ListView {
        id: songsList
        anchors.top: parent.top
        anchors.topMargin: 178
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        cacheBuffer: 2000
        model: albumManager ? albumManager.songs : []
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
            if (albumManager && !albumManager.isLoading && albumManager.hasMore
                && contentHeight > height && contentY >= contentHeight - height - 200) {
                albumManager.fetchMoreSongs()
            }
        }

        // 空状态 / 加载中
        Text {
            anchors.centerIn: parent
            visible: albumManager && albumManager.isLoading && albumManager.songs.length === 0
            text: "正在加载..."
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }

        delegate: Rectangle {
            width: songsList.width - 60
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

                // 操作按钮区（悬停显示；一起听模式只留「加入一起听」）
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
            // 整行点击 = 播放（一起听 = 加入一起听）；悬停在按钮区不触发
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
}
