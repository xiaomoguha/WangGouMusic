import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import NetworkRequest 1.0
import "../BasicConfig"
import "../ToolWindow"

Item {
    id: searchResultRoot

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "SearchresultPage"
    clip: true

    // 页面入场：淡入 + 轻微上浮
    opacity: 0
    transform: Translate { id: searchResultRootEnterShift; y: 14 }

    Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: {
            if (BasicConfig.uiIdle) {
                searchResultRoot.opacity = 1
                searchResultRootEnterShift.y = 0
            } else {
                searchResultRootEnterAnim.start()
            }
        }
    }

    ParallelAnimation {
        id: searchResultRootEnterAnim
        NumberAnimation {
            target: searchResultRoot; property: "opacity"
            from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: searchResultRootEnterShift; property: "y"
            from: 14; to: 0; duration: 420; easing.type: Easing.OutCubic
        }
    }

    property string keyword: BasicConfig.searchKeyword
    property bool _ready: false
    property int currentTab: 0

    readonly property var tabNames: ["综合", "单曲", "歌单", "专辑", "歌手", "MV", "歌词"]

    // ── 综合页预览数据 ──
    ListModel { id: songPreviewModel }
    ListModel { id: playlistModel }
    ListModel { id: albumModel }
    ListModel { id: artistModel }
    ListModel { id: mvModel }
    ListModel { id: lyricModel }

    property int songPreviewTotal: 0
    property int playlistTotal: 0
    property int albumTotal: 0
    property int artistTotal: 0
    property int mvTotal: 0
    property int lyricTotal: 0

    // ── 分页 / 加载状态 ──
    property int playlistPage: 0
    property int albumPage: 0
    property int artistPage: 0
    property int mvPage: 0
    property int lyricPage: 0

    property bool playlistLoading: false
    property bool albumLoading: false
    property bool artistLoading: false
    property bool mvLoading: false
    property bool lyricLoading: false

    property bool playlistHasMore: false
    property bool albumHasMore: false
    property bool artistHasMore: false
    property bool mvHasMore: false
    property bool lyricHasMore: false

    property int pendingPreviews: 0
    property bool songPreviewInFlight: false
    property bool playlistPreviewInFlight: false
    property bool albumPreviewInFlight: false
    property bool artistPreviewInFlight: false
    property bool mvPreviewInFlight: false
    property bool lyricPreviewInFlight: false

    // 每个请求的元信息：{ keyword, page, preview, full }
    property var reqMeta: ({})

    // ── 工具函数 ──
    function fmtTotal(n) {
        n = Number(n || 0)
        if (n >= 10000)
            return (n / 10000).toFixed(1) + "万"
        return String(n)
    }

    function fmtDuration(sec) {
        sec = parseInt(sec)
        if (!isFinite(sec) || sec <= 0)
            return "--:--"
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function coverUrl(url, size) {
        var s = String(url || "")
        return s.replace("{size}", size || "240")
    }

    function parseRoot(data) {
        try {
            return JSON.parse(data)
        } catch (e) {
            console.log("[SearchPage] json parse error:", e)
            return null
        }
    }

    function mapSong(v) {
        var tp = v.trans_param || ({})
        var cover = tp.union_cover || v.cover || ""
        return {
            "songname": v.songname || v.SongName || "",
            "singername": v.singername || v.SingerName || "",
            "album_name": v.album_name || "",
            "duration": fmtDuration(v.duration || v.TimeLength),
            "songhash": v.hash || v.FileHash || "",
            "union_cover": coverUrl(cover, "240"),
            "mvhash": v.mvhash || ""
        }
    }

    function mapPlaylist(v) {
        return {
            "title": v.specialname || "",
            "subtitle": (v.song_count || 0) + " 首 · " + (v.nickname || "酷狗音乐"),
            "cover": coverUrl(v.img, "240"),
            "gid": v.gid || "",
            "intro": v.intro || ""
        }
    }

    function mapAlbum(v) {
        var year = v.publish_time ? String(v.publish_time).substring(0, 4) : ""
        var sub = v.singer || ""
        if (year !== "")
            sub += " · " + year
        if (v.songcount)
            sub += " · " + v.songcount + " 首"
        return {
            "title": v.albumname || "",
            "subtitle": sub,
            "cover": coverUrl(v.img, "240"),
            "albumid": String(v.albumid || "")
        }
    }

    function mapArtist(v) {
        return {
            "title": v.AuthorName || "",
            "subtitle": fmtTotal(v.FansNum || 0) + " 粉丝 · " + (v.AudioCount || 0) + " 首 · "
                        + (v.AlbumCount || 0) + " 张专辑",
            "cover": v.Avatar || "",
            "artistid": String(v.AuthorId || "")
        }
    }

    function mapMv(v) {
        return {
            "title": v.MvName || v.FileName || "",
            "subtitle": (v.SingerName || "") + " · " + fmtDuration(v.Duration),
            "cover": v.ThumbGif || "",
            "mvhash": v.MvHash || "",
            "songhash": v.FileHash || "",
            "singername": v.SingerName || "",
            "duration": fmtDuration(v.Duration)
        }
    }

    function escapeHtml(text) {
        return String(text || "")
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;")
    }

    function highlightLyric(text, kw) {
        var raw = String(text || "")
        var needle = String(kw || "")
        if (needle === "")
            return escapeHtml(raw)

        var lowerRaw = raw.toLowerCase()
        var lowerNeedle = needle.toLowerCase()
        var out = ""
        var pos = 0
        var idx = lowerRaw.indexOf(lowerNeedle)
        while (idx >= 0) {
            out += escapeHtml(raw.substring(pos, idx))
            out += "<span style=\"color:#FF6B6B;font-weight:600;\">"
                    + escapeHtml(raw.substring(idx, idx + needle.length)) + "</span>"
            pos = idx + needle.length
            idx = lowerRaw.indexOf(lowerNeedle, pos)
        }
        out += escapeHtml(raw.substring(pos))
        return out
    }

    function mapLyric(v) {
        var tp = v.trans_param || ({})
        return {
            "title": v.SongName || "",
            "singername": v.SingerName || "",
            "lyric": v.Lyric || "",
            "lyricHtml": highlightLyric(v.Lyric || "", keyword),
            "songhash": v.FileHash || "",
            "cover": coverUrl(tp.union_cover || v.Image, "240"),
            "duration": fmtDuration(v.TimeLength)
        }
    }

    function appendModel(model, items) {
        for (var i = 0; i < items.length; i++)
            model.append(items[i])
    }

    function playlistUrl(type, page, pageSize) {
        return "https://api.special520.com/search?keywords=" + encodeURIComponent(keyword)
                + "&type=" + type + "&page=" + page + "&pagesize=" + pageSize
                + "&timestamp=" + Date.now()
    }

    function openPlaylist(item) {
        if (!item || !item.gid)
            return
        BasicConfig.openPlaylistDetail(item.gid, item.title, item.cover, item.intro || "")
    }

    function openAlbum(item) {
        if (!item || !item.albumid)
            return
        BasicConfig.openAlbum(item.albumid, item.title, item.cover)
    }

    function openArtist(item) {
        if (!item || !item.artistid)
            return
        BasicConfig.openArtist(item.artistid, item.title)
    }

    function playSong(item) {
        if (!item || !item.songhash || !playlistmanager)
            return
        if (playlistmanager.type === 1) {
            BasicConfig.togetherAddSongs(websocket, [item])
            return
        }
        playlistmanager.playNextAndPlay({
            "songname": item.songname || "",
            "songhash": item.songhash || "",
            "singername": item.singername || "",
            "union_cover": item.union_cover || "",
            "album_name": item.album_name || "",
            "duration": item.duration || ""
        })
        BasicConfig.emitSongAdded("正在播放: " + (item.songname || ""))
    }

    function playMv(item) {
        if (!item || !item.mvhash)
            return
        BasicConfig.requestMvPlay({
            "mvhash": item.mvhash,
            "title": item.title || "",
            "singername": item.singername || "",
            "songhash": item.songhash || "",
            "cover": item.cover || ""
        })
    }

    function playLyric(item) {
        if (!item || !item.songhash || !playlistmanager)
            return
        playlistmanager.playNextAndPlay({
            "songname": item.title || "",
            "songhash": item.songhash || "",
            "singername": item.singername || "",
            "union_cover": item.cover || "",
            "album_name": "",
            "duration": item.duration || ""
        })
        BasicConfig.emitSongAdded("正在播放: " + (item.title || ""))
    }

    // ── 请求 ──
    HttpGetRequester {
        id: songPreviewRequester
        onDataReceived: function (data) { searchResultRoot.handleSongPreview(data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("song", error) }
    }
    HttpGetRequester {
        id: playlistRequester
        onDataReceived: function (data) { searchResultRoot.handleCategoryData("special", data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("special", error) }
    }
    HttpGetRequester {
        id: albumRequester
        onDataReceived: function (data) { searchResultRoot.handleCategoryData("album", data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("album", error) }
    }
    HttpGetRequester {
        id: artistRequester
        onDataReceived: function (data) { searchResultRoot.handleCategoryData("author", data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("author", error) }
    }
    HttpGetRequester {
        id: mvRequester
        onDataReceived: function (data) { searchResultRoot.handleCategoryData("mv", data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("mv", error) }
    }
    HttpGetRequester {
        id: lyricRequester
        onDataReceived: function (data) { searchResultRoot.handleCategoryData("lyric", data) }
        onRequestFailed: function (error) { searchResultRoot.onRequestFailed("lyric", error) }
    }

    function clearAll() {
        songPreviewModel.clear()
        playlistModel.clear()
        albumModel.clear()
        artistModel.clear()
        mvModel.clear()
        lyricModel.clear()

        songPreviewTotal = 0
        playlistTotal = 0
        albumTotal = 0
        artistTotal = 0
        mvTotal = 0
        lyricTotal = 0

        playlistPage = 0
        albumPage = 0
        artistPage = 0
        mvPage = 0
        lyricPage = 0

        playlistLoading = false
        albumLoading = false
        artistLoading = false
        mvLoading = false
        lyricLoading = false

        playlistHasMore = false
        albumHasMore = false
        artistHasMore = false
        mvHasMore = false
        lyricHasMore = false

        pendingPreviews = 0
        songPreviewInFlight = false
        playlistPreviewInFlight = false
        albumPreviewInFlight = false
        artistPreviewInFlight = false
        mvPreviewInFlight = false
        lyricPreviewInFlight = false
        reqMeta = ({})
    }

    function fetchAll() {
        if (!_ready || keyword === "")
            return
        clearAll()

        // 单曲页签用现有的 C++ 模型（支持无限滚动、右键菜单、AI 展开）
        complexsearch.fetchComplexData(keyword)

        fetchSongPreview()

        // 每个分类都先拉 30 条：综合页只展示前 4/5 条，切到分类页也不用再补第一页
        fetchPlaylists(1, 30, true)
        fetchAlbums(1, 30, true)
        fetchArtists(1, 30, true)
        fetchMvs(1, 30, true)
        fetchLyrics(1, 30, true)
    }

    function fetchSongPreview() {
        songPreviewInFlight = true
        pendingPreviews++
        reqMeta["song"] = { "keyword": keyword, "page": 1, "preview": true }
        songPreviewRequester.fetchData(playlistUrl("song", 1, 6))
    }

    function fetchPlaylists(page, pageSize, trackPending) {
        reqMeta["special"] = { "keyword": keyword, "page": page, "pending": trackPending }
        playlistRequester.fetchData(playlistUrl("special", page, pageSize))
        playlistLoading = true
        if (trackPending) {
            playlistPreviewInFlight = true
            pendingPreviews++
        }
    }

    function fetchAlbums(page, pageSize, trackPending) {
        reqMeta["album"] = { "keyword": keyword, "page": page, "pending": trackPending }
        albumRequester.fetchData(playlistUrl("album", page, pageSize))
        albumLoading = true
        if (trackPending) {
            albumPreviewInFlight = true
            pendingPreviews++
        }
    }

    function fetchArtists(page, pageSize, trackPending) {
        reqMeta["author"] = { "keyword": keyword, "page": page, "pending": trackPending }
        artistRequester.fetchData(playlistUrl("author", page, pageSize))
        artistLoading = true
        if (trackPending) {
            artistPreviewInFlight = true
            pendingPreviews++
        }
    }

    function fetchMvs(page, pageSize, trackPending) {
        reqMeta["mv"] = { "keyword": keyword, "page": page, "pending": trackPending }
        mvRequester.fetchData(playlistUrl("mv", page, pageSize))
        mvLoading = true
        if (trackPending) {
            mvPreviewInFlight = true
            pendingPreviews++
        }
    }

    function fetchLyrics(page, pageSize, trackPending) {
        reqMeta["lyric"] = { "keyword": keyword, "page": page, "pending": trackPending }
        lyricRequester.fetchData(playlistUrl("lyric", page, pageSize))
        lyricLoading = true
        if (trackPending) {
            lyricPreviewInFlight = true
            pendingPreviews++
        }
    }

    function handleSongPreview(data) {
        if (songPreviewInFlight) {
            songPreviewInFlight = false
            pendingPreviews = Math.max(0, pendingPreviews - 1)
        }
        var meta = reqMeta["song"] || ({})
        if (meta.keyword !== keyword)
            return
        var root = parseRoot(data)
        if (!root)
            return
        var d = root.data || ({})
        var arr = d.info || d.lists || []
        songPreviewTotal = d.total || arr.length || 0
        songPreviewModel.clear()
        for (var i = 0; i < arr.length; i++)
            songPreviewModel.append(mapSong(arr[i]))
    }

    function handleCategoryData(type, data) {
        var meta = reqMeta[type] || ({})
        var trackPending = !!meta.pending
        if (trackPending) {
            if (type === "special") {
                if (playlistPreviewInFlight) {
                    playlistPreviewInFlight = false
                    pendingPreviews = Math.max(0, pendingPreviews - 1)
                }
            } else if (type === "album") {
                if (albumPreviewInFlight) {
                    albumPreviewInFlight = false
                    pendingPreviews = Math.max(0, pendingPreviews - 1)
                }
            } else if (type === "author") {
                if (artistPreviewInFlight) {
                    artistPreviewInFlight = false
                    pendingPreviews = Math.max(0, pendingPreviews - 1)
                }
            } else if (type === "mv") {
                if (mvPreviewInFlight) {
                    mvPreviewInFlight = false
                    pendingPreviews = Math.max(0, pendingPreviews - 1)
                }
            } else if (type === "lyric") {
                if (lyricPreviewInFlight) {
                    lyricPreviewInFlight = false
                    pendingPreviews = Math.max(0, pendingPreviews - 1)
                }
            }
        }
        if (meta.keyword !== keyword)
            return

        var root = parseRoot(data)
        if (!root)
            return
        var d = root.data || ({})
        var lists = d.lists || []
        var total = d.total || lists.length || 0
        var page = Number(meta.page || 1)
        var replace = page === 1

        if (type === "special") {
            if (replace)
                playlistModel.clear()
            for (var i = 0; i < lists.length; i++)
                playlistModel.append(mapPlaylist(lists[i]))
            playlistTotal = total
            playlistPage = page
            playlistHasMore = playlistModel.count < total
            playlistLoading = false
        } else if (type === "album") {
            if (replace)
                albumModel.clear()
            for (var a = 0; a < lists.length; a++)
                albumModel.append(mapAlbum(lists[a]))
            albumTotal = total
            albumPage = page
            albumHasMore = albumModel.count < total
            albumLoading = false
        } else if (type === "author") {
            if (replace)
                artistModel.clear()
            for (var b = 0; b < lists.length; b++)
                artistModel.append(mapArtist(lists[b]))
            artistTotal = total
            artistPage = page
            artistHasMore = artistModel.count < total
            artistLoading = false
        } else if (type === "mv") {
            if (replace)
                mvModel.clear()
            for (var c = 0; c < lists.length; c++)
                mvModel.append(mapMv(lists[c]))
            mvTotal = total
            mvPage = page
            mvHasMore = mvModel.count < total
            mvLoading = false
        } else if (type === "lyric") {
            if (replace)
                lyricModel.clear()
            for (var e = 0; e < lists.length; e++)
                lyricModel.append(mapLyric(lists[e]))
            lyricTotal = total
            lyricPage = page
            lyricHasMore = lyricModel.count < total
            lyricLoading = false
        }
    }

    function onRequestFailed(type, error) {
        console.log("[SearchPage] request failed:", type, error)
        var meta = reqMeta[type] || ({})
        if (type === "song") {
            if (songPreviewInFlight) {
                songPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
        } else if (type === "special") {
            if (playlistPreviewInFlight) {
                playlistPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
            playlistLoading = false
        } else if (type === "album") {
            if (albumPreviewInFlight) {
                albumPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
            albumLoading = false
        } else if (type === "author") {
            if (artistPreviewInFlight) {
                artistPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
            artistLoading = false
        } else if (type === "mv") {
            if (mvPreviewInFlight) {
                mvPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
            mvLoading = false
        } else if (type === "lyric") {
            if (lyricPreviewInFlight) {
                lyricPreviewInFlight = false
                pendingPreviews = Math.max(0, pendingPreviews - 1)
            }
            lyricLoading = false
        }
    }

    // 初始请求失败/为空时，切到对应页签再补拉一次
    function ensureTabLoaded(tab) {
        if (tab === 2 && playlistModel.count === 0 && !playlistLoading)
            fetchPlaylists(1, 30, false)
        else if (tab === 3 && albumModel.count === 0 && !albumLoading)
            fetchAlbums(1, 30, false)
        else if (tab === 4 && artistModel.count === 0 && !artistLoading)
            fetchArtists(1, 30, false)
        else if (tab === 5 && mvModel.count === 0 && !mvLoading)
            fetchMvs(1, 30, false)
        else if (tab === 6 && lyricModel.count === 0 && !lyricLoading)
            fetchLyrics(1, 30, false)
    }

    function loadMore(tab) {
        if (tab === 2 && playlistHasMore && !playlistLoading)
            fetchPlaylists(playlistPage + 1, 30, false)
        else if (tab === 3 && albumHasMore && !albumLoading)
            fetchAlbums(albumPage + 1, 30, false)
        else if (tab === 4 && artistHasMore && !artistLoading)
            fetchArtists(artistPage + 1, 30, false)
        else if (tab === 5 && mvHasMore && !mvLoading)
            fetchMvs(mvPage + 1, 30, false)
        else if (tab === 6 && lyricHasMore && !lyricLoading)
            fetchLyrics(lyricPage + 1, 30, false)
    }

    function activeCount() {
        switch (currentTab) {
        case 1: return complexsearch ? complexsearch.count : 0
        case 2: return playlistModel.count
        case 3: return albumModel.count
        case 4: return artistModel.count
        case 5: return mvModel.count
        case 6: return lyricModel.count
        }
        return 0
    }

    function activeLoading() {
        switch (currentTab) {
        case 1: return complexsearch ? complexsearch.isLoading : false
        case 2: return playlistLoading
        case 3: return albumLoading
        case 4: return artistLoading
        case 5: return mvLoading
        case 6: return lyricLoading
        }
        return false
    }

    function activeTotal() {
        switch (currentTab) {
        case 0:
        case 1: return complexsearch && complexsearch.total > 0 ? complexsearch.total : songPreviewTotal
        case 2: return playlistTotal
        case 3: return albumTotal
        case 4: return artistTotal
        case 5: return mvTotal
        case 6: return lyricTotal
        }
        return 0
    }

    function activeUnit() {
        switch (currentTab) {
        case 2: return "个歌单"
        case 3: return "张专辑"
        case 4: return "位歌手"
        case 5: return "个 MV"
        case 6: return "条歌词"
        }
        return "首歌曲"
    }

    function activeName() {
        switch (currentTab) {
        case 2: return "歌单"
        case 3: return "专辑"
        case 4: return "歌手"
        case 5: return "MV"
        case 6: return "歌词"
        }
        return "内容"
    }

    function previewEmpty() {
        return songPreviewModel.count === 0 && playlistModel.count === 0
                && albumModel.count === 0 && artistModel.count === 0
                && mvModel.count === 0 && lyricModel.count === 0
    }

    Component.onCompleted: {
        _ready = true
        BasicConfig.playlistPageActive = false
        if (keyword !== "")
            fetchAll()
    }

    onKeywordChanged: {
        if (!_ready)
            return
        currentTab = 0
        fetchAll()
    }

    onVisibleChanged: {
        if (visible)
            BasicConfig.playlistPageActive = false
    }

    onCurrentTabChanged: {
        if (_ready)
            ensureTabLoaded(currentTab)
    }

    // ════════════════════════════════════════════════════════════
    // 组件：搜索结果行
    // ════════════════════════════════════════════════════════════
    component CoverImage: Rectangle {
        id: coverRoot
        property string src: ""
        property bool circular: false
        property int radiusValue: 8
        width: 48
        height: 48
        radius: circular ? width / 2 : radiusValue
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

    component SectionHeader: Item {
        id: secHeader
        property string title: ""
        property int total: 0
        property bool showAll: false
        signal viewAll()
        width: parent ? parent.width : 0
        height: 36

        Rectangle {
            width: 3
            height: 15
            radius: 2
            color: AppTheme.accent
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: secTitle
            text: secHeader.title
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 16
            font.bold: true
            color: AppTheme.textPrimary
            font.family: AppTheme.fontFamily
        }
        Text {
            text: secHeader.total > 0 ? BasicConfig.formatCount(secHeader.total) : ""
            anchors.left: secTitle.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: AppTheme.fontSizeCaption
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }
        Text {
            visible: secHeader.showAll
            text: "查看全部 ›"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: AppTheme.fontSizeSmall
            color: secHover.hovered ? AppTheme.accentPlaying : AppTheme.accent
            font.family: AppTheme.fontFamily
            HoverHandler { id: secHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: secHeader.viewAll()
            }
        }
    }

    component SongRow: HoverRow {
        id: songRowItem
        property var itemData: ({})
        property int itemIndex: 0
        signal activated(var item)
        height: 56 + aiExpand.expandedHeight
        radius: 8
        color: "transparent"
        hovered: songRowHover.hovered

        readonly property bool isPlaying: !!(playlistmanager && playlistmanager.currentSonghash === itemData.songhash)
        readonly property bool isTogether: !!(playlistmanager && playlistmanager.type === 1)

        HoverHandler { id: songRowHover }

        // 行内容固定在 56 高，下方让位给 AI 展开
        Item {
            width: parent.width
            height: 56

            // 左侧：序号 / 播放指示 + 封面 + 歌名/歌手
            Row {
                x: 0.025 * songRowItem.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Item {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: (songRowItem.itemIndex + 1).toString().padStart(2, "0")
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        color: songRowItem.isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                        visible: !songRowItem.isPlaying
                    }

                    NowPlayingIndicator {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        visible: songRowItem.isPlaying
                        playing: playlistmanager ? !playlistmanager.isPaused : true
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
                    width: 0.2 * songRowItem.width
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

            // 操作按钮：悬停显示，位置与单曲页一致
            Row {
                id: actionRow
                visible: songRowHover.hovered || climaxPreviewBtn.active
                x: 0.025 * songRowItem.width + 28 + 12 + 40 + 12 + 0.2 * songRowItem.width + 12
                width: 88
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                z: 1

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
                    visible: !songRowItem.isTogether && !songRowItem.isPlaying
                    iconSource: AppIcon.playCircle
                    size: 24
                    iconSize: 14
                    onClicked: songRowItem.activated(songRowItem.itemData)
                }

                IconButton {
                    visible: songRowItem.isTogether && !songRowItem.isPlaying
                    iconSource: AppIcon.addTogether
                    size: 24
                    iconSize: 14
                    iconColor: hovered ? AppTheme.accent : AppTheme.iconDefault
                    onClicked: songRowItem.activated(songRowItem.itemData)
                }
            }

            // 专辑名
            Text {
                x: 0.48 * songRowItem.width
                anchors.verticalCenter: parent.verticalCenter
                width: 0.28 * songRowItem.width
                text: songRowItem.itemData.album_name || ""
                elide: Text.ElideRight
                font.pixelSize: AppTheme.fontSizeBody
                font.bold: true
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }

            // 时长
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 0.04 * songRowItem.width
                anchors.verticalCenter: parent.verticalCenter
                text: songRowItem.itemData.duration || "--:--"
                font.pixelSize: AppTheme.fontSizeBody
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
        }

        // AI 推荐展开
        AiRecommendExpand {
            id: aiExpand
            anchors.top: parent.top
            anchors.topMargin: 56
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 44
            anchors.rightMargin: 14
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
            onTapped: songRowItem.activated(songRowItem.itemData)
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: BasicConfig.requestSongContextMenu(songRowItem.contextSong(), {
                "togetherMode": songRowItem.isTogether,
                "showAi": true,
                "onAi": function() { aiExpand.toggle(songRowItem.itemData.songhash, songRowItem.itemData.songname) }
            })
        }
    }
    component PlaylistRow: HoverRow {
        id: plRowItem
        property var itemData: ({})
        signal activated(var item)
        height: 64
        radius: 6
        hovered: plRowHover.hovered

        HoverHandler { id: plRowHover }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            CoverImage {
                id: plCover
                width: 48
                height: 48
                src: plRowItem.itemData.cover || ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: plArrow
                text: "›"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 22
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
            Column {
                anchors.left: plCover.right
                anchors.leftMargin: 12
                anchors.right: plArrow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: plRowItem.itemData.title || "未命名歌单"
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: true
                    color: plRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }
                Text {
                    width: parent.width
                    text: plRowItem.itemData.subtitle || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: plRowItem.activated(plRowItem.itemData)
        }
    }

    component AlbumRow: HoverRow {
        id: alRowItem
        property var itemData: ({})
        signal activated(var item)
        height: 64
        radius: 6
        hovered: alRowHover.hovered

        HoverHandler { id: alRowHover }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            CoverImage {
                id: alCover
                width: 48
                height: 48
                src: alRowItem.itemData.cover || ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: alArrow
                text: "›"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 22
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
            Column {
                anchors.left: alCover.right
                anchors.leftMargin: 12
                anchors.right: alArrow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: alRowItem.itemData.title || "未命名专辑"
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: true
                    color: alRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }
                Text {
                    width: parent.width
                    text: alRowItem.itemData.subtitle || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: alRowItem.activated(alRowItem.itemData)
        }
    }

    component ArtistRow: HoverRow {
        id: arRowItem
        property var itemData: ({})
        signal activated(var item)
        height: 64
        radius: 6
        hovered: arRowHover.hovered

        HoverHandler { id: arRowHover }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            CoverImage {
                id: arCover
                width: 48
                height: 48
                circular: true
                src: arRowItem.itemData.cover || ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: arArrow
                text: "›"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 22
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
            Column {
                anchors.left: arCover.right
                anchors.leftMargin: 12
                anchors.right: arArrow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: arRowItem.itemData.title || "未知歌手"
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: true
                    color: arRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }
                Text {
                    width: parent.width
                    text: arRowItem.itemData.subtitle || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: arRowItem.activated(arRowItem.itemData)
        }
    }

    component MvRow: HoverRow {
        id: mvRowItem
        property var itemData: ({})
        signal activated(var item)
        height: 76
        radius: 6
        hovered: mvRowHover.hovered

        HoverHandler { id: mvRowHover }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            CoverImage {
                id: mvCover
                width: 96
                height: 54
                radiusValue: 6
                src: mvRowItem.itemData.cover || ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton {
                id: mvPlay
                iconSource: AppIcon.playCircle
                size: 28
                iconSize: 15
                iconColor: mvPlay.hovered ? "#4FC3F7" : AppTheme.textSecondary
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: mvRowItem.activated(mvRowItem.itemData)
            }
            Column {
                anchors.left: mvCover.right
                anchors.leftMargin: 12
                anchors.right: mvPlay.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: mvRowItem.itemData.title || "MV"
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: true
                    color: mvRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }
                Text {
                    width: parent.width
                    text: mvRowItem.itemData.subtitle || ""
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: mvRowItem.activated(mvRowItem.itemData)
        }
    }

    component LyricRow: HoverRow {
        id: lyRowItem
        property var itemData: ({})
        signal activated(var item)
        height: 92
        radius: 6
        hovered: lyRowHover.hovered

        HoverHandler { id: lyRowHover }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            CoverImage {
                id: lyCover
                width: 42
                height: 42
                radiusValue: 6
                src: lyRowItem.itemData.cover || ""
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 10
            }
            IconButton {
                id: lyPlay
                iconSource: AppIcon.playCircle
                size: 28
                iconSize: 15
                iconColor: lyPlay.hovered ? "#4FC3F7" : AppTheme.textSecondary
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: lyRowItem.activated(lyRowItem.itemData)
            }
            Column {
                anchors.left: lyCover.right
                anchors.leftMargin: 12
                anchors.right: lyPlay.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 8
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: lyRowItem.itemData.title || ""
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeBody
                        font.bold: true
                        color: lyRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }
                    Text {
                        text: lyRowItem.itemData.singername || ""
                        elide: Text.ElideRight
                        font.pixelSize: AppTheme.fontSizeCaption
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                }
                Text {
                    width: parent.width
                    text: lyRowItem.itemData.lyricHtml || ""
                    textFormat: Text.RichText
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: lyRowItem.activated(lyRowItem.itemData)
        }
    }

    component LoadFooter: Item {
        id: loadFooter
        property bool loading: false
        property bool hasMore: false
        property int total: 0
        signal loadMoreRequested()
        width: parent ? parent.width : 0
        height: total > 0 ? 48 : 0
        visible: total > 0

        Text {
            anchors.centerIn: parent
            text: loadFooter.loading ? "加载中..."
                  : (loadFooter.hasMore ? "上滑加载更多" : "没有更多了")
            font.pixelSize: AppTheme.fontSizeSmall
            color: loadFooter.hasMore ? AppTheme.textMuted : AppTheme.textDim
            font.family: AppTheme.fontFamily
        }
        TapHandler {
            enabled: loadFooter.hasMore && !loadFooter.loading
            cursorShape: Qt.PointingHandCursor
            onTapped: loadFooter.loadMoreRequested()
        }
    }

    component Spinner: Item {
        width: 26
        height: 26
        Image {
            id: spinnerImg
            anchors.fill: parent
            source: AppIcon.refresh
            sourceSize: Qt.size(52, 52)
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: spinnerImg
                color: AppTheme.accent
            }
            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: spinnerImg.visible && !BasicConfig.uiIdle
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // 页头：关键词 + 数量
    // ════════════════════════════════════════════════════════════
    Item {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 66

        Item {
            x: 30
            width: parent.width - 60
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: 10

                Text {
                    id: keywordText
                    width: Math.max(0, parent.width - countText.width - 12)
                    text: "“" + searchResultRoot.keyword + "”"
                    elide: Text.ElideRight
                    font.pixelSize: 22
                    font.bold: true
                    color: AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: countText
                    text: {
                        var total = searchResultRoot.activeTotal()
                        if (total > 0)
                            return searchResultRoot.fmtTotal(total) + " " + searchResultRoot.activeUnit()
                        if (searchResultRoot.currentTab === 0 && searchResultRoot.pendingPreviews > 0)
                            return "搜索中..."
                        return "没有结果"
                    }
                    font.pixelSize: AppTheme.fontSizeBody
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // 页签
    // ════════════════════════════════════════════════════════════
    Row {
        id: tabBar
        x: 30
        anchors.top: headerRow.bottom
        height: 42
        spacing: 28

        Repeater {
            model: searchResultRoot.tabNames

            delegate: Item {
                width: tabText.implicitWidth
                height: tabBar.height

                Text {
                    id: tabText
                    text: modelData
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: AppTheme.fontSizeBody
                    font.bold: index === searchResultRoot.currentTab
                    color: index === searchResultRoot.currentTab ? AppTheme.accent
                           : (tabHover.hovered ? AppTheme.textPrimary : AppTheme.textMuted)
                    font.family: AppTheme.fontFamily
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                }
                Rectangle {
                    width: tabText.implicitWidth
                    height: 2
                    radius: 1
                    color: AppTheme.accent
                    anchors.bottom: parent.bottom
                    visible: index === searchResultRoot.currentTab
                }

                HoverHandler { id: tabHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: searchResultRoot.currentTab = index
                }
            }
        }
    }

    Rectangle {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: AppTheme.borderDefault
        opacity: 0.5
    }

    // ════════════════════════════════════════════════════════════
    // 内容区
    // ════════════════════════════════════════════════════════════
    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        clip: true

        // ── 综合 ──
        Flickable {
            id: overviewFlick
            visible: searchResultRoot.currentTab === 0
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: overviewColumn.height + 28

            ScrollBar.vertical: ScrollBar {
                id: overviewScroll
                anchors.right: parent.right
                anchors.rightMargin: 4
                width: 9
                contentItem: Rectangle {
                    visible: overviewScroll.active
                    width: 9
                    radius: 4
                    color: AppTheme.scrollbarColor
                }
            }

            Column {
                id: overviewColumn
                x: 30
                y: 8
                width: overviewFlick.width - 60
                spacing: 14

                // 单曲
                Column {
                    width: parent.width
                    spacing: 2
                    visible: songPreviewModel.count > 0 || songPreviewTotal > 0
                    SectionHeader {
                        title: "单曲"
                        total: songPreviewTotal
                        showAll: songPreviewTotal > 5
                        onViewAll: searchResultRoot.currentTab = 1
                    }
                    Repeater {
                        model: Math.min(5, songPreviewModel.count)
                        delegate: SongRow {
                            width: overviewColumn.width
                            itemData: songPreviewModel.get(index) || ({})
                            itemIndex: index
                            onActivated: searchResultRoot.playSong(item)
                        }
                    }
                }

                // 歌手
                Column {
                    width: parent.width
                    spacing: 2
                    visible: artistModel.count > 0 || artistTotal > 0
                    SectionHeader {
                        title: "歌手"
                        total: artistTotal
                        showAll: artistTotal > 4
                        onViewAll: searchResultRoot.currentTab = 4
                    }
                    Repeater {
                        model: Math.min(4, artistModel.count)
                        delegate: Item {
                            width: overviewColumn.width
                            height: 64
                            ArtistRow {
                                anchors.fill: parent
                                itemData: artistModel.get(index) || ({})
                                onActivated: searchResultRoot.openArtist(item)
                            }
                        }
                    }
                }

                // 歌单
                Column {
                    width: parent.width
                    spacing: 2
                    visible: playlistModel.count > 0 || playlistTotal > 0
                    SectionHeader {
                        title: "歌单"
                        total: playlistTotal
                        showAll: playlistTotal > 4
                        onViewAll: searchResultRoot.currentTab = 2
                    }
                    Repeater {
                        model: Math.min(4, playlistModel.count)
                        delegate: Item {
                            width: overviewColumn.width
                            height: 64
                            PlaylistRow {
                                anchors.fill: parent
                                itemData: playlistModel.get(index) || ({})
                                onActivated: searchResultRoot.openPlaylist(item)
                            }
                        }
                    }
                }

                // 专辑
                Column {
                    width: parent.width
                    spacing: 2
                    visible: albumModel.count > 0 || albumTotal > 0
                    SectionHeader {
                        title: "专辑"
                        total: albumTotal
                        showAll: albumTotal > 4
                        onViewAll: searchResultRoot.currentTab = 3
                    }
                    Repeater {
                        model: Math.min(4, albumModel.count)
                        delegate: Item {
                            width: overviewColumn.width
                            height: 64
                            AlbumRow {
                                anchors.fill: parent
                                itemData: albumModel.get(index) || ({})
                                onActivated: searchResultRoot.openAlbum(item)
                            }
                        }
                    }
                }

                // MV
                Column {
                    width: parent.width
                    spacing: 2
                    visible: mvModel.count > 0 || mvTotal > 0
                    SectionHeader {
                        title: "MV"
                        total: mvTotal
                        showAll: mvTotal > 4
                        onViewAll: searchResultRoot.currentTab = 5
                    }
                    Repeater {
                        model: Math.min(4, mvModel.count)
                        delegate: Item {
                            width: overviewColumn.width
                            height: 76
                            MvRow {
                                anchors.fill: parent
                                itemData: mvModel.get(index) || ({})
                                onActivated: searchResultRoot.playMv(item)
                            }
                        }
                    }
                }

                // 歌词
                Column {
                    width: parent.width
                    spacing: 2
                    visible: lyricModel.count > 0 || lyricTotal > 0
                    SectionHeader {
                        title: "歌词"
                        total: lyricTotal
                        showAll: lyricTotal > 3
                        onViewAll: searchResultRoot.currentTab = 6
                    }
                    Repeater {
                        model: Math.min(3, lyricModel.count)
                        delegate: Item {
                            width: overviewColumn.width
                            height: 92
                            LyricRow {
                                anchors.fill: parent
                                itemData: lyricModel.get(index) || ({})
                                onActivated: searchResultRoot.playLyric(item)
                            }
                        }
                    }
                }

                // 搜索中 / 空
                Column {
                    width: parent.width
                    spacing: 10
                    topPadding: 40
                    bottomPadding: 40
                    visible: searchResultRoot.pendingPreviews > 0 && searchResultRoot.previewEmpty()
                    Spinner {
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "正在搜索..."
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10
                    topPadding: 60
                    bottomPadding: 60
                    visible: searchResultRoot.pendingPreviews === 0 && searchResultRoot.previewEmpty()

                    Rectangle {
                        width: 62
                        height: 62
                        radius: 31
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: AppTheme.accentSubtle
                        Text {
                            anchors.centerIn: parent
                            text: "♪"
                            font.pixelSize: 26
                            color: AppTheme.accent
                            font.family: AppTheme.fontFamily
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "没有找到相关内容"
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "换个关键词试试吧"
                        font.pixelSize: AppTheme.fontSizeSmall
                        color: AppTheme.textDim
                        font.family: AppTheme.fontFamily
                    }
                }
            }
        }

        // ── 单曲（复用原有列表） ──
        ComplexPage {
            visible: searchResultRoot.currentTab === 1
            anchors.fill: parent
        }

        // ── 歌单 ──
        ListView {
            id: playlistList
            visible: searchResultRoot.currentTab === 2
            anchors.fill: parent
            clip: true
            spacing: 2
            topMargin: 6
            leftMargin: 30
            rightMargin: 30
            model: playlistModel
            delegate: Item {
                id: playlistDelegate
                required property var modelData
                width: playlistList.width - 60
                height: 64
                PlaylistRow {
                    anchors.fill: parent
                    itemData: playlistDelegate.modelData
                    onActivated: searchResultRoot.openPlaylist(item)
                }
            }
            footer: LoadFooter {
                loading: searchResultRoot.playlistLoading
                hasMore: searchResultRoot.playlistHasMore
                total: searchResultRoot.playlistTotal
                onLoadMoreRequested: searchResultRoot.loadMore(2)
            }
            onContentYChanged: {
                if (searchResultRoot.playlistHasMore && !searchResultRoot.playlistLoading
                        && contentY + height >= contentHeight - 200)
                    searchResultRoot.loadMore(2)
            }
        }

        // ── 专辑 ──
        ListView {
            id: albumList
            visible: searchResultRoot.currentTab === 3
            anchors.fill: parent
            clip: true
            spacing: 2
            topMargin: 6
            leftMargin: 30
            rightMargin: 30
            model: albumModel
            delegate: Item {
                id: albumDelegate
                required property var modelData
                width: albumList.width - 60
                height: 64
                AlbumRow {
                    anchors.fill: parent
                    itemData: albumDelegate.modelData
                    onActivated: searchResultRoot.openAlbum(item)
                }
            }
            footer: LoadFooter {
                loading: searchResultRoot.albumLoading
                hasMore: searchResultRoot.albumHasMore
                total: searchResultRoot.albumTotal
                onLoadMoreRequested: searchResultRoot.loadMore(3)
            }
            onContentYChanged: {
                if (searchResultRoot.albumHasMore && !searchResultRoot.albumLoading
                        && contentY + height >= contentHeight - 200)
                    searchResultRoot.loadMore(3)
            }
        }

        // ── 歌手 ──
        ListView {
            id: artistList
            visible: searchResultRoot.currentTab === 4
            anchors.fill: parent
            clip: true
            spacing: 2
            topMargin: 6
            leftMargin: 30
            rightMargin: 30
            model: artistModel
            delegate: Item {
                id: artistDelegate
                required property var modelData
                width: artistList.width - 60
                height: 64
                ArtistRow {
                    anchors.fill: parent
                    itemData: artistDelegate.modelData
                    onActivated: searchResultRoot.openArtist(item)
                }
            }
            footer: LoadFooter {
                loading: searchResultRoot.artistLoading
                hasMore: searchResultRoot.artistHasMore
                total: searchResultRoot.artistTotal
                onLoadMoreRequested: searchResultRoot.loadMore(4)
            }
            onContentYChanged: {
                if (searchResultRoot.artistHasMore && !searchResultRoot.artistLoading
                        && contentY + height >= contentHeight - 200)
                    searchResultRoot.loadMore(4)
            }
        }

        // ── MV ──
        ListView {
            id: mvList
            visible: searchResultRoot.currentTab === 5
            anchors.fill: parent
            clip: true
            spacing: 2
            topMargin: 6
            leftMargin: 30
            rightMargin: 30
            model: mvModel
            delegate: Item {
                id: mvDelegate
                required property var modelData
                width: mvList.width - 60
                height: 76
                MvRow {
                    anchors.fill: parent
                    itemData: mvDelegate.modelData
                    onActivated: searchResultRoot.playMv(item)
                }
            }
            footer: LoadFooter {
                loading: searchResultRoot.mvLoading
                hasMore: searchResultRoot.mvHasMore
                total: searchResultRoot.mvTotal
                onLoadMoreRequested: searchResultRoot.loadMore(5)
            }
            onContentYChanged: {
                if (searchResultRoot.mvHasMore && !searchResultRoot.mvLoading
                        && contentY + height >= contentHeight - 200)
                    searchResultRoot.loadMore(5)
            }
        }

        // ── 歌词 ──
        ListView {
            id: lyricList
            visible: searchResultRoot.currentTab === 6
            anchors.fill: parent
            clip: true
            spacing: 2
            topMargin: 6
            leftMargin: 30
            rightMargin: 30
            model: lyricModel
            delegate: Item {
                id: lyricDelegate
                required property var modelData
                width: lyricList.width - 60
                height: 92
                LyricRow {
                    anchors.fill: parent
                    itemData: lyricDelegate.modelData
                    onActivated: searchResultRoot.playLyric(item)
                }
            }
            footer: LoadFooter {
                loading: searchResultRoot.lyricLoading
                hasMore: searchResultRoot.lyricHasMore
                total: searchResultRoot.lyricTotal
                onLoadMoreRequested: searchResultRoot.loadMore(6)
            }
            onContentYChanged: {
                if (searchResultRoot.lyricHasMore && !searchResultRoot.lyricLoading
                        && contentY + height >= contentHeight - 200)
                    searchResultRoot.loadMore(6)
            }
        }

        // ── 分类加载 / 空状态 ──
        Column {
            anchors.centerIn: parent
            spacing: 10
            z: 10
            visible: searchResultRoot.currentTab >= 2
                     && searchResultRoot.activeLoading()
                     && searchResultRoot.activeCount() === 0
            Spinner {
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "正在搜索" + searchResultRoot.activeName() + "..."
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            z: 10
            visible: searchResultRoot.currentTab >= 2
                     && !searchResultRoot.activeLoading()
                     && searchResultRoot.activeCount() === 0
                     && searchResultRoot.keyword !== ""

            Rectangle {
                width: 62
                height: 62
                radius: 31
                anchors.horizontalCenter: parent.horizontalCenter
                color: AppTheme.accentSubtle
                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 26
                    color: AppTheme.accent
                    font.family: AppTheme.fontFamily
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "没有找到相关" + searchResultRoot.activeName()
                font.pixelSize: AppTheme.fontSizeBodyLg
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "换个关键词试试吧"
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textDim
                font.family: AppTheme.fontFamily
            }
        }
    }
}
