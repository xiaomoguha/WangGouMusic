import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Item {
    objectName: "PlaylistDetailPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string playlistId: BasicConfig.playlistDetailId
    property string playlistName: BasicConfig.playlistDetailName
    property string playlistCover: BasicConfig.playlistDetailCover
    property string playlistIntro: BasicConfig.playlistDetailIntro
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    // 搜索状态
    property string searchKeyword: ""
    property var filteredTracks: []
    property bool isSearchAllLoaded: false   // 是否已为搜索全量加载
    property var searchTimer: null
    property bool _pendingPlayAll: false

    Component.onCompleted: {
        if (recommendation && playlistId !== "")
            recommendation.fetchPlaylistTracks(playlistId)
    }

    // 歌单详情页会被 Rightpage 的 Loader 缓存复用，切换不同歌单时
    // Component.onCompleted 不会再次触发，因此监听 id 变化重新拉取歌曲列表
    Connections {
        target: BasicConfig
        function onPlaylistDetailIdChanged() {
            if (recommendation && playlistId !== "") {
                tracksListView.contentY = 0
                searchKeyword = ""
                filteredTracks = []
                isSearchAllLoaded = false
                _pendingPlayAll = false
                recommendation.fetchPlaylistTracks(playlistId)
            }
        }
    }

    // 搜索：输入时防抖，触发全量加载后客户端过滤
    function doSearch() {
        var kw = searchKeyword.trim()
        if (kw === "") {
            filteredTracks = []
            // 清空搜索后恢复分页（重新拉第 1 页）
            if (recommendation) {
                recommendation.fetchPlaylistTracks(playlistId)
            }
            return
        }
        // 尚未全量加载时，先触发全量；加载完成后由 onTracksChanged 再过滤
        if (!isSearchAllLoaded) {
            if (recommendation) recommendation.loadAllPlaylistTracks()
            return
        }
        var lower = kw.toLowerCase()
        var src = recommendation ? recommendation.playlistTracksQml : []
        var result = []
        for (var i = 0; i < src.length; i++) {
            var s = src[i]
            if ((s.songname && s.songname.toLowerCase().indexOf(lower) >= 0) ||
                (s.singername && s.singername.toLowerCase().indexOf(lower) >= 0) ||
                (s.album_name && s.album_name.toLowerCase().indexOf(lower) >= 0)) {
                result.push(s)
            }
        }
        filteredTracks = result
    }

    // 监听后端歌曲列表变化：全量加载完成后执行搜索过滤 / 播放全部
    Connections {
        target: recommendation
        function onPlaylistTracksChanged() {
            if (!recommendation) return
            // 全量加载完成（hasMore=false）
            if (!recommendation.playlistHasMore) {
                // 搜索触发的全量
                if (searchKeyword.trim() !== "" && !isSearchAllLoaded) {
                    isSearchAllLoaded = true
                    doSearch()
                }
                // 播放全部触发的全量
                if (_pendingPlayAll) {
                    _pendingPlayAll = false
                    var songs = recommendation.playlistTracksQml
                    if (songs.length > 0) {
                        playlistmanager.clearPlaylist()
                        for (var i = 0; i < songs.length; i++) {
                            var s = songs[i]
                            playlistmanager.addSong(s.songname, s.songhash, s.singername, s.union_cover, s.album_name, s.duration)
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
                    color: backHover.hovered ? AppTheme.bgCard : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: backIcon
                        anchors.centerIn: parent
                        source: "qrc:/image/left_line.png"
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: backIcon
                            color: AppTheme.textPrimary
                        }
                    }

                    HoverHandler { id: backHover }
                    TapHandler {
                        cursorShape: Qt.PointingCursor
                        onTapped: BasicConfig.goBack()
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
                        font.pixelSize: 20
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
                        font.pixelSize: 12
                        color: AppTheme.textMuted
                        font.family: AppTheme.fontFamily
                    }

                    // 搜索框
                    TextField {
                        id: searchInput
                        width: 180
                        height: 32
                        placeholderText: "搜索歌单内歌曲"
                        font.pixelSize: 12
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textPrimary
                        background: Rectangle {
                            radius: 16
                            color: AppTheme.bgCard
                            border.color: searchInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault
                            border.width: 1
                        }
                        onTextChanged: {
                            searchKeyword = text
                            if (text.trim() === "") isSearchAllLoaded = false
                            if (!searchTimer) {
                                searchTimer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 400; repeat: false }', searchInput)
                                searchTimer.triggered.connect(function(){ doSearch() })
                            }
                            searchTimer.restart()
                        }
                    }

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
                                font.pixelSize: 12
                                color: "#ffffff"
                                font.family: AppTheme.fontFamily
                                font.bold: true
                            }

                            HoverHandler { id: playAllHover }
                            TapHandler {
                                cursorShape: Qt.PointingCursor
                                enabled: recommendation && !recommendation.playlistIsLoading
                                onTapped: {
                                    if (!recommendation) return
                                    var songs = recommendation.playlistTracksQml
                                    // 未全量加载时，先全量；全量后由 onTracksChanged 触发播放
                                    if (recommendation.playlistHasMore) {
                                        _pendingPlayAll = true
                                        recommendation.loadAllPlaylistTracks()
                                        return
                                    }
                                    if (songs.length > 0) {
                                        playlistmanager.clearPlaylist()
                                        for (var i = 0; i < songs.length; i++) {
                                            var s = songs[i]
                                            playlistmanager.addSong(s.songname, s.songhash, s.singername, s.union_cover, s.album_name, s.duration)
                                        }
                                        playlistmanager.playSongbyindex(0)
                                        BasicConfig.emitSongAdded("正在播放: " + playlistName)
                                    }
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
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

    // 歌曲列表
    ListView {
        id: tracksListView
        anchors.top: parent.top
        anchors.topMargin: 170
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        // 搜索时显示过滤结果，否则显示全部已加载
        model: searchKeyword.trim() !== "" ? filteredTracks
              : (recommendation ? recommendation.playlistTracksQml : [])
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

        // 滚动到底加载下一页（仅非搜索状态）
        onContentYChanged: {
            if (searchKeyword.trim() !== "") return
            if (recommendation && !recommendation.playlistIsLoading
                && recommendation.playlistHasMore
                && contentHeight > height
                && contentY >= contentHeight - height - 200) {
                recommendation.fetchMorePlaylistTracks()
            }
        }

        delegate: Rectangle {
            width: tracksListView.width - 60
            height: 55
            x: 30
            radius: 8
            color: songHover.hovered ? AppTheme.bgCard : "transparent"

            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === modelData.songhash

                    Row {
                        id: mainRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Text {
                            width: 30
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 13
                            color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                            text: isPlaying ? "♪" : (index + 1)
                        }

                        Image {
                            width: 40
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.union_cover
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
                            width: parent.width - 260
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: modelData.songname
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: isPlaying ? AppTheme.accentPlaying : AppTheme.textPrimary
                                font.family: AppTheme.fontFamily
                            }

                            Text {
                                text: modelData.singername
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                color: AppTheme.textMuted
                                font.family: AppTheme.fontFamily
                            }
                        }

                        // 操作按钮
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            visible: songHover.hovered

                            // 普通模式：立即播放 + 下一首播放
                            Row {
                                visible: !isTogetherMode
                                spacing: 6

                                Rectangle {
                                    width: 66
                                    height: 26
                                    radius: 13
                                    color: playBtnHover.hovered ? "#533483" : "#e94560"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "立即播放"
                                        font.pixelSize: 10
                                        color: "#ffffff"
                                        font.family: AppTheme.fontFamily
                                    }

                                    HoverHandler { id: playBtnHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingCursor
                                        onTapped: {
                                            playlistmanager.addandplay(modelData.songname, modelData.songhash,
                                                                       modelData.singername, modelData.union_cover,
                                                                       modelData.album_name, modelData.duration)
                                            BasicConfig.emitSongAdded("正在播放: " + modelData.songname)
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Rectangle {
                                    width: 76
                                    height: 26
                                    radius: 13
                                    color: nextBtnHover.hovered ? AppTheme.bgNavHover : "transparent"
                                    border.color: AppTheme.textMuted
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "下一首播放"
                                        font.pixelSize: 10
                                        color: AppTheme.textPrimary
                                        font.family: AppTheme.fontFamily
                                    }

                                    HoverHandler { id: nextBtnHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingCursor
                                        onTapped: {
                                            playlistmanager.addSongNext(modelData.songname, modelData.songhash,
                                                                        modelData.singername, modelData.union_cover,
                                                                        modelData.album_name, modelData.duration)
                                            BasicConfig.emitSongAdded("已添加到下一首: " + modelData.songname)
                                        }
                                    }
                                }
                            }

                            // 一起听模式：添加到一起听列表
                            Rectangle {
                                visible: isTogetherMode
                                width: 80
                                height: 26
                                radius: 13
                                color: togetherBtnHover.hovered ? "#533483" : "#e94560"

                                Text {
                                    anchors.centerIn: parent
                                    text: "添加到一起听"
                                    font.pixelSize: 10
                                    color: "#ffffff"
                                    font.family: AppTheme.fontFamily
                                }

                                HoverHandler { id: togetherBtnHover }
                                TapHandler {
                                    cursorShape: Qt.PointingCursor
                                    onTapped: {
                                        websocket.addSongToTogether(modelData.songname, modelData.songhash,
                                                                    modelData.singername, modelData.album_name,
                                                                    modelData.duration, modelData.union_cover)
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        Text {
                            id: durationText
                            text: modelData.duration
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 11
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                            visible: !songHover.hovered
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        enabled: !isTogetherMode
                        propagateComposedEvents: true
                        onDoubleClicked: {
                            if (!recommendation) return
                            var total = recommendation.playlistTotal
                            var firstBatch = recommendation.playlistTracksQml
                            if (firstBatch.length === 0 || total <= 0) return
                            playlistmanager.playPlaylistFromSource(playlistId, total, index, firstBatch)
                            BasicConfig.emitSongAdded("已切换播放列表: " + playlistName)
                        }
                    }

                    HoverHandler { id: songHover }

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

        // footer：总数 / 加载中 / 已加载全部
        footer: Item {
            width: tracksListView.width
            height: 44
            Text {
                anchors.centerIn: parent
                font.pixelSize: 12
                color: AppTheme.textMuted
                font.family: AppTheme.fontFamily
                text: {
                    if (!recommendation) return ""
                    if (searchKeyword.trim() !== "") {
                        return "找到 " + filteredTracks.length + " 首"
                    }
                    if (recommendation.playlistIsLoading) return "加载中..."
                    var loaded = recommendation.playlistTracksQml ? recommendation.playlistTracksQml.length : 0
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
        visible: !recommendation || recommendation.playlistTracksQml.length === 0
        iconText: "♪"
        title: "歌单暂无歌曲"
        subtitle: "稍后再来看看吧"
    }
}
