import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    id: root
    objectName: "PlaylistDetailPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string playlistId: BasicConfig.playlistDetailId
    property string playlistName: BasicConfig.playlistDetailName
    property string playlistCover: BasicConfig.playlistDetailCover
    property string playlistIntro: BasicConfig.playlistDetailIntro
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    // ── 收藏状态 ──
    // 我的歌单列表（含创建与收藏）：收藏按钮/移除按钮的状态依据
    property var myPlaylists: []
    // 当前歌单是不是我自己创建的（global_collection_id 命中我的歌单）
    readonly property bool isMyOwnPlaylist: findPlaylistItem("global_collection_id") !== null
    // 当前歌单是否已收藏（list_create_gid 命中我的歌单 = 我收藏的别人歌单）
    readonly property bool isCollected: findPlaylistItem("list_create_gid") !== null
    // 我自己歌单的 listid（移除歌曲用）
    readonly property string myOwnListid: {
        var item = findPlaylistItem("global_collection_id")
        return item ? String(item.listid) : ""
    }

    // 在 myPlaylists 中按字段找匹配当前歌单的项（global_collection_id = 我创建的；list_create_gid = 我收藏的）
    function findPlaylistItem(field) {
        if (!playlistId) return null
        for (var i = 0; i < myPlaylists.length; i++) {
            if (myPlaylists[i][field] === playlistId)
                return myPlaylists[i]
        }
        return null
    }

    // 初始化/刷新我的歌单列表（缓存优先，登录后拉取）
    function refreshMyPlaylists() {
        var cached = userManager.loadCachedPlaylists()
        var listData = cached ? (cached["data"] || cached) : null
        myPlaylists = (listData && listData.info) ? listData.info.slice(0) : []
        if (myPlaylists.length === 0 && userManager.isLoggedIn)
            userManager.fetchUserPlaylist(1, 30)
    }

    // ── 收藏歌曲到歌单（弹选择器）──
    property var pendingCollectSong: null   // 待收藏歌曲（map: songname/songhash/...）

    function openCollectDialog(songname, songhash, singername, album_name) {
        if (!userManager.isLoggedIn) {
            BasicConfig.noticeError("请先登录")
            return
        }
        pendingCollectSong = {
            "songname": songname,
            "songhash": songhash,
            "singername": singername || "",
            "album_name": album_name || ""
        }
        collectPopup.currentSongName = songname
        if (root.myPlaylists.length === 0)
            userManager.fetchUserPlaylist(1, 30)
        collectPopup.open()
    }

    // 收藏 / 取消收藏当前歌单
    function toggleCollect() {
        if (!userManager.isLoggedIn) {
            BasicConfig.noticeError("请先登录")
            return
        }
        if (playlistCollection.isWorking) return
        if (isCollected) {
            var mine = findPlaylistItem("list_create_gid")
            playlistCollection.uncollectPlaylist(String(mine.listid))
        } else {
            playlistCollection.collectPlaylist(
                playlistName,
                playlistCollection.createUserIdFromGid(playlistId),
                playlistCollection.createListIdFromGid(playlistId),
                playlistId
            )
        }
    }

    // 歌单封面主色（hex，暂存用；空 = 未就绪/无封面）。真正驱动渐变的是
    // BasicConfig.playlistCoverColor——渐变在主窗口根部，页面只负责同步。
    property string coverColor: ""

    // 把当前颜色同步到窗口级：仅当本页处于显示状态时生效。
    // 最终生效色由 BasicConfig.playlistCoverColor 集中计算（歌单页优先于播放歌曲）。
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

    // 请求封面主色（异步）。切换歌单时**不清空**旧色：旧色保留到新色到达，
    // GradientStop 的 Behavior 直接平滑过渡到新色，避免渐变闪空再淡入。
    function requestCoverColor() {
        if (!playlistCover || playlistCover === "") {
            coverColor = ""
            syncWindowTint()
            return
        }
        playlistColorExtractor.extract(playlistCover)
    }

    // 页面被 Loader 池切走/切回时同步渐变显隐
    onVisibleChanged: syncWindowTint()

    Connections {
        target: playlistColorExtractor
        function onDominantColorReady(color) {
            coverColor = color
            syncWindowTint()
        }
    }

    property bool _pendingPlayAll: false
    property int currentSongIndex: -1        // 当前播放在列表中的下标，-1 = 不在
    property bool _autoLocated: false        // 是否已自动定位过一次
    property string _lastLoadedGid: ""       // 已拉取过的歌单 gid（可见时兜底拉取去重）
    readonly property bool pageActive: parent && parent.visible && opacity > 0

    Component.onCompleted: {
        console.log("[PlaylistDetailPage] onCompleted, playlistId:", playlistId)
        if (recommendation && playlistId !== "")
            recommendation.fetchPlaylistTracks(playlistId)
        requestCoverColor()
        refreshMyPlaylists()
    }

    // 调试探针：Timer 在组件创建时也会启动。
    // 若 onCompleted 不执行而 Timer 执行 → 组件创建被某绑定抛错中断；
    // 若两者都不执行 → 页面加载的并非本文件。
    Timer {
        running: true
        interval: 400
        repeat: false
        onTriggered: {
            console.log("[DBG] PlaylistDetailPage timer fired, playlistId:",
                        root.playlistId,
                        "model count:", recommendation ? recommendation.playlistTracksModel.count : -1)
        }
    }

    // Loader 池复用实例时 onCompleted 只跑一次；每次页面变为可见且歌单变化时兜底拉取，
    // 避免切歌单时 playlistDetailId 信号错过或实例复用导致列表空白
    onPageActiveChanged: {
        if (!pageActive || !recommendation || playlistId === "")
            return
        if (root._lastLoadedGid !== playlistId) {
            root._lastLoadedGid = playlistId
            console.log("[PlaylistDetailPage] pageActive, fetch gid:", playlistId)
            recommendation.fetchPlaylistTracks(playlistId)
            requestCoverColor()
        }
    }

    // 收藏结果提示 + 刷新列表（新增的收藏项出现在我的歌单里）
    Connections {
        target: playlistCollection
        function onOperationFinished(success, message) {
            if (success) {
                BasicConfig.noticeSuccess(message)
                refreshMyPlaylists()
                userManager.fetchUserPlaylist(1, 30)
            } else {
                BasicConfig.noticeError(message)
            }
        }
    }

    // 用户歌单数据变化（登录/收藏后刷新）→ 更新本地列表
    Connections {
        target: userManager
        function onUserPlaylistReceived(data) {
            var listData = data["data"] || data
            if (listData && listData.info)
                myPlaylists = listData.info.slice(0)
        }
    }

    // 计算当前播放在当前列表中的下标
    function recomputeCurrentSongIndex() {
        currentSongIndex = -1
        if (!playlistmanager) return
        var csh = playlistmanager.currentSonghash
        if (!csh) return
        var list = recommendation ? recommendation.playlistTracksModel : null
        if (!list) return
        for (var i = 0; i < list.count; i++) {
            if (list.get(i).songhash === csh) { currentSongIndex = i; break }
        }
    }

    // 当前播放变化时重算下标（驱动浮动按钮显隐），但不自动滚动
    Connections {
        target: playlistmanager
        function onCurrentSongChanged() { recomputeCurrentSongIndex() }
    }

    // 歌单详情页会被 Rightpage 的 Loader 缓存复用，切换不同歌单时
    // Component.onCompleted 不会再次触发，因此监听 id 变化重新拉取歌曲列表
    Connections {
        target: BasicConfig
        function onPlaylistDetailIdChanged() {
            console.log("[PlaylistDetailPage] id changed to:", playlistId)
            if (recommendation && playlistId !== "") {
                tracksListView.contentY = 0
                _pendingPlayAll = false
                _autoLocated = false
                currentSongIndex = -1
                recommendation.fetchPlaylistTracks(playlistId)
                requestCoverColor()
            }
        }
    }


    // 监听后端歌曲列表变化：全量加载完成后执行播放全部
    Connections {
        target: recommendation
        function onPlaylistTracksChanged() {
            if (!recommendation || !pageActive) return
            recomputeCurrentSongIndex()
            // 首次数据到达且用户未滚动时，自动定位到当前播放（仅一次）
            if (!_autoLocated && tracksListView.contentY < 10 && currentSongIndex >= 0) {
                _autoLocated = true
                tracksListView.positionViewAtIndex(currentSongIndex, ListView.Contain)
            }
            // 全量加载完成（hasMore=false）
            if (!recommendation.playlistHasMore) {
                // 播放全部触发的全量
                if (_pendingPlayAll) {
                    _pendingPlayAll = false
                    var songs = recommendation.playlistTracksModel
                    if (songs.count > 0) {
                        playlistmanager.clearPlaylist()
                        for (var i = 0; i < songs.count; i++) {
                            var s = songs.get(i)
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
                        BasicConfig.emitSongAdded("正在播放: " + playlistName)
                    }
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // 顶部：返回按钮 + 歌单信息
        Rectangle {
            width: parent.width
            height: 150
            color: "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 30
                anchors.topMargin: 10
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

                // 刷新歌单（重新拉取歌曲列表）
                SectionRefreshButton {
                    anchors.verticalCenter: parent.verticalCenter
                    busy: recommendation && recommendation.playlistIsLoading
                    onClicked: {
                        if (recommendation && playlistId !== "") {
                            recommendation.fetchPlaylistTracks(playlistId)
                            root.requestCoverColor()
                        }
                    }
                }

                Image {
                    id: coverImg
                    width: 110
                    height: 110
                    source: playlistCover
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize.width: 220
                    sourceSize.height: 220
                    fillMode: Image.PreserveAspectCrop
                    anchors.verticalCenter: parent.verticalCenter
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 110
                            height: 110
                            radius: 12
                        }
                    }
                }

                Column {
                    width: parent.width - coverImg.width - backBtn.width - 65
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: playlistName
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeHeadline
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }

                    Text {
                        text: playlistIntro
                        width: parent.width
                        height: 40
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }

                    // 播放全部 + 收藏
                    Row {
                        spacing: 12
                        visible: !isTogetherMode

                        Rectangle {
                            width: 100
                            height: 32
                            radius: 16
                            color: playAllHover.hovered ? "#533483" : "#e94560"

                            Text {
                                anchors.centerIn: parent
                                text: (recommendation && recommendation.playlistIsLoading) ? "加载中..." : "▶ 播放全部"
                                font.pixelSize: AppTheme.fontSizeSmall
                                color: "#ffffff"
                                font.family: AppTheme.fontFamily
                                font.bold: true
                            }

                            HoverHandler { id: playAllHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                enabled: recommendation && !recommendation.playlistIsLoading
                                onTapped: {
                                    if (!recommendation) return
                                    var songs = recommendation.playlistTracksModel
                                    if (recommendation.playlistHasMore) {
                                        _pendingPlayAll = true
                                        recommendation.loadAllPlaylistTracks()
                                        return
                                    }
                                    if (songs.count > 0) {
                                        playlistmanager.clearPlaylist()
                                        for (var i = 0; i < songs.count; i++) {
                                            var s = songs.get(i)
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
                                        BasicConfig.emitSongAdded("正在播放: " + playlistName)
                                    }
                                }
                            }
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                        }

                        // 收藏歌单（自己创建的歌单不显示，无收藏意义）
                        Rectangle {
                            visible: !root.isMyOwnPlaylist
                            width: 90
                            height: 32
                            radius: 16
                            color: collectHover.hovered ? (root.isCollected ? "#3a3a3a" : "#533483") : (root.isCollected ? AppTheme.bgNavHover : "#e94560")

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: root.isCollected ? "★" : "☆"
                                    font.pixelSize: AppTheme.fontSizeBodyLg
                                    color: root.isCollected ? AppTheme.textPrimary : "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.isCollected ? "已收藏" : "收藏歌单"
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    color: root.isCollected ? AppTheme.textPrimary : "#ffffff"
                                    font.family: AppTheme.fontFamily
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            HoverHandler { id: collectHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                enabled: !playlistCollection.isWorking
                                onTapped: root.toggleCollect()
                            }
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                        }
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

    // 右下角浮动「定位到正在播放」按钮（当前歌不在视口内时出现）
    LocateCurrentButton {
        target: tracksListView
        currentSongIndex: parent.currentSongIndex
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        z: 10
    }

    // 歌曲列表
    ListView {
        id: tracksListView
        anchors.top: parent.top
        anchors.topMargin: 170
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        cacheBuffer: 2000
        // 显示全部已加载歌曲
        model: recommendation ? recommendation.playlistTracksModel : null
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

        // 滚动到底加载下一页
        onContentYChanged: {
            if (recommendation && !recommendation.playlistIsLoading
                && recommendation.playlistHasMore
                && contentHeight > height
                && contentY >= contentHeight - height - 200) {
                recommendation.fetchMorePlaylistTracks()
            }
        }

        delegate: Rectangle {
            width: tracksListView.width - 60
            height: 60
            x: 30
            radius: 5
            // hover/播放改为文字高亮（背景透明，渐变下无块状覆盖层）
            color: "transparent"

            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === model.songhash

                    Row {
                        id: mainRow
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
                                maskSource: Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 6
                                }
                            }
                        }

                        Column {
                            width: 0.3 * tracksListView.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: model.title
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBody
                                font.bold: true
                                // hover 歌曲名高亮（网易云风格），播放行保持主题色
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

                        // 操作按钮区（固定宽度占位，悬停时显示；时长始终可见，不再被覆盖）
                        Item {
                            width: isTogetherMode ? 34 : 108
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

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
                                            "songname": model.title,
                                            "songhash": model.songhash,
                                            "singername": model.singername,
                                            "union_cover": model.union_cover,
                                            "album_name": model.album_name,
                                            "duration": model.duration
                                        })
                                        BasicConfig.emitSongAdded("正在播放: " + model.title)
                                    }
                                }

                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.addToList
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
                                        playlistmanager.addSongNext({
                                            "songname": model.title,
                                            "songhash": model.songhash,
                                            "singername": model.singername,
                                            "union_cover": model.union_cover,
                                            "album_name": model.album_name,
                                            "duration": model.duration
                                        })
                                        BasicConfig.emitSongAdded("已添加到下一首: " + model.title)
                                    }
                                }

                                // 收藏到歌单（弹出歌单选择器）
                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.heart
                                    iconColor: AppTheme.textSecondary
                                    size: 30
                                    iconSize: 16
                                    onClicked: root.openCollectDialog(model.title, model.songhash,
                                                                       model.singername, model.album_name)
                                }

                                // 从歌单移除（仅自己创建的歌单显示）
                                IconButton {
                                    visible: !isTogetherMode && root.isMyOwnPlaylist
                                    iconSource: AppIcon.deleteIcon
                                    iconColor: AppTheme.textSecondary
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
                                        if (!playlistCollection.isWorking)
                                            playlistCollection.removeTracks(String(root.myOwnListid),
                                                                             [String(model.fileid)])
                                    }
                                }

                                IconButton {
                                    visible: isTogetherMode
                                    iconSource: AppIcon.addTogether
                                    size: 30
                                    iconSize: 16
                                    onClicked: websocket.addSongToTogether(model.title, model.songhash,
                                                                           model.singername, model.album_name,
                                                                           model.duration, model.union_cover)
                                }
                            }
                        }

                        // 专辑名（与最近播放一致的列）
                        Text {
                            text: model.album_name
                            width: 0.2 * tracksListView.width
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.family: AppTheme.fontFamily
                            font.bold: true
                            color: AppTheme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: {
                                var d = model.duration
                                if (!d) return "--:--"
                                if (d.indexOf(":") !== -1) return d
                                var sec = parseInt(d)
                                if (isNaN(sec)) return d
                                var m = Math.floor(sec / 60)
                                var s = sec % 60
                                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                            }
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 双击切换播放列表。用 TapHandler 而非 MouseArea：
                    // MouseArea anchors.fill 会 grab press 事件，导致 delegate 内
                    // 按钮的 TapHandler 收不到点击。TapHandler 之间不互相吞噬。
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        enabled: !isTogetherMode
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        cursorShape: Qt.PointingHandCursor
                        onDoubleTapped: {
                            if (!recommendation) return
                            var total = recommendation.playlistTotal
                            var model = recommendation.playlistTracksModel
                            if (model.count === 0 || total <= 0) return
                            var firstBatch = []
                            for (var i = 0; i < model.count; i++)
                                firstBatch.push(model.get(i))
                            playlistmanager.playPlaylistFromSource(playlistId, total, index, firstBatch)
                            BasicConfig.emitSongAdded("已切换播放列表: " + playlistName)
                        }
                    }

                    HoverHandler { id: songHover }
                }

        // footer：总数 / 加载中 / 已加载全部
        footer: Item {
            width: tracksListView.width
            height: 44
            Text {
                anchors.centerIn: parent
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
                text: {
                    if (!recommendation) return ""
                    if (recommendation.playlistIsLoading) return "加载中..."
                    var loaded = recommendation.playlistTracksModel ? recommendation.playlistTracksModel.count : 0
                    if (!recommendation.playlistHasMore)
                        return "共 " + recommendation.playlistTotal + " 首"
                    return "已加载 " + loaded + " / " + recommendation.playlistTotal + " 首"
                }
            }
        }
    }

    // 空状态：歌单无歌曲时
    EmptyState {
        anchors.top: parent.top
        anchors.topMargin: 200
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !recommendation || recommendation.playlistTracksModel.count === 0
        iconText: "♪"
        title: "歌单暂无歌曲"
        subtitle: "稍后再来看看吧"
    }

    // ── 收藏歌曲到歌单：歌单选择弹窗 ──
    ThemedPopup {
        id: collectPopup
        width: 320
        height: 400
        property string currentSongName: ""

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: "收藏到歌单"
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
            }
            Text {
                text: "\"" + collectPopup.currentSongName + "\""
                width: parent.width
                elide: Text.ElideRight
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }

            // 新建歌单行
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width - 60
                    height: 34
                    radius: 8
                    color: AppTheme.bgCard
                    border.color: newNameInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault
                    border.width: 1

                    TextInput {
                        id: newNameInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        selectByMouse: true
                    }
                }

                Rectangle {
                    width: 52
                    height: 34
                    radius: 8
                    color: createHover.hovered ? AppTheme.accentHover : AppTheme.accent
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "创建"
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.bold: true
                        color: "white"
                        font.family: AppTheme.fontFamily
                    }
                    HoverHandler { id: createHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: !playlistCollection.isWorking
                        onTapped: {
                            var name = newNameInput.text.trim()
                            if (name === "") {
                                BasicConfig.noticeError("请输入歌单名")
                                return
                            }
                            playlistCollection.createPlaylist(name)
                        }
                    }
                }
            }

            // 我的歌单列表（点击即收藏当前歌曲）
            Rectangle {
                width: parent.width
                height: parent.height - 120
                radius: 8
                color: AppTheme.bgCard

                ListView {
                    anchors.fill: parent
                    clip: true
                    model: root.myPlaylists
                    spacing: 2

                    delegate: Rectangle {
                        width: parent.width
                        height: 42
                        radius: 6
                        color: collectItemHover.hovered ? AppTheme.bgNavHover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Image {
                                width: 26
                                height: 26
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.pic ? modelData.pic.replace("{size}", "80") : ""
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: 26; height: 26; radius: 5 }
                                }
                            }
                            Text {
                                text: modelData.name || "未命名歌单"
                                width: parent.width - 90
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeSmall
                                color: AppTheme.textPrimary
                                font.family: AppTheme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.count || 0
                                font.pixelSize: AppTheme.fontSizeCaption
                                color: AppTheme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: collectItemHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            enabled: !playlistCollection.isWorking
                            onTapped: {
                                if (!root.pendingCollectSong) return
                                // 单曲收藏：songname/songhash 必填，album_id/mixsongid 留空由服务端兜底
                                playlistCollection.addTracks(String(modelData.listid), [root.pendingCollectSong])
                                collectPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
