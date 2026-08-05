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

    // 随机榜单歌曲 → 注入热门推荐区
    Connections {
        target: rankList
        function onRandomSongsReady(list) {
            if (recommendation)
                recommendation.showRankSongs(list)
        }
    }

    Component.onCompleted: {
        // 首次进首页拉一批 FM（已拉过则不重复请求）
        if (personalFM && personalFM.songs.length === 0 && !personalFM.isLoading)
            personalFM.fetch()
    }

    // ===================== 个人 FM =====================
    // 原独立 FM 页合并进首页：播放全部进入 FM 模式（播到批末自动续批并追加），
    // 换一批手动切新批。未播放时仅展示当前批。
    property bool fmPlaying: false
    property bool _autoFetched: false

    // 播放全部（FM 批入队播放；播到批末自动续批）
    function fmPlayAll() {
        var songs = personalFM ? personalFM.songs : []
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
        root.fmPlaying = true
        BasicConfig.emitSongAdded("开始播放个人FM")
    }

    // 切下一批（手动「换一批」或播到批末自动触发）
    function fmFetchNext() {
        console.log("[HomePage] fmFetchNext, isLoading:", personalFM ? personalFM.isLoading : "no obj")
        if (personalFM && !personalFM.isLoading)
            personalFM.fetchNext()
    }

    // 播放队列跳到当前批最后一首 → 预取下一批（播完即续）
    Connections {
        target: playlistmanager
        function onCurrentSongChanged() {
            if (!root.fmPlaying) return
            var songs = personalFM ? personalFM.songs : []
            if (songs.length < 2) return
            var lastHash = songs[songs.length - 1].songhash
            if (playlistmanager.currentSonghash === lastHash && !root._autoFetched) {
                root._autoFetched = true
                root.fmFetchNext()
            } else if (playlistmanager.currentSonghash !== lastHash) {
                root._autoFetched = false
            }
        }
    }

    // 新一批到达：FM 模式下追加到播放队列末尾（播完批末自动接上新批）
    Connections {
        target: personalFM
        function onSongsChanged() {
            if (!root.fmPlaying) return
            var songs = personalFM.songs
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
            root._autoFetched = false
        }
    }

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

            // ========== 个人 FM ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Row {
                    spacing: 6

                    Text {
                        text: "✦ 个人FM"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    // 换一批（请求期间图标持续旋转；FM 模式下播放队列自动接上）
                    SectionRefreshButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -3
                        busy: personalFM && personalFM.isLoading
                        onClicked: root.fmFetchNext()
                    }
                }

                Row {
                    spacing: 12
                    visible: !isTogetherMode

                    // 播放全部
                    Rectangle {
                        width: 100
                        height: 32
                        radius: 16
                        color: fmPlayAllHover.hovered ? "#533483" : "#e94560"
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: (personalFM && personalFM.isLoading && personalFM.songs.length === 0)
                                  ? "加载中..." : "▶ 播放全部"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: "#ffffff"
                            font.family: AppTheme.fontFamily
                        }
                        HoverHandler { id: fmPlayAllHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            enabled: personalFM && !personalFM.isLoading
                            onTapped: root.fmPlayAll()
                        }
                    }
                }

                // 横向歌曲卡片（当前批）
                ListView {
                    id: fmList
                    width: parent.width
                    height: 180
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    model: personalFM ? personalFM.songs : []

                    ScrollBar.horizontal: ScrollBar {
                        height: 4
                        anchors.bottom: parent.bottom
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            visible: parent.active
                            height: 4
                            radius: 2
                            color: AppTheme.scrollbarColor
                        }
                    }

                    delegate: Item {
                        width: 130
                        height: 180

                        readonly property var songData: modelData
                        readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

                        Column {
                            anchors.fill: parent
                            spacing: 6

                            // FM 接口无封面：用主题渐变占位封面（不同卡片不同色系），
                            // 中间大号 ♪，hover/播放时压暗 + 动态图
                            Rectangle {
                                id: fmCoverCard
                                width: 130
                                height: 130
                                radius: 12
                                clip: true

                                // 渐变色板：按卡片序号循环取一对
                                readonly property var palette: [
                                    ["#FF6B6B", "#EE5A24"], ["#54A0FF", "#2E86DE"],
                                    ["#5F27CD", "#341F97"], ["#1DD1A1", "#10AC84"],
                                    ["#FECA57", "#F39C12"], ["#00D2D3", "#01A3A4"]
                                ]

                                LinearGradient {
                                    anchors.fill: parent
                                    start: Qt.vector2d(0, 0)
                                    end: Qt.vector2d(parent.width, parent.height)
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: fmCoverCard.palette[index % 6][0] }
                                        GradientStop { position: 1.0; color: fmCoverCard.palette[index % 6][1] }
                                    }
                                }

                                // 专辑封面（C++ 按 album_id 补全后显示；无图时渐变兜底）
                                Image {
                                    anchors.fill: parent
                                    source: songData.union_cover || ""
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 260
                                    sourceSize.height: 260
                                    fillMode: Image.PreserveAspectCrop
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    font.pixelSize: 52
                                    color: "#59FFFFFF"
                                    font.family: AppTheme.fontFamily
                                    visible: !songData.union_cover
                                }

                                // 卡片序号角标（像专辑封面编号）
                                Text {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    text: (index + 1).toString().padStart(2, "0")
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.bold: true
                                    color: "#59FFFFFF"
                                    font.family: AppTheme.fontFamily
                                }

                                // hover/播放时深色压暗层
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#40000000"
                                    visible: fmCardHover.hovered || isPlaying

                                    NowPlayingIndicator {
                                        anchors.centerIn: parent
                                        visible: isPlaying
                                        playing: playlistmanager ? !playlistmanager.isPaused : true
                                    }

                                    Image {
                                        id: fmPlayIcon
                                        anchors.centerIn: parent
                                        // 一起听模式下图标换成「加入一起听」，点击行为已由 TapHandler 区分
                                        source: isTogetherMode ? AppIcon.addTogether : AppIcon.playCircle
                                        width: 32
                                        height: 32
                                        fillMode: Image.PreserveAspectFit
                                        visible: !isPlaying && fmCardHover.hovered
                                        sourceSize: Qt.size(128, 128)
                                        mipmap: true
                                        layer.enabled: true
                                        // 遮罩是深色压暗，播放按钮一律用白色（浅色主题下也清晰）
                                        layer.effect: ColorOverlay {
                                            source: fmPlayIcon
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }

                            Text {
                                text: songData.songname
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.bold: true
                                color: (isPlaying || fmCardHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
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

                        HoverHandler { id: fmCardHover }
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

                // FM 空状态（加载失败时重试）
                EmptyState {
                    visible: personalFM && personalFM.songs.length === 0
                    width: parent.width
                    height: 160
                    iconText: "♪"
                    title: personalFM && personalFM.isLoading ? "正在加载个人FM..." : "个人FM加载失败"
                    subtitle: personalFM && personalFM.isLoading ? "" : "点击重试"
                    buttonText: personalFM && personalFM.isLoading ? "" : "重新加载"
                    onButtonClicked: {
                        if (personalFM)
                            personalFM.fetch()
                    }
                }
            }

            // ========== 热门推荐 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 12

                Row {
                    spacing: 6

                    Text {
                        text: "✦ 热门推荐"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
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
                                    // 横版圆角矩形封面（高 = 宽 × 3/4，圆角与 FM 卡片视觉统一）
                                    height: width * 3 / 4
                                    radius: 10
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
                                                radius: 10
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
                                            playing: playlistmanager ? !playlistmanager.isPaused : true
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

                    Text {
                        text: "↑ 精选歌单"
                        font.pixelSize: AppTheme.fontSizeTitleLg
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
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
}
