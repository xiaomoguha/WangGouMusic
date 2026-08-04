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

    property bool _pendingPlayAll: false
    property int currentSongIndex: -1        // 当前播放在列表中的下标，-1 = 不在
    property bool _autoLocated: false        // 是否已自动定位过一次
    readonly property bool pageActive: parent && parent.visible && opacity > 0

    Component.onCompleted: {
        if (recommendation && playlistId !== "")
            recommendation.fetchPlaylistTracks(playlistId)
    }

    // 计算当前播放在当前列表中的下标
    function recomputeCurrentSongIndex() {
        currentSongIndex = -1
        if (!playlistmanager) return
        var csh = playlistmanager.currentSonghash
        if (!csh) return
        var list = recommendation ? recommendation.playlistTracksQml : []
        for (var i = 0; i < list.length; i++) {
            if (list[i].songhash === csh) { currentSongIndex = i; break }
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
            if (recommendation && playlistId !== "") {
                tracksListView.contentY = 0
                _pendingPlayAll = false
                _autoLocated = false
                currentSongIndex = -1
                recommendation.fetchPlaylistTracks(playlistId)
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
                    var songs = recommendation.playlistTracksQml
                    if (songs.length > 0) {
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
                        source: AppIcon.back
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
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

                    // 播放全部
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
                                cursorShape: Qt.PointingCursor
                                enabled: recommendation && !recommendation.playlistIsLoading
                                onTapped: {
                                    if (!recommendation) return
                                    var songs = recommendation.playlistTracksQml
                                    if (recommendation.playlistHasMore) {
                                        _pendingPlayAll = true
                                        recommendation.loadAllPlaylistTracks()
                                        return
                                    }
                                    if (songs.length > 0) {
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
                                        BasicConfig.emitSongAdded("正在播放: " + playlistName)
                                    }
                                }
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
        model: recommendation ? recommendation.playlistTracksQml : []
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
            color: {
                if (songHover.hovered) return AppTheme.bgCardHover
                if (isPlaying) return AppTheme.bgCardHover
                return "transparent"
            }

            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === modelData.songhash

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
                            anchors.verticalCenter: parent.verticalCenter
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
                            width: 0.3 * tracksListView.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                text: modelData.songname
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBody
                                font.bold: true
                                color: isPlaying ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                font.family: AppTheme.fontFamily
                            }

                            Text {
                                text: modelData.singername
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
                            width: isTogetherMode ? 34 : 68
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
                                            "songname": modelData.songname,
                                            "songhash": modelData.songhash,
                                            "singername": modelData.singername,
                                            "union_cover": modelData.union_cover,
                                            "album_name": modelData.album_name,
                                            "duration": modelData.duration
                                        })
                                        BasicConfig.emitSongAdded("正在播放: " + modelData.songname)
                                    }
                                }

                                IconButton {
                                    visible: !isTogetherMode
                                    iconSource: AppIcon.addToList
                                    size: 30
                                    iconSize: 16
                                    onClicked: {
                                        playlistmanager.addSongNext({
                                            "songname": modelData.songname,
                                            "songhash": modelData.songhash,
                                            "singername": modelData.singername,
                                            "union_cover": modelData.union_cover,
                                            "album_name": modelData.album_name,
                                            "duration": modelData.duration
                                        })
                                        BasicConfig.emitSongAdded("已添加到下一首: " + modelData.songname)
                                    }
                                }

                                IconButton {
                                    visible: isTogetherMode
                                    iconSource: AppIcon.addTogether
                                    size: 30
                                    iconSize: 16
                                    onClicked: websocket.addSongToTogether(modelData.songname, modelData.songhash,
                                                                           modelData.singername, modelData.album_name,
                                                                           modelData.duration, modelData.union_cover)
                                }
                            }
                        }

                        // 专辑名（与最近播放一致的列）
                        Text {
                            text: modelData.album_name
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
                                var d = modelData.duration
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
                        onDoubleTapped: {
                            if (!recommendation) return
                            var total = recommendation.playlistTotal
                            var firstBatch = recommendation.playlistTracksQml
                            if (firstBatch.length === 0 || total <= 0) return
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
