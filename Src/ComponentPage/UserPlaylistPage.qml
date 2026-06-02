import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    id: userPlaylistPage
    objectName: "UserPlaylistPage"
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ── 工具函数 ──
    function fmtDuration(raw) {
        if (!raw && raw !== 0) return ""
        var sec = parseInt(raw, 10)
        if (isNaN(sec) || sec < 0) return ""
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── 数据 ──
    property var playlists: []
    property var currentSongs: []
    property string currentListName: ""
    property string currentListId: ""
    property int currentListCount: 0

    // ── 视图状态 ──
    property string viewState: "list"  // "list" | "detail"

    // ── 歌单列表分页 ──
    property int playlistPage: 1
    property int playlistPageSize: 20
    property bool hasMorePlaylists: true
    property bool isLoadingPlaylists: false
    property bool isLoadingMorePlaylists: false

    // ── 歌曲详情分页 ──
    property int detailPage: 1
    property int detailPageSize: 30
    property bool hasMoreSongs: true
    property bool isLoadingDetail: false
    property bool isLoadingMoreSongs: false

    // ── 歌单内搜索 ──
    property string searchKeyword: ""
    property var filteredSongs: []

    onSearchKeywordChanged: updateFilteredSongs()
    onCurrentSongsChanged: updateFilteredSongs()

    function updateFilteredSongs() {
        if (searchKeyword.trim() === "") {
            filteredSongs = currentSongs
        } else {
            var kw = searchKeyword.trim().toLowerCase()
            var result = []
            for (var i = 0; i < currentSongs.length; i++) {
                var s = currentSongs[i]
                if ((s.songname && s.songname.toLowerCase().indexOf(kw) >= 0) ||
                    (s.singername && s.singername.toLowerCase().indexOf(kw) >= 0) ||
                    (s.album_name && s.album_name.toLowerCase().indexOf(kw) >= 0)) {
                    result.push(s)
                }
            }
            filteredSongs = result
        }
    }

    Component.onCompleted: {
        if (userManager && userManager.isLoggedIn) {
            // 先加载缓存，立即显示
            var cached = userManager.loadCachedPlaylists()
            var cachedData = cached["data"] || cached
            if (cachedData) {
                var cachedList = []
                if (cachedData.info && cachedData.info.length > 0) {
                    cachedList = Array.prototype.slice.call(cachedData.info)
                } else if (cachedData.length !== undefined) {
                    cachedList = Array.prototype.slice.call(cachedData)
                }
                for (var i = 0; i < cachedList.length; i++) {
                    if (cachedList[i].pic) cachedList[i].pic = cachedList[i].pic.replace("{size}", "400")
                }
                if (cachedList.length > 0) playlists = cachedList
            }
            // 后台刷新
            isLoadingPlaylists = playlists.length === 0
            playlistPage = 1
            userManager.fetchUserPlaylist(1, playlistPageSize)
        }
    }

    // ── 信号处理 ──
    Connections {
        target: userManager
        function onLoginStatusChanged() {
            if (userManager && userManager.isLoggedIn) {
                // 先加载缓存
                var cached = userManager.loadCachedPlaylists()
                var cachedData = cached["data"] || cached
                if (cachedData) {
                    var cachedList = []
                    if (cachedData.info && cachedData.info.length > 0) {
                        cachedList = Array.prototype.slice.call(cachedData.info)
                    } else if (cachedData.length !== undefined) {
                        cachedList = Array.prototype.slice.call(cachedData)
                    }
                    for (var i = 0; i < cachedList.length; i++) {
                        if (cachedList[i].pic) cachedList[i].pic = cachedList[i].pic.replace("{size}", "400")
                    }
                    if (cachedList.length > 0) playlists = cachedList
                }
                isLoadingPlaylists = playlists.length === 0
                playlistPage = 1
                userManager.fetchUserPlaylist(1, playlistPageSize)
            } else {
                playlists = []
                currentSongs = []
                viewState = "list"
            }
        }
        function onUserPlaylistReceived(data) {
            isLoadingPlaylists = false
            isLoadingMorePlaylists = false
            var listData = data["data"] || data
            var rawList = []
            if (listData && listData.info && listData.info.length > 0) {
                rawList = Array.prototype.slice.call(listData.info)
            } else if (listData && listData.length !== undefined) {
                rawList = Array.prototype.slice.call(listData)
            }
            for (var i = 0; i < rawList.length; i++) {
                if (rawList[i].pic) rawList[i].pic = rawList[i].pic.replace("{size}", "400")
            }
            if (playlistPage === 1) {
                playlists = rawList
            } else {
                var combined = Array.prototype.slice.call(playlists).concat(rawList)
                playlists = combined
            }
            hasMorePlaylists = rawList.length >= playlistPageSize
        }
        function onPlaylistDetailReceived(data) {
            isLoadingDetail = false
            isLoadingMoreSongs = false
            var detailData = data["data"] || data
            var songList = []
            var totalCount = 0
            if (detailData && detailData.songs && detailData.songs.length > 0) {
                songList = Array.prototype.slice.call(detailData.songs)
                totalCount = detailData.count || detailData.total || songList.length
            } else if (detailData && detailData.info && detailData.info.length > 0) {
                songList = Array.prototype.slice.call(detailData.info)
                totalCount = detailData.count || detailData.total || songList.length
            }
            currentListCount = totalCount
            var normalized = []
            for (var i = 0; i < songList.length; i++) {
                var s = songList[i]
                var singerName = ""
                if (s.singerinfo && s.singerinfo.length > 0) {
                    var si = s.singerinfo[0]
                    singerName = (si && si.name) ? si.name : ""
                }
                var coverUrl = (s.cover || "").replace("{size}", "80")
                normalized.push({
                    "songname": s.songname || (s.name || "").split(" - ").pop() || s.name || "",
                    "singername": singerName || (s.name || "").split(" - ")[0] || "",
                    "hash": s.hash || "",
                    "cover": coverUrl,
                    "union_cover": coverUrl,
                    "album_name": (s.albuminfo && s.albuminfo.name) ? s.albuminfo.name : (s.album_name || ""),
                    "duration": s.duration ? (String(s.duration).indexOf(":") >= 0 ? s.duration : fmtDuration(s.duration)) : (s.timelen ? fmtDuration(Math.round(s.timelen / 1000)) : ""),
                })
            }
            if (detailPage === 1) {
                currentSongs = normalized
            } else {
                var combined = Array.prototype.slice.call(currentSongs).concat(normalized)
                currentSongs = combined
            }
            hasMoreSongs = normalized.length >= detailPageSize && currentSongs.length < currentListCount
        }
    }

    // ── 未登录提示 ──
    Item {
        visible: !userManager || !userManager.isLoggedIn
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "请先登录查看歌单"
                color: AppTheme.textMuted
                font.pixelSize: 16
                font.family: "黑体"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 120
                height: 36
                radius: AppTheme.radiusMedium
                color: loginBtnHover.hovered ? AppTheme.accentHover : AppTheme.accent
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "去登录"
                    color: "white"
                    font.pixelSize: 14
                    font.family: "黑体"
                }

                HoverHandler { id: loginBtnHover }
                TapHandler { onTapped: loginPopup.open() }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    // ── 已登录内容 ──
    Item {
        visible: userManager && userManager.isLoggedIn
        anchors.fill: parent

        // ═══════ 歌单列表视图 ═══════
        Item {
            id: listViewContainer
            anchors.fill: parent
            visible: listOpacity > 0.01
            opacity: listOpacity
            x: listSlideX

            property real listOpacity: viewState === "list" ? 1.0 : 0.0
            property real listSlideX: viewState === "list" ? 0 : -width * 0.15

            Behavior on listOpacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on listSlideX { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Flickable {
                id: playlistFlickable
                anchors.fill: parent
                clip: true
                contentHeight: listContent.height

                onContentYChanged: {
                    if (isLoadingMorePlaylists || !hasMorePlaylists) return
                    if (contentY >= contentHeight - height - 200) {
                        isLoadingMorePlaylists = true
                        playlistPage += 1
                        userManager.fetchUserPlaylist(playlistPage, playlistPageSize)
                    }
                }

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
                    id: listContent
                    width: parent.width
                    anchors.leftMargin: 0.04 * userPlaylistPage.width
                    anchors.rightMargin: 0.04 * userPlaylistPage.width
                    spacing: 4
                    topPadding: 20

                    // 标题
                    Text {
                        text: "我的歌单"
                        color: AppTheme.textPrimary
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        font.family: "黑体"
                        anchors.left: parent.left
                        anchors.leftMargin: 0.04 * userPlaylistPage.width
                    }

                    // 加载中（首次）
                    Text {
                        visible: isLoadingPlaylists
                        text: "加载中..."
                        color: AppTheme.textMuted
                        font.pixelSize: 13
                        font.family: "黑体"
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 20
                    }

                    // 歌单列表（横排）
                    Column {
                        visible: !isLoadingPlaylists
                        width: parent.width - 0.08 * userPlaylistPage.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Repeater {
                            model: playlists.length

                            delegate: Rectangle {
                                width: parent.width
                                height: 70
                                radius: AppTheme.radiusSmall
                                color: rowHover.hovered ? AppTheme.bgCardHover : "transparent"

                                property var playlistData: playlists[index]

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 14

                                    // 封面
                                    Rectangle {
                                        width: 50
                                        height: 50
                                        radius: 8
                                        clip: true
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            anchors.fill: parent
                                            source: playlistData.pic || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            visible: status === Image.Ready
                                        }
                                    }

                                    // 歌单名 + 数量
                                    Column {
                                        width: parent.width - 50 - 14 - 60 - 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: playlistData.name || "未知歌单"
                                            width: parent.width
                                            elide: Text.ElideRight
                                            color: AppTheme.textPrimary
                                            font.pixelSize: 14
                                            font.family: "黑体"
                                        }

                                        Text {
                                            text: (playlistData.count || 0) + " 首"
                                            color: AppTheme.textMuted
                                            font.pixelSize: 12
                                            font.family: "黑体"
                                        }
                                    }

                                    // 右侧箭头
                                    Image {
                                        id: arrowIcon
                                        width: 16
                                        height: 16
                                        source: "qrc:/image/left_line.png"
                                        rotation: 180
                                        fillMode: Image.PreserveAspectFit
                                        anchors.verticalCenter: parent.verticalCenter
                                        layer.enabled: true
                                        layer.effect: ColorOverlay {
                                            source: arrowIcon
                                            color: AppTheme.textMuted
                                        }
                                    }
                                }

                                HoverHandler { id: rowHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: {
                                        if (!userManager) return
                                        var gid = playlistData.global_collection_id || ""
                                        if (gid === "") return
                                        currentListId = gid
                                        currentListName = playlistData.name || "歌单"
                                        currentListCount = playlistData.count || 0
                                        detailPage = 1
                                        hasMoreSongs = true

                                        // 先加载缓存
                                        var cachedDetail = userManager.loadCachedPlaylistDetail(gid)
                                        var cd = cachedDetail["data"] || cachedDetail
                                        if (cd) {
                                            var cachedSongs = []
                                            if (cd.songs && cd.songs.length > 0) cachedSongs = Array.prototype.slice.call(cd.songs)
                                            else if (cd.info && cd.info.length > 0) cachedSongs = Array.prototype.slice.call(cd.info)
                                            if (cachedSongs.length > 0) {
                                                currentListCount = cd.count || cd.total || cachedSongs.length
                                                var normalized = []
                                                for (var j = 0; j < cachedSongs.length; j++) {
                                                    var s = cachedSongs[j]
                                                    var sn = ""
                                                    if (s.singerinfo && s.singerinfo.length > 0) { var si = s.singerinfo[0]; sn = (si && si.name) ? si.name : "" }
                                                    var cu = (s.cover || "").replace("{size}", "80")
                                                    normalized.push({
                                                        "songname": s.songname || (s.name || "").split(" - ").pop() || s.name || "",
                                                        "singername": sn || (s.name || "").split(" - ")[0] || "",
                                                        "hash": s.hash || "", "cover": cu, "union_cover": cu,
                                                        "album_name": (s.albuminfo && s.albuminfo.name) ? s.albuminfo.name : (s.album_name || ""),
                                                        "duration": s.duration ? (String(s.duration).indexOf(":") >= 0 ? s.duration : fmtDuration(s.duration)) : (s.timelen ? fmtDuration(Math.round(s.timelen / 1000)) : ""),
                                                    })
                                                }
                                                currentSongs = normalized
                                            }
                                        }

                                        isLoadingDetail = currentSongs.length === 0
                                        viewState = "detail"
                                        userManager.fetchPlaylistDetail(gid, 1, detailPageSize)
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // 加载更多歌单
                        Item {
                            width: parent.width
                            height: 40
                            visible: isLoadingMorePlaylists || !hasMorePlaylists && playlists.length > 0

                            Text {
                                visible: isLoadingMorePlaylists
                                text: "加载更多..."
                                color: AppTheme.textMuted
                                font.pixelSize: 12
                                font.family: "黑体"
                                anchors.centerIn: parent
                            }

                            Text {
                                visible: !hasMorePlaylists && playlists.length > 0 && !isLoadingMorePlaylists
                                text: "共 " + playlists.length + " 个歌单"
                                color: AppTheme.textDim
                                font.pixelSize: 12
                                font.family: "黑体"
                                anchors.centerIn: parent
                            }
                        }
                    }

                    // 空状态
                    Text {
                        visible: !isLoadingPlaylists && playlists.length === 0
                        text: "暂无歌单"
                        color: AppTheme.textMuted
                        font.pixelSize: 14
                        font.family: "黑体"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // ═══════ 歌曲详情视图 ═══════
        Item {
            id: detailViewContainer
            anchors.fill: parent
            visible: detailOpacity > 0.01
            opacity: detailOpacity
            x: detailSlideX

            property real detailOpacity: viewState === "detail" ? 1.0 : 0.0
            property real detailSlideX: viewState === "detail" ? 0 : width * 0.15

            Behavior on detailOpacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on detailSlideX { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Column {
                anchors.fill: parent

                // 顶部标题栏
                Item {
                    width: parent.width
                    height: 60

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 0.04 * parent.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: backHover.hovered ? AppTheme.iconButtonHover : "transparent"

                            Image {
                                id: backIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/left_line.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: backIcon
                                    color: AppTheme.iconDefault
                                }
                            }

                            HoverHandler { id: backHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    viewState = "list"
                                    searchKeyword = ""
                                    detailSearchField.text = ""
                                    resetTimer.start()
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            text: currentListName
                            color: AppTheme.textPrimary
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            font.family: "黑体"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "共" + currentListCount + "首"
                            color: AppTheme.textDim
                            font.pixelSize: 13
                            font.family: "黑体"
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                        }
                    }
                }

                // 操作栏
                Rectangle {
                    id: detailActionsWrapper
                    width: parent.width - 0.08 * userPlaylistPage.width
                    height: 45
                    anchors.left: parent.left
                    anchors.leftMargin: 0.04 * userPlaylistPage.width
                    color: "transparent"

                    Row {
                        id: detailActions
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 12

                    Rectangle {
                        width: 100
                        height: 35
                        radius: 17
                        color: playAllHover.hovered ? AppTheme.accentHover : AppTheme.accent

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Image {
                                id: playAllIcon
                                source: "qrc:/image/play.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: playAllIcon
                                    color: "white"
                                }
                            }

                            Text {
                                text: "播放全部"
                                color: "white"
                                font.pixelSize: 14
                                font.family: "黑体"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: playAllHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (!playlistmanager || filteredSongs.length === 0) return
                                playlistmanager.clearPlaylist()
                                var songsToPlay = searchKeyword.trim() === "" ? currentSongs : filteredSongs
                                for (var i = 0; i < songsToPlay.length; i++) {
                                    var s = songsToPlay[i]
                                    playlistmanager.addSong(s.songname, s.hash, s.singername, s.cover, s.album_name, s.duration)
                                }
                                playlistmanager.playSongbyindex(0)
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        visible: isLoadingDetail
                        text: "加载中..."
                        color: AppTheme.textMuted
                        font.pixelSize: 13
                        font.family: "黑体"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 搜索结果计数
                    Text {
                        visible: searchKeyword.trim() !== ""
                        text: "找到 " + filteredSongs.length + " 首"
                        color: AppTheme.textMuted
                        font.pixelSize: 13
                        font.family: "黑体"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 歌单内搜索框
                Rectangle {
                        width: 200
                        height: 35
                        radius: 17
                        color: AppTheme.bgInput
                        border.width: 1
                        border.color: detailSearchField.activeFocus ? AppTheme.borderFocus : AppTheme.borderDefault
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            Image {
                                id: detailSearchIcon
                                source: "qrc:/image/search_line.png"
                                width: 14
                                height: 14
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: detailSearchIcon
                                    color: AppTheme.iconSearch
                                }
                            }

                            TextField {
                                id: detailSearchField
                                width: parent.width - detailSearchIcon.width - parent.spacing - (searchKeyword.trim() !== "" ? clearDetailSearch.width + parent.spacing : 0)
                                height: parent.height
                                placeholderText: "搜索歌曲、歌手、专辑"
                                color: AppTheme.textPrimary
                                palette.placeholderText: AppTheme.textPlaceholder
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 13
                                font.family: "黑体"
                                background: Rectangle { color: "transparent" }
                                onTextChanged: {
                                    searchKeyword = text
                                }
                            }

                            Rectangle {
                                id: clearDetailSearch
                                width: 20
                                height: 20
                                radius: 10
                                color: clearDetailHover.hovered ? AppTheme.iconButtonHover : "transparent"
                                visible: searchKeyword.trim() !== ""

                                Image {
                                    id: clearDetailIcon
                                    anchors.centerIn: parent
                                    source: "qrc:/image/delete_line.png"
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: clearDetailIcon
                                        color: AppTheme.iconDefault
                                    }
                                }

                                HoverHandler { id: clearDetailHover }
                                TapHandler {
                                    onTapped: {
                                        detailSearchField.text = ""
                                        searchKeyword = ""
                                    }
                                }
                            }
                        }

                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }
                }

                // 歌曲列表
                Flickable {
                    id: detailFlickable
                    width: parent.width
                    height: parent.height - 60 - detailActions.height - 12
                    anchors.topMargin: 12
                    clip: true
                    contentHeight: detailListColumn.height

                    onContentYChanged: {
                        if (isLoadingMoreSongs || !hasMoreSongs) return
                        if (contentY >= contentHeight - height - 200) {
                            isLoadingMoreSongs = true
                            detailPage += 1
                            userManager.fetchPlaylistDetail(currentListId, detailPage, detailPageSize)
                        }
                    }

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
                        id: detailListColumn
                        width: parent.width

                        Repeater {
                            model: filteredSongs.length

                            delegate: Rectangle {
                                width: detailListColumn.width
                                height: 60
                                radius: 5
                                color: {
                                    if (songMouse.hovered) return AppTheme.bgCardHover
                                    if (playlistmanager && filteredSongs[index] && filteredSongs[index].hash && playlistmanager.currentSonghash === filteredSongs[index].hash) return AppTheme.bgCardHover
                                    return "transparent"
                                }

                                readonly property bool isPlaying: playlistmanager && filteredSongs[index] && filteredSongs[index].hash && playlistmanager.currentSonghash === filteredSongs[index].hash

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    spacing: 15

                                    Text {
                                        width: 25
                                        text: index + 1 <= 9 ? "0" + String(index + 1) : String(index + 1)
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 16
                                        color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                                        visible: !isPlaying
                                    }

                                    AnimatedImage {
                                        width: 25
                                        height: 25
                                        source: "qrc:/image/isplaying.gif"
                                        playing: visible
                                        visible: isPlaying
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Image {
                                        width: 40
                                        height: 40
                                        source: filteredSongs[index] ? filteredSongs[index].cover : ""
                                        sourceSize.width: 80
                                        sourceSize.height: 80
                                        fillMode: Image.PreserveAspectCrop
                                        anchors.verticalCenter: parent.verticalCenter
                                        asynchronous: true
                                        cache: true
                                    }

                                    Column {
                                        width: 0.35 * userPlaylistPage.width
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            text: filteredSongs[index] ? filteredSongs[index].songname : ""
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.pixelSize: 13
                                            font.family: "黑体"
                                            color: isPlaying ? AppTheme.accentPlaying : AppTheme.textPrimary
                                        }

                                        Text {
                                            text: filteredSongs[index] ? filteredSongs[index].singername : ""
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.pixelSize: 11
                                            font.family: "黑体"
                                            color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                                        }
                                    }

                                    // 操作按钮区（固定宽度，悬停时显示按钮）
                                    Item {
                                        width: isTogetherMode ? 34 : 68
                                        height: 30
                                        anchors.verticalCenter: parent.verticalCenter

                                        Row {
                                            anchors.fill: parent
                                            spacing: 4
                                            visible: songMouse.hovered && !isPlaying

                                            Rectangle {
                                                visible: !isTogetherMode
                                                width: 30; height: 30; radius: 15
                                                color: AppTheme.isDark
                                                       ? (playHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                                       : (playHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                                Image {
                                                    id: playNowIcon
                                                    anchors.centerIn: parent
                                                    source: "qrc:/image/playnow.png"
                                                    width: 14; height: 14
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: true
                                                    layer.effect: ColorOverlay {
                                                        source: playNowIcon
                                                        color: AppTheme.isDark ? (playHover.hovered ? "#4FC3F7" : "#FFFFFF") : AppTheme.accent
                                                    }
                                                }
                                                HoverHandler { id: playHover }
                                                TapHandler {
                                                    cursorShape: Qt.PointingHandCursor
                                                    onTapped: {
                                                        if (!playlistmanager) return
                                                        var s = filteredSongs[index]
                                                        playlistmanager.addandplay(s.songname, s.hash, s.singername, s.cover, s.album_name, s.duration)
                                                    }
                                                }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            Rectangle {
                                                visible: !isTogetherMode
                                                width: 30; height: 30; radius: 15
                                                color: AppTheme.isDark
                                                       ? (addHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                                       : (addHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                                Image {
                                                    id: addListIcon
                                                    anchors.centerIn: parent
                                                    source: "qrc:/image/addplaylist.png"
                                                    width: 14; height: 14
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: true
                                                    layer.effect: ColorOverlay {
                                                        source: addListIcon
                                                        color: AppTheme.isDark ? (addHover.hovered ? AppTheme.accent : "#FFFFFF") : AppTheme.accent
                                                    }
                                                }
                                                HoverHandler { id: addHover }
                                                TapHandler {
                                                    cursorShape: Qt.PointingHandCursor
                                                    onTapped: {
                                                        if (!playlistmanager) return
                                                        var s = filteredSongs[index]
                                                        playlistmanager.addSong(s.songname, s.hash, s.singername, s.cover, s.album_name, s.duration)
                                                        BasicConfig.emitSongAdded()
                                                    }
                                                }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            Rectangle {
                                                visible: isTogetherMode
                                                width: 30; height: 30; radius: 15
                                                color: AppTheme.isDark
                                                       ? (addTogetherHover.hovered ? AppTheme.iconButtonHover : "transparent")
                                                       : (addTogetherHover.hovered ? "#FFCCCC" : "#FFD8D8")
                                                Image {
                                                    id: togetherIcon
                                                    anchors.centerIn: parent
                                                    source: "qrc:/image/yinle.png"
                                                    width: 14; height: 14
                                                    fillMode: Image.PreserveAspectFit
                                                    layer.enabled: true
                                                    layer.effect: ColorOverlay {
                                                        source: togetherIcon
                                                        color: AppTheme.isDark ? (addTogetherHover.hovered ? AppTheme.accent : "#FFFFFF") : AppTheme.accent
                                                    }
                                                }
                                                HoverHandler { id: addTogetherHover }
                                                TapHandler {
                                                    cursorShape: Qt.PointingHandCursor
                                                    onTapped: {
                                                        if (!websocket || !filteredSongs[index]) return
                                                        var s = filteredSongs[index]
                                                        websocket.addSongToTogether(
                                                            s.songname, s.hash, s.singername,
                                                            s.album_name, s.duration, s.cover
                                                        )
                                                    }
                                                }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }
                                    }

                                    Text {
                                        text: filteredSongs[index] ? filteredSongs[index].album_name : ""
                                        width: 0.2 * userPlaylistPage.width
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.family: "黑体"
                                        color: AppTheme.textPrimary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: filteredSongs[index] ? filteredSongs[index].duration : ""
                                        font.pixelSize: 14
                                        font.family: "黑体"
                                        color: AppTheme.textMuted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                HoverHandler { id: songMouse }
                            }
                        }

                        // 加载更多歌曲
                        Item {
                            width: parent.width
                            height: 50
                            visible: isLoadingMoreSongs || (!hasMoreSongs && currentSongs.length > 0)

                            Text {
                                visible: isLoadingMoreSongs
                                text: "加载更多歌曲..."
                                color: AppTheme.textMuted
                                font.pixelSize: 12
                                font.family: "黑体"
                                anchors.centerIn: parent
                            }

                            Text {
                                visible: !hasMoreSongs && currentSongs.length > 0 && !isLoadingMoreSongs
                                text: "已加载全部 " + currentSongs.length + " 首"
                                color: AppTheme.textDim
                                font.pixelSize: 12
                                font.family: "黑体"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }
        }
    }

    // 返回后延迟清理数据
    Timer {
        id: resetTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (viewState === "list") {
                currentSongs = []
                currentListId = ""
                detailPage = 1
                hasMoreSongs = true
                searchKeyword = ""
            }
        }
    }
}
