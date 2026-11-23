import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

// 歌单管理中心：左侧歌单列表 + 右侧当前歌单详情
Item {
    id: root
    objectName: "PlaylistManagerPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    readonly property bool loggedIn: userManager && userManager.isLoggedIn
    readonly property int selectedCount: Object.keys(selectedFileids).length

    property var playlists: []
    property var filteredPlaylists: []
    property int playlistTotalVer: 0
    property string playlistSearch: ""
    property string pendingSelectListid: ""

    property string selectedGid: ""
    property var selectedPlaylist: ({})
    property var songs: []
    property var filteredSongs: []
    property string songSearch: ""
    property int songCount: 0
    property int listVer: 0
    property int detailPage: 1
    property bool hasMoreSongs: false
    property bool loadingList: false
    property bool loadingDetail: false
    property bool loadingMoreSongs: false

    property bool manageMode: false
    property var selectedFileids: ({})

    function fmtDuration(raw) {
        var sec = Number(raw)
        if (!isFinite(sec) || sec <= 0) return "--:--"
        var m = Math.floor(sec / 60)
        var s = Math.round(sec % 60)
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    function normalizedSong(s) {
        if (!s || !s.hash) return null
        var singerName = ""
        if (s.singerinfo && s.singerinfo.length > 0 && s.singerinfo[0])
            singerName = s.singerinfo[0].name || ""
        var rawName = s.name || ""
        var dash = rawName.indexOf(" - ")
        var songName = s.songname || (dash >= 0 ? rawName.substring(dash + 3) : rawName)
        if (singerName === "" && dash >= 0)
            singerName = rawName.substring(0, dash)
        var cover = s.cover || (s.trans_param ? s.trans_param.union_cover : "")
        if (!cover && s.album_info) cover = s.album_info.cover || ""
        if (!cover && s.albuminfo) cover = s.albuminfo.cover || ""
        cover = String(cover || "").replace("{size}", "200")
        var albumName = s.album_name || (s.albuminfo ? s.albuminfo.name : "")
        var duration = s.duration || ""
        if (duration === "" && s.timelen)
            duration = fmtDuration(Math.round(Number(s.timelen) / 1000))
        return {
            "songname": songName,
            "singername": singerName,
            "hash": s.hash,
            "songhash": s.hash,
            "cover": cover,
            "union_cover": cover,
            "album_name": albumName,
            "duration": duration,
            "fileid": s.fileid !== undefined ? String(s.fileid) : "",
            "album_id": s.album_id !== undefined ? String(s.album_id) : "",
            "mixsongid": s.mixsongid !== undefined ? String(s.mixsongid) : (s.album_audio_id !== undefined ? String(s.album_audio_id) : ""),
            "mvhash": s.mvhash || ""
        }
    }

    function applyPlaylistFilter() {
        var q = playlistSearch.trim().toLowerCase()
        if (q === "") {
            filteredPlaylists = playlists
            return
        }
        var out = []
        for (var i = 0; i < playlists.length; i++) {
            var p = playlists[i]
            if (String(p.name || "").toLowerCase().indexOf(q) >= 0)
                out.push(p)
        }
        filteredPlaylists = out
    }

    function applySongFilter() {
        var q = songSearch.trim().toLowerCase()
        if (q === "") {
            filteredSongs = songs
            return
        }
        var out = []
        for (var i = 0; i < songs.length; i++) {
            var s = songs[i]
            if (String(s.songname || "").toLowerCase().indexOf(q) >= 0
                    || String(s.singername || "").toLowerCase().indexOf(q) >= 0
                    || String(s.album_name || "").toLowerCase().indexOf(q) >= 0)
                out.push(s)
        }
        filteredSongs = out
    }

    function findPlaylist(key) {
        if (!key) return null
        for (var i = 0; i < playlists.length; i++) {
            var p = playlists[i]
            if (String(p.global_collection_id || "") === String(key)
                    || String(p.listid || "") === String(key)
                    || String(p.list_create_gid || "") === String(key))
                return p
        }
        return null
    }

    function applyPlaylistData(data) {
        var d = data ? (data["data"] || data) : null
        if (!d) return
        if (d.total_ver !== undefined && d.total_ver !== null)
            playlistTotalVer = Number(d.total_ver)
        var raw = d.info || (d.length !== undefined ? d : [])
        var arr = []
        for (var i = 0; i < raw.length; i++) {
            var p = raw[i]
            if (!p) continue
            if (p.pic) p.pic = String(p.pic).replace("{size}", "300")
            arr.push(p)
        }
        playlists = arr
        applyPlaylistFilter()
        if (arr.length === 0) {
            clearSelection()
            return
        }
        var target = findPlaylist(pendingSelectListid)
        pendingSelectListid = ""
        if (!target) target = findPlaylist(selectedGid)
        if (!target) target = arr[0]
        if (!selectedGid || String(target.global_collection_id) === String(selectedGid)) {
            selectedPlaylist = target
            selectedGid = String(target.global_collection_id || "")
            if (songs.length === 0)
                selectPlaylist(target, true)
        } else {
            selectPlaylist(target, true)
        }
    }

    function clearSelection() {
        selectedGid = ""
        selectedPlaylist = ({})
        songs = []
        filteredSongs = []
        songCount = 0
        listVer = 0
        hasMoreSongs = false
        manageMode = false
        selectedFileids = ({})
    }

    function selectPlaylist(p, force) {
        if (!p) return
        var gid = String(p.global_collection_id || p.list_create_gid || "")
        selectedPlaylist = p
        if (!force && gid === selectedGid && songs.length > 0)
            return
        selectedGid = gid
        songs = []
        filteredSongs = []
        songSearch = ""
        songCount = Number(p.count || 0)
        listVer = 0
        hasMoreSongs = false
        detailPage = 1
        manageMode = false
        selectedFileids = ({})
        loadingDetail = true
        if (gid === "") {
            loadingDetail = false
            return
        }
        userManager.fetchPlaylistDetail(gid, 1, 300)
    }

    function loadDetailPage(page) {
        if (!selectedGid) return
        if (page === 1) {
            detailPage = 1
            loadingDetail = true
        } else {
            loadingMoreSongs = true
        }
        userManager.fetchPlaylistDetail(selectedGid, page, 300)
    }

    function applyDetailData(data) {
        var requestGid = data["_request_gid"] || ""
        if (requestGid !== "" && requestGid !== selectedGid)
            return
        loadingDetail = false
        loadingMoreSongs = false
        var d = data["data"] || data
        var raw = d.songs || d.info || []
        var count = d.count || d.total || raw.length
        songCount = Number(count)
        listVer = Number((d.list_info && d.list_info.list_ver) || d.list_ver || 0)
        var arr = []
        for (var i = 0; i < raw.length; i++) {
            var s = normalizedSong(raw[i])
            if (s) arr.push(s)
        }
        if (detailPage <= 1)
            songs = arr
        else
            songs = songs.concat(arr)
        hasMoreSongs = raw.length >= 300 && songs.length < songCount
        applySongFilter()
    }

    function refreshPlaylists() {
        if (!loggedIn) return
        loadingList = playlists.length === 0
        userManager.fetchUserPlaylist(1, 100)
    }

    function canRename(p) {
        return !!p && Number(p.type) === 0 && !isSystemPlaylist(p)
    }
    function canDelete(p) {
        return !!p && Number(p.type) === 0 && !isSystemPlaylist(p)
    }
    function canUncollect(p) {
        return !!p && Number(p.type) === 1
    }
    function canRemoveSongs(p) {
        return !!p && Number(p.type) === 0
    }
    function isSystemPlaylist(p) {
        if (!p) return false
        return Number(p.listid) === 1 || Number(p.listid) === 2 || Number(p.is_def) === 1
    }

    function playAllFrom(startIndex) {
        if (!playlistmanager || songs.length === 0) return
        var batch = []
        for (var i = 0; i < songs.length; i++) {
            var s = songs[i]
            batch.push({
                "songname": s.songname, "songhash": s.hash,
                "singername": s.singername, "union_cover": s.cover,
                "album_name": s.album_name, "duration": s.duration
            })
        }
        playlistmanager.playPlaylistFromSource(selectedGid, songCount, Math.max(0, startIndex), batch)
        BasicConfig.emitSongAdded("正在播放歌单: " + (selectedPlaylist.name || ""))
    }

    function playSingle(s) {
        if (!s || !playlistmanager) return
        playlistmanager.playNextAndPlay({
            "songname": s.songname,
            "songhash": s.hash,
            "singername": s.singername,
            "union_cover": s.cover,
            "album_name": s.album_name,
            "duration": s.duration
        })
        BasicConfig.emitSongAdded("正在播放: " + s.songname)
    }

    function addSongToTogether(s) {
        if (!s || !websocket || !isTogetherMode) return
        websocket.addSongToTogether(s.songname, s.hash, s.singername, s.album_name, s.duration, s.cover)
        BasicConfig.noticeSuccess("已添加到一起听: " + s.songname)
    }

    function toggleSelect(fileid) {
        var id = String(fileid || "")
        if (id === "") return
        var m = {}
        for (var k in selectedFileids) m[k] = selectedFileids[k]
        if (m[id]) delete m[id]
        else m[id] = true
        selectedFileids = m
    }

    function selectAll() {
        var m = {}
        for (var i = 0; i < filteredSongs.length; i++) {
            var id = String(filteredSongs[i].fileid || "")
            if (id !== "") m[id] = true
        }
        selectedFileids = m
    }

    function exitManageMode() {
        manageMode = false
        selectedFileids = ({})
    }

    function openRemoveConfirm(fileids) {
        if (!fileids || fileids.length === 0) return
        confirmDialog.kind = "removeSongs"
        confirmDialog.fileids = fileids.slice(0)
        confirmDialog.title = "移除歌曲"
        confirmDialog.message = "确定从「" + (selectedPlaylist.name || "当前歌单") + "」移除这 "
                                + fileids.length + " 首歌曲吗？"
        confirmDialog.open()
    }

    function openPlaylistDeleteConfirm() {
        if (!selectedPlaylist || (!canDelete(selectedPlaylist) && !canUncollect(selectedPlaylist))) return
        confirmDialog.kind = canUncollect(selectedPlaylist) ? "uncollect" : "deletePlaylist"
        confirmDialog.fileids = []
        confirmDialog.title = canUncollect(selectedPlaylist) ? "取消收藏" : "删除歌单"
        confirmDialog.message = canUncollect(selectedPlaylist)
                ? "确定不再收藏「" + selectedPlaylist.name + "」吗？"
                : "确定删除歌单「" + selectedPlaylist.name + "」吗？删除后无法恢复。"
        confirmDialog.open()
    }

    Connections {
        target: userManager
        function onUserPlaylistReceived(data) {
            loadingList = false
            applyPlaylistData(data)
        }
        function onPlaylistDetailReceived(data) {
            applyDetailData(data)
        }
        function onLoginStatusChanged() {
            if (root.loggedIn) {
                var cached = userManager.loadCachedPlaylists()
                applyPlaylistData(cached)
                refreshPlaylists()
            } else {
                root.playlists = []
                root.filteredPlaylists = []
                root.clearSelection()
            }
        }
    }

    Connections {
        target: playlistCollection
        function onPlaylistCreated(listid, name) {
            root.pendingSelectListid = String(listid)
        }
        function onPlaylistUpdated() {
            renameDialog.close()
            root.refreshPlaylists()
        }
        function onPlaylistDeleted() {
            confirmDialog.close()
            root.clearSelection()
            root.refreshPlaylists()
        }
        function onTracksRemoved() {
            confirmDialog.close()
            root.exitManageMode()
            root.manageMode = false
            root.loadDetailPage(1)
            root.refreshPlaylists()
        }
    }

    Component.onCompleted: {
        if (!loggedIn) return
        applyPlaylistData(userManager.loadCachedPlaylists())
        refreshPlaylists()
    }

    onVisibleChanged: {
        if (visible) {
            BasicConfig.playlistPageActive = false
            if (loggedIn && playlists.length === 0)
                refreshPlaylists()
        }
    }

    // ---------- 顶部标题 ----------
    Item {
        id: pageHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 0.04 * root.width
        anchors.rightMargin: 0.04 * root.width
        anchors.topMargin: 16
        height: 54

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            GlowText {
                text: "歌单管理"
                font.pixelSize: AppTheme.fontSizeHeadline
                font.bold: true
                color: AppTheme.textPrimary
                glowColor: AppTheme.accentGlow
                glowRadius: 14
            }
            Text {
                text: "创建、重命名、删除歌单，批量整理歌曲"
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
                color: AppTheme.textMuted
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 108
                height: 32
                radius: 16
                color: newHeaderHover.hovered ? AppTheme.accentHover : AppTheme.accent
                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "＋ 新建歌单"
                    color: "#FFFFFF"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    font.family: AppTheme.fontFamily
                }
                HoverHandler { id: newHeaderHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.loggedIn
                    onTapped: createPlaylistDialog.openDialog()
                }
            }

            IconButton {
                iconSource: AppIcon.refresh
                size: 30
                iconSize: 15
                onClicked: root.refreshPlaylists()
            }
        }
    }

    // ---------- 主体 ----------
    Row {
        id: bodyRow
        anchors.left: pageHeader.left
        anchors.right: pageHeader.right
        anchors.top: pageHeader.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 16

        // 左：歌单列表
        Rectangle {
            id: leftPanel
            width: 292
            height: parent.height
            radius: 18
            color: "#121219"
            border.width: 1
            border.color: "#1FFFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Row {
                    width: parent.width

                    Text {
                        text: "我的歌单"
                        font.pixelSize: AppTheme.fontSizeTitle
                        font.bold: true
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textPrimary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.playlists.length + " 个"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    color: AppTheme.bgCard
                    border.width: 1
                    border.color: playlistSearchInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault

                    TextInput {
                        id: playlistSearchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        selectByMouse: true
                        onTextChanged: {
                            root.playlistSearch = text
                            root.applyPlaylistFilter()
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "搜索我的歌单"
                            color: AppTheme.textDim
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.family: AppTheme.fontFamily
                            visible: playlistSearchInput.text === ""
                        }
                    }
                }

                ListView {
                    id: playlistList
                    width: parent.width
                    height: parent.height - 84
                    clip: true
                    spacing: 3
                    model: root.filteredPlaylists

                    delegate: HoverRow {
                        id: plRow
                        width: playlistList.width
                        height: 62
                        radius: 9
                        hovered: plHover.hovered
                        color: root.selectedGid === String(modelData.global_collection_id || "")
                               ? "#20FF6B6B" : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                width: 42
                                height: 42
                                radius: 8
                                clip: true
                                color: "#1C1C26"
                                anchors.verticalCenter: parent.verticalCenter

                                RetryImage {
                                    anchors.fill: parent
                                    coverSource: modelData.pic || ""
                                    sourceSize.width: 84
                                    sourceSize.height: 84
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !modelData.pic
                                    text: "♪"
                                    color: AppTheme.textMuted
                                    font.pixelSize: 18
                                    font.family: AppTheme.fontFamily
                                }
                            }

                            Column {
                                width: parent.width - 42 - 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.name || "未命名歌单"
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                    color: (plHover.hovered || root.selectedGid === String(modelData.global_collection_id || ""))
                                           ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                }
                                Row {
                                    spacing: 6
                                    Text {
                                        text: (modelData.count || 0) + " 首"
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.textMuted
                                    }
                                    Text {
                                        text: Number(modelData.type) === 1 ? "收藏" : "自建"
                                        font.pixelSize: AppTheme.fontSizeXs
                                        font.family: AppTheme.fontFamily
                                        color: Number(modelData.type) === 1 ? AppTheme.infoColor : AppTheme.textDim
                                    }
                                }
                            }
                        }

                        HoverHandler { id: plHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: root.selectPlaylist(modelData, false)
                        }
                    }
                }

                Text {
                    visible: root.filteredPlaylists.length === 0
                    width: parent.width
                    height: 60
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.loadingList ? "正在加载歌单..." : (root.loggedIn ? "没有匹配的歌单" : "登录后查看我的歌单")
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textMuted
                }
            }
        }

        // 右：歌单详情
        Rectangle {
            id: rightPanel
            width: parent.width - leftPanel.width - bodyRow.spacing
            height: parent.height
            radius: 18
            color: "#121219"
            border.width: 1
            border.color: "#1FFFFFFF"

            EmptyState {
                visible: !root.selectedPlaylist || !root.selectedPlaylist.name
                anchors.fill: parent
                iconText: "♪"
                title: root.loggedIn ? "选择一个歌单" : "请先登录"
                subtitle: root.loggedIn ? "从左侧选择要管理的歌单" : "登录后可以创建和管理自己的歌单"
                buttonText: ""
            }

            Column {
                visible: !!root.selectedPlaylist && !!root.selectedPlaylist.name
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // 歌单信息 + 操作
                Item {
                    width: parent.width
                    height: 92

                    Row {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        spacing: 14

                        Rectangle {
                            width: 82
                            height: 82
                            radius: 12
                            clip: true
                            color: "#1C1C26"

                            RetryImage {
                                anchors.fill: parent
                                coverSource: root.selectedPlaylist.pic || ""
                                sourceSize.width: 164
                                sourceSize.height: 164
                                fillMode: Image.PreserveAspectCrop
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !root.selectedPlaylist.pic
                                text: "♪"
                                color: AppTheme.textMuted
                                font.pixelSize: 28
                                font.family: AppTheme.fontFamily
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            width: rightPanel.width - 190

                            Text {
                                width: parent.width
                                text: root.selectedPlaylist.name || ""
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeTitleLg
                                font.bold: true
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textPrimary
                            }
                            Text {
                                width: parent.width
                                text: (root.selectedPlaylist.list_create_username || "我")
                                      + " · " + root.songCount + " 首 · "
                                      + (Number(root.selectedPlaylist.type) === 1 ? "收藏歌单" : "自建歌单")
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                            }
                            Row {
                                spacing: 7

                                ActionButton {
                                    label: "播放全部"
                                    iconSource: AppIcon.playCircle
                                    accent: true
                                    enabled: root.songs.length > 0
                                    onClicked: root.playAllFrom(0)
                                }
                                ActionButton {
                                    label: root.manageMode ? "退出管理" : "批量管理"
                                    iconSource: AppIcon.listChecks
                                    enabled: root.canRemoveSongs(root.selectedPlaylist) && root.songs.length > 0
                                    onClicked: {
                                        root.manageMode = !root.manageMode
                                        root.selectedFileids = ({})
                                    }
                                }
                                ActionButton {
                                    visible: root.canRename(root.selectedPlaylist)
                                    label: "重命名"
                                    iconSource: AppIcon.textAA
                                    onClicked: renameDialog.openFor(root.selectedPlaylist)
                                }
                                ActionButton {
                                    visible: root.canDelete(root.selectedPlaylist) || root.canUncollect(root.selectedPlaylist)
                                    label: root.canUncollect(root.selectedPlaylist) ? "取消收藏" : "删除"
                                    iconSource: AppIcon.deleteIcon
                                    danger: true
                                    onClicked: root.openPlaylistDeleteConfirm()
                                }
                            }
                        }
                    }
                }

                // 歌曲搜索 + 数量
                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: parent.width - 90
                        height: 30
                        radius: 8
                        color: AppTheme.bgCard
                        border.width: 1
                        border.color: songSearchInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault

                        TextInput {
                            id: songSearchInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.family: AppTheme.fontFamily
                            selectByMouse: true
                            onTextChanged: {
                                root.songSearch = text
                                root.applySongFilter()
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "搜索歌单内歌曲"
                                color: AppTheme.textDim
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                visible: songSearchInput.text === ""
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.songCount + " 首"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                }

                // 批量操作条
                Rectangle {
                    visible: root.manageMode
                    width: parent.width
                    height: 34
                    radius: 8
                    color: "#18FF6B6B"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "已选 " + root.selectedCount + " 首"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textSecondary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "全选"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: selectAllHover.hovered ? AppTheme.accent : AppTheme.textMuted
                            HoverHandler { id: selectAllHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: root.selectAll()
                            }
                        }
                        Item { width: parent.width - 210; height: 1 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "移除选中"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.bold: true
                            font.family: AppTheme.fontFamily
                            color: root.selectedCount > 0 ? AppTheme.errorColor : AppTheme.textDim
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.selectedCount > 0
                                onTapped: {
                                    var ids = []
                                    for (var k in root.selectedFileids) ids.push(k)
                                    root.openRemoveConfirm(ids)
                                }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "取消"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: cancelManageHover.hovered ? AppTheme.textPrimary : AppTheme.textMuted
                            HoverHandler { id: cancelManageHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: root.exitManageMode()
                            }
                        }
                    }
                }

                // 歌曲列表
                Item {
                    width: parent.width
                    height: parent.height - (root.manageMode ? 186 : 142) - (root.hasMoreSongs ? 32 : 0)

                    ListView {
                        id: songList
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: root.filteredSongs

                        ScrollBar.vertical: ScrollBar {
                            anchors.right: parent.right
                            width: 8
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                visible: parent.active
                                width: 8
                                radius: 4
                                color: AppTheme.scrollbarColor
                            }
                        }

                        delegate: HoverRow {
                            id: songRow
                            width: songList.width
                            height: 56
                            radius: 7
                            hovered: songHover.hovered

                            readonly property var songData: root.filteredSongs[index] || ({})

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 9

                                CheckBox {
                                    visible: root.manageMode
                                    checked: !!root.selectedFileids[String(songRow.songData.fileid || "")]
                                    anchors.verticalCenter: parent.verticalCenter
                                    onToggled: root.toggleSelect(songRow.songData.fileid)
                                }

                                Item {
                                    width: 22
                                    height: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: (index + 1).toString().padStart(2, "0")
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: playlistmanager && playlistmanager.currentSonghash === songRow.songData.hash
                                               ? AppTheme.accentPlaying : AppTheme.textMuted
                                    }
                                }

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 7
                                    clip: true
                                    color: "#1C1C26"
                                    anchors.verticalCenter: parent.verticalCenter

                                    RetryImage {
                                        anchors.fill: parent
                                        coverSource: songRow.songData.cover || ""
                                        sourceSize.width: 72
                                        sourceSize.height: 72
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                Column {
                                    width: parent.width - 22 - 36 - 20 - (root.manageMode ? 18 : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: songRow.songData.songname || ""
                                        elide: Text.ElideRight
                                        font.pixelSize: AppTheme.fontSizeSmall
                                        font.bold: true
                                        font.family: AppTheme.fontFamily
                                        color: (songHover.hovered || (playlistmanager && playlistmanager.currentSonghash === songRow.songData.hash))
                                               ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                    }
                                    Text {
                                        width: parent.width
                                        text: songRow.songData.singername || ""
                                        elide: Text.ElideRight
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.textMuted
                                    }
                                }

                                Text {
                                    width: 110
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: songRow.songData.album_name || ""
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textMuted
                                    visible: songList.width > 520
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: songRow.songData.duration || "--:--"
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textMuted
                                }

                                Row {
                                    visible: songHover.hovered || climaxBtn.active
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    ClimaxPreviewButton {
                                        id: climaxBtn
                                        compact: true
                                        songHash: songRow.songData.hash || ""
                                        songTitle: songRow.songData.songname || ""
                                        songSinger: songRow.songData.singername || ""
                                        songCover: songRow.songData.cover || ""
                                        rowHovered: songHover.hovered
                                    }

                                    IconButton {
                                        visible: !root.isTogetherMode
                                        iconSource: AppIcon.playCircle
                                        size: 24
                                        iconSize: 14
                                        onClicked: root.playSingle(songRow.songData)
                                    }
                                    IconButton {
                                        visible: root.isTogetherMode
                                        iconSource: AppIcon.addTogether
                                        size: 24
                                        iconSize: 14
                                        onClicked: root.addSongToTogether(songRow.songData)
                                    }
                                }
                            }

                            HoverHandler { id: songHover }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    if (root.manageMode) {
                                        root.toggleSelect(songRow.songData.fileid)
                                        return
                                    }
                                    if (songHover.hovered && climaxBtn.active)
                                        return
                                }
                                onDoubleTapped: {
                                    if (!root.manageMode)
                                        root.playSingle(songRow.songData)
                                }
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: BasicConfig.requestSongContextMenu({
                                    "songname": songRow.songData.songname || "",
                                    "songhash": songRow.songData.hash || "",
                                    "singername": songRow.songData.singername || "",
                                    "union_cover": songRow.songData.cover || "",
                                    "album_name": songRow.songData.album_name || "",
                                    "duration": songRow.songData.duration || "",
                                    "mvhash": songRow.songData.mvhash || ""
                                }, {
                                    "togetherMode": root.isTogetherMode,
                                    "showRemove": root.canRemoveSongs(root.selectedPlaylist),
                                    "onRemove": function() { root.openRemoveConfirm([songRow.songData.fileid]) }
                                })
                            }
                        }
                    }

                    EmptyState {
                        visible: !root.loadingDetail && root.filteredSongs.length === 0
                        anchors.fill: parent
                        iconText: "♪"
                        title: root.loadingDetail ? "正在加载歌曲..." : (root.songSearch !== "" ? "没有匹配歌曲" : "歌单还是空的")
                        subtitle: root.loadingDetail ? "" : "通过歌曲右键「添加到歌单」补充歌曲"
                        buttonText: ""
                    }
                }

                // 加载更多
                Text {
                    visible: root.hasMoreSongs && !root.loadingMoreSongs
                    width: parent.width
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: "加载更多歌曲"
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.family: AppTheme.fontFamily
                    color: moreHover.hovered ? AppTheme.accent : AppTheme.textMuted
                    HoverHandler { id: moreHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            root.detailPage += 1
                            root.loadDetailPage(root.detailPage)
                        }
                    }
                }
            }
        }
    }

    // ---------- 操作按钮 ----------
    component ActionButton: Rectangle {
        id: action
        property string label: ""
        property string iconSource: ""
        property bool accent: false
        property bool danger: false
        property bool enabled: true
        signal clicked

        width: actionRow.implicitWidth + 22
        height: 28
        radius: 14
        opacity: action.enabled ? 1 : 0.4
        color: action.accent ? (actionHover.hovered ? AppTheme.accentHover : AppTheme.accent)
                             : (action.danger ? "#20FF6B6B" : (actionHover.hovered ? "#24FFFFFF" : "#14FFFFFF"))
        border.width: 1
        border.color: action.accent ? "transparent" : (action.danger ? "#40FF6B6B" : "#25FFFFFF")

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 5

            Image {
                width: 12
                height: 12
                source: action.iconSource
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
                visible: action.iconSource !== ""
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: action.accent ? "#FFFFFF"
                                        : (action.danger ? AppTheme.errorColor : AppTheme.textSecondary)
                }
            }
            Text {
                text: action.label
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
                color: action.accent ? "#FFFFFF"
                                     : (action.danger ? AppTheme.errorColor : AppTheme.textSecondary)
            }
        }
        HoverHandler { id: actionHover }
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            enabled: action.enabled
            onTapped: action.clicked()
        }
    }

    component CheckBox: Rectangle {
        id: cb
        property bool checked: false
        signal toggled
        width: 18
        height: 18
        radius: 5
        color: cb.checked ? AppTheme.accent : "transparent"
        border.width: 1
        border.color: cb.checked ? AppTheme.accent : AppTheme.borderDefault

        Image {
            anchors.centerIn: parent
            width: 10
            height: 10
            visible: cb.checked
            source: AppIcon.check
            sourceSize: Qt.size(40, 40)
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay { color: "#FFFFFF" }
        }
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: cb.toggled()
        }
    }

    // ---------- 新建 ----------
    CreatePlaylistDialog {
        id: createPlaylistDialog
        onCreated: {
            root.refreshPlaylists()
            BasicConfig.noticeSuccess("已创建歌单: " + name)
        }
    }

    // ---------- 重命名 ----------
    ThemedPopup {
        id: renameDialog
        width: 380
        height: 190
        property var playlist: ({})

        function openFor(p) {
            playlist = p || ({})
            renameInput.text = p ? (p.name || "") : ""
            open()
            renameInput.forceActiveFocus()
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: "重命名歌单"
                font.pixelSize: AppTheme.fontSizeTitle
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: AppTheme.bgCard
                border.width: 1
                border.color: renameInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault

                TextInput {
                    id: renameInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    color: AppTheme.textPrimary
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    selectByMouse: true
                    onAccepted: renameConfirmTap.confirm()
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                ActionButton {
                    label: "取消"
                    onClicked: renameDialog.close()
                }
                ActionButton {
                    id: renameConfirmTap
                    label: "保存"
                    accent: true
                    function confirm() {
                        var name = renameInput.text.trim()
                        if (name === "" || !renameDialog.playlist.name) {
                            BasicConfig.noticeError("歌单名称不能为空")
                            return
                        }
                        playlistCollection.updatePlaylist(
                            String(renameDialog.playlist.listid),
                            Number(renameDialog.playlist.type || 0),
                            root.playlistTotalVer,
                            name
                        )
                    }
                    onClicked: confirm()
                }
            }
        }
    }

    // ---------- 删除 / 移除确认 ----------
    ThemedPopup {
        id: confirmDialog
        width: 400
        height: 190
        property string kind: ""
        property string title: ""
        property string message: ""
        property var fileids: []

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                width: parent.width
                text: confirmDialog.title
                font.pixelSize: AppTheme.fontSizeTitle
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
            }
            Text {
                width: parent.width
                text: confirmDialog.message
                wrapMode: Text.WordWrap
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textSecondary
                font.family: AppTheme.fontFamily
                lineHeight: 1.4
            }
            Item { width: 1; height: 4 }
            Row {
                anchors.right: parent.right
                spacing: 10

                ActionButton {
                    label: "取消"
                    onClicked: confirmDialog.close()
                }
                ActionButton {
                    label: "确定"
                    danger: true
                    onClicked: {
                        if (!root.selectedPlaylist || !root.selectedPlaylist.name) return
                        if (confirmDialog.kind === "removeSongs") {
                            playlistCollection.removeTracks(
                                String(root.selectedPlaylist.listid),
                                confirmDialog.fileids,
                                Number(root.selectedPlaylist.type || 0),
                                root.listVer
                            )
                        } else {
                            playlistCollection.deletePlaylist(
                                String(root.selectedPlaylist.listid),
                                Number(root.selectedPlaylist.type || 0),
                                root.playlistTotalVer
                            )
                        }
                    }
                }
            }
        }
    }
}
