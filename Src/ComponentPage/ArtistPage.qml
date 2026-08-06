import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

// 歌手页：顶部歌手信息 + 单曲/专辑 tab（数据来自 artistManager）
Item {
    id: root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "ArtistPage"


    property string artistId: BasicConfig.artistId
    property string artistName: BasicConfig.artistName
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    property bool showAlbums: false   // false=单曲 tab，true=专辑 tab

    // 歌手头像主色（hex，暂存用）。真正驱动渐变的是 BasicConfig.playlistCoverColor——
    // 渐变在主窗口根部，页面只负责同步（机制同歌单详情页）。
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

    // 请求头像主色（异步）。换歌手时不清空旧色，新色到达后平滑过渡。
    function requestCoverColor() {
        var avatar = artistManager && artistManager.artist ? artistManager.artist.avatar : ""
        if (!avatar || avatar === "") {
            requestedCoverUrl = ""
            coverColor = ""
            syncWindowTint()
            return
        }
        requestedCoverUrl = avatar
        playlistColorExtractor.extract(avatar)
    }

    // 页面被 Loader 池切走/切回时同步渐变显隐
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
        target: artistManager
        function onArtistChanged() {
            root.requestCoverColor()
        }
    }

    // 打开即拉数据（页面池复用，同歌手只拉一次由 C++ 侧 loading 拒绝）
    Component.onCompleted: {
        if (artistManager && artistId !== "")
            artistManager.fetchArtist(artistId)
    }

    onArtistIdChanged: {
        if (artistManager && artistId !== "")
            artistManager.fetchArtist(artistId)
    }

    // 粉丝数格式化：1.2万 / 2547万 / 1.3亿
    function formatCount(n) {
        if (n >= 100000000) return (n / 100000000).toFixed(1) + "亿"
        if (n >= 10000) return (n / 10000).toFixed(1) + "万"
        return String(n)
    }

    // ===== 顶部歌手信息 =====
    Rectangle {
        id: infoSection
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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

                // 歌手头像（图片未就绪时整块透明，不露占位灰圆）
                Rectangle {
                    width: 120
                    height: 120
                    radius: 60
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: artistAvatar.status === Image.Ready ? AppTheme.bgCard : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Image {
                        id: artistAvatar
                        anchors.fill: parent
                        source: artistManager && artistManager.artist ? artistManager.artist.avatar : ""
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(240, 240)
                        // 加载完成才淡入，避免头像还没到的时候露出占位圆
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    // 仅当歌手确实没有头像时显示名字首字（加载中不显示任何东西）
                    Text {
                        visible: artistManager && artistManager.artist && !artistManager.artist.avatar
                        anchors.centerIn: parent
                        text: artistManager.artist.name.charAt(0)
                        font.pixelSize: 40
                        font.bold: true
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                }

                Column {
                    width: parent.width - 120 - backBtn.width - 45
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: artistManager && artistManager.artist ? artistManager.artist.name : artistName
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 26
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    Row {
                        spacing: 16
                        // 浅色模式用更黑的灰保证可读，深色模式保持 muted
                        property color statColor: AppTheme.isDark ? AppTheme.textMuted : AppTheme.textSecondary
                        Text {
                            text: "粉丝 " + (artistManager && artistManager.artist ? root.formatCount(artistManager.artist.fans) : "—")
                            font.pixelSize: AppTheme.fontSizeSmall
                            color: parent.statColor
                            font.family: AppTheme.fontFamily
                        }
                        Text {
                            text: "单曲 " + (artistManager && artistManager.artist ? artistManager.artist.audioCount : "—")
                            font.pixelSize: AppTheme.fontSizeSmall
                            color: parent.statColor
                            font.family: AppTheme.fontFamily
                        }
                        Text {
                            text: "专辑 " + (artistManager && artistManager.artist ? artistManager.artist.albumCount : "—")
                            font.pixelSize: AppTheme.fontSizeSmall
                            color: parent.statColor
                            font.family: AppTheme.fontFamily
                        }
                    }

                    // 播放全部（加载全部单曲后播放）
                    Rectangle {
                        width: 110
                        height: 32
                        radius: 16
                        color: playAllHover.hovered ? "#533483" : "#e94560"
                        visible: !isTogetherMode

                        Text {
                            anchors.centerIn: parent
                            text: (artistManager && artistManager.isLoading && artistManager.songsModel.count === 0) ? "加载中..." : "▶ 播放全部"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                            font.family: AppTheme.fontFamily
                        }
                        HoverHandler { id: playAllHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (!artistManager || artistManager.songsModel.count === 0) return
                                playlistmanager.clearPlaylist()
                                for (var i = 0; i < artistManager.songsModel.count; i++) {
                                    var s = artistManager.songsModel.get(i)
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
                                BasicConfig.emitSongAdded("正在播放: " + (artistManager.artist ? artistManager.artist.name : artistName))
                            }
                        }
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }
                }
            }
        }

    // ===== tab：单曲 / 专辑 =====
    Row {
        id: tabRow
        anchors.top: infoSection.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        spacing: 10
        height: 30

        Rectangle {
            width: 60
            height: 30
            radius: 15
            color: !root.showAlbums ? AppTheme.accent : "transparent"

            Text {
                anchors.centerIn: parent
                text: "单曲"
                color: !root.showAlbums ? "#ffffff" : AppTheme.textMuted
                font.bold: true
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.showAlbums = false }
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }

        Rectangle {
            width: 60
            height: 30
            radius: 15
            color: root.showAlbums ? AppTheme.accent : "transparent"

            Text {
                anchors.centerIn: parent
                text: "专辑"
                color: root.showAlbums ? "#ffffff" : AppTheme.textMuted
                font.bold: true
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.showAlbums = true }
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }
    }

    // ===== 单曲列表 =====
    ListView {
        id: songsList
        visible: !root.showAlbums
        anchors.top: tabRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        clip: true
            cacheBuffer: 2000
            model: artistManager ? artistManager.songsModel : null
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
                if (artistManager && !artistManager.isLoading && artistManager.hasMoreSongs
                    && contentHeight > height && contentY >= contentHeight - height - 200) {
                    artistManager.fetchMoreSongs()
                }
            }

            // 滚动加载 footer：加载中显示旋转动画
            footer: Item {
                width: songsList.width
                height: 44
                visible: artistManager && artistManager.songsLoading

                Image {
                    id: songsLoadingIcon
                    anchors.centerIn: parent
                    source: AppIcon.refresh
                    sourceSize: Qt.size(48, 48)
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: songsLoadingIcon
                        color: AppTheme.textMuted
                    }
                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: artistManager && artistManager.songsLoading
                    }
                }

                Text {
                    anchors.left: parent.horizontalCenter
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: "正在加载..."
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textMuted
                }
            }

            delegate: Rectangle {
                id: songRow
                width: songsList.width - 60
                height: 60 + aiExpand.expandedHeight
                radius: 6
                color: "transparent"

                // QAbstractListModel：delegate 用 model.xxx 访问（modelData 失效）
                readonly property var songData: ({
                    "songname": model.songname,
                    "singername": model.singername,
                    "songhash": model.songhash,
                    "album_name": model.album_name,
                    "duration": model.duration,
                    "union_cover": model.union_cover
                })
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
                        width: isTogetherMode ? 70 : 138
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { id: actionHover }

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

                            // AI 推荐（点击展开/收回生成的 AI 歌单；有数据时切换为箭头）
                            IconButton {

                                iconSource: aiExpand.expanded ? AppIcon.caretDown

                                    : (aiExpand.aiSongs.length > 0 ? AppIcon.caretRight : AppIcon.sparkle)
                                size: 30
                                iconSize: 16
                                onClicked: {
                                    aiExpand.toggle(songData.songhash, songData.songname)
                                }
                            }

                            IconButton {
                                visible: !isTogetherMode && !isPlaying
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

    // ===== 专辑列表（主页精选歌单同款：2 列横向卡片） =====
    GridView {
        id: albumsGrid
        visible: root.showAlbums
        anchors.top: tabRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        clip: true
        cacheBuffer: 2000
        model: artistManager ? artistManager.albumsModel : null
        // cellWidth 按「可用宽」（减左右 margin）算，否则 floor 后放不下两个 cell 退成 1 列
        cellWidth: (width - leftMargin - rightMargin) / 2
        cellHeight: 100
        leftMargin: 30
        rightMargin: 30
        topMargin: 10

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
            if (artistManager && !artistManager.isLoading && artistManager.hasMoreAlbums
                && contentHeight > height && contentY >= contentHeight - height - 200) {
                artistManager.fetchMoreAlbums()
            }
        }

        // 滚动加载 footer：加载中显示旋转动画
        footer: Item {
            width: albumsGrid.width
            height: 44
            visible: artistManager && artistManager.albumsLoading

            Image {
                id: albumsLoadingIcon
                anchors.centerIn: parent
                source: AppIcon.refresh
                sourceSize: Qt.size(48, 48)
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: albumsLoadingIcon
                    color: AppTheme.textMuted
                }
                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: artistManager && artistManager.albumsLoading
                }
            }

            Text {
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                text: "正在加载..."
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
                color: AppTheme.textMuted
            }
        }

        // 卡片：80 封面在左 + 右侧专辑名/日期（与主页精选歌单完全一致）
        delegate: Item {
            width: albumsGrid.cellWidth - 10
            height: albumsGrid.cellHeight - 10

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 12

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Image {
                        id: albumCoverImg
                        width: 80
                        height: 80
                        source: model.cover
                        asynchronous: true
                        cache: true
                        sourceSize.width: 160
                        sourceSize.height: 160
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 80; height: 80; radius: 8 }
                        }
                    }

                    Column {
                        width: parent.width - 80 - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: model.album_name
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeBody
                            font.bold: true
                            // hover 专辑名高亮（网易云风格，同精选歌单）
                            color: albumHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                            font.family: AppTheme.fontFamily
                        }
                        // 专辑简介（2 行，同精选歌单 intro）
                        Text {
                            text: model.intro
                            width: parent.width
                            height: 32
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            font.pixelSize: AppTheme.fontSizeCaption
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }
                        Text {
                            text: model.publish_date
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeCaption
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }
                    }
                }
            }

            HoverHandler { id: albumHover }
            // 专辑点击 → 专辑页
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: BasicConfig.openAlbum(String(model.album_id), model.album_name, model.cover)
            }
        }
    }

    // 空状态 / 加载中
    Text {
        anchors.centerIn: parent
        visible: artistManager && artistManager.isLoading && artistManager.songsModel.count === 0
        text: "正在加载..."
        font.pixelSize: AppTheme.fontSizeBody
        color: AppTheme.textMuted
        font.family: AppTheme.fontFamily
    }
}
