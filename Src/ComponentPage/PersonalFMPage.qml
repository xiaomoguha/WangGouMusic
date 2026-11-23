pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

// 独立个人 FM 页：大封面 + 播放控制 + 喜欢/不感兴趣/屏蔽歌手 + 连续队列
Item {
    id: root
    objectName: "PersonalFMPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // 页面入场动效（与每日推荐一致）
    opacity: 0
    transform: Translate { id: enterShift; y: 14 }
    Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: {
            if (BasicConfig.uiIdle) {
                root.opacity = 1
                enterShift.y = 0
            } else {
                enterAnim.start()
            }
        }
    }
    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: enterShift; property: "y"; from: 14; to: 0; duration: 420; easing.type: Easing.OutCubic }
    }

    // FM 播放状态：播放列表是否由个人 FM 接管
    property bool fmActive: false
    // 一起听模式下只做推荐来源，不在这里启动本地 FM 播放
    readonly property bool togetherMode: playlistmanager && playlistmanager.type === 1
    // 首次启动等待首批数据
    property bool pendingPlay: false
    property string pendingStartHash: ""
    // 刷新 / 切模式后，新队列到达时整体重建播放器
    property bool pendingRefreshPlay: false
    // 批量重建播放列表时屏蔽队列监听，避免误判为外部播放
    property bool _syncing: false
    // 本次会话点过喜欢的 hash
    property var likedHashes: ({})

    readonly property real sideMargin: Math.max(24, width * 0.035)

    readonly property var currentQueueSong: {
        if (!personalFM || !playlistmanager) return null
        var hash = playlistmanager.currentSonghash
        if (!hash) return null
        var q = personalFM.queue
        for (var i = 0; i < q.length; i++) {
            if (q[i].songhash === hash) return q[i]
        }
        return null
    }
    readonly property var previewSong: {
        if (!personalFM) return null
        if (personalFM.queue.length > 0) return personalFM.queue[0]
        return personalFM.songs.length > 0 ? personalFM.songs[0] : null
    }
    readonly property var displaySong: root.togetherMode ? root.previewSong
                                                         : (root.currentQueueSong ? root.currentQueueSong : root.previewSong)
    readonly property bool fmPlayingThis: root.fmActive && root.currentQueueSong !== null

    readonly property string displayTitle: {
        if (root.fmPlayingThis && playlistmanager && playlistmanager.currentTitle)
            return playlistmanager.currentTitle
        return root.displaySong ? root.displaySong.songname : ""
    }
    readonly property string displaySinger: {
        if (root.fmPlayingThis && playlistmanager && playlistmanager.currentsingername)
            return playlistmanager.currentsingername
        return root.displaySong ? root.displaySong.singername : ""
    }
    readonly property string displayAlbum: root.displaySong ? (root.displaySong.album_name || "") : ""
    readonly property string displayCover: {
        if (root.fmPlayingThis && playlistmanager && playlistmanager.union_cover)
            return playlistmanager.union_cover
        return root.displaySong ? (root.displaySong.union_cover || "") : ""
    }
    readonly property string recReason: root.displaySong ? (root.displaySong.rec_desc || "") : ""

    readonly property var queueModel: (personalFM && personalFM.queueMode) ? personalFM.queue : (personalFM ? personalFM.songs : [])
    readonly property bool previewMode: !root.fmActive
    readonly property bool likedCurrent: !!(playlistmanager && root.likedHashes[playlistmanager.currentSonghash])

    function queueIndexOf(hash) {
        if (!personalFM || !hash) return -1
        var q = personalFM.queue
        for (var i = 0; i < q.length; i++) {
            if (q[i].songhash === hash) return i
        }
        return -1
    }
    function queueContains(hash) {
        return root.queueIndexOf(hash) >= 0
    }

    // 把 FM 队列整体装进播放器并从 startHash（或第一首）开始
    function beginPlayback(startHash) {
        if (root.togetherMode)
            return
        if (!personalFM || personalFM.queue.length === 0)
            return
        root._syncing = true
        playlistmanager.clearPlaylist()
        var q = personalFM.queue
        for (var i = 0; i < q.length; i++) {
            var s = q[i]
            playlistmanager.addSong({
                "songname": s.songname,
                "songhash": s.songhash,
                "singername": s.singername,
                "union_cover": s.union_cover,
                "album_name": s.album_name,
                "duration": s.duration,
                "peak_start_ms": s.peak_start_ms || 0,
                "peak_end_ms": s.peak_end_ms || 0
            })
        }
        var idx = startHash ? root.queueIndexOf(startHash) : 0
        if (idx < 0) idx = 0
        playlistmanager.playSongbyindex(idx)
        root.fmActive = true
        root.pendingPlay = false
        root.pendingRefreshPlay = false
        root.pendingStartHash = ""
        root._syncing = false
        root.syncPeakMode()
        BasicConfig.emitSongAdded("个人FM: " + q[idx].songname)
    }

    function startFM(startHash) {
        if (!personalFM || root.togetherMode) return
        // 已经在放 FM 且没有指定某首时，直接继续，不打断当前进度
        if (!startHash && root.fmActive && root.queueContains(playlistmanager.currentSonghash))
            return

        root.pendingRefreshPlay = false
        root.pendingStartHash = startHash || ""
        root.pendingPlay = true

        if (!personalFM.queueMode)
            personalFM.startQueue()

        // startQueue 可能同步用已有卡片填好队列；此时立刻开播
        if (root.pendingPlay && personalFM.queue.length > 0)
            root.beginPlayback(root.pendingStartHash)
    }

    function appendSongsToPlaylist(songs) {
        if (!playlistmanager || !songs) return
        for (var i = 0; i < songs.length; i++) {
            var s = songs[i]
            playlistmanager.addSong({
                "songname": s.songname,
                "songhash": s.songhash,
                "singername": s.singername,
                "union_cover": s.union_cover,
                "album_name": s.album_name,
                "duration": s.duration,
                "peak_start_ms": s.peak_start_ms || 0,
                "peak_end_ms": s.peak_end_ms || 0
            })
        }
    }

    function maybePrefetch() {
        if (!root.fmActive || !personalFM || personalFM.isLoading) return
        var idx = root.queueIndexOf(playlistmanager.currentSonghash)
        if (idx < 0) return
        if (personalFM.queue.length - idx - 1 <= 2)
            personalFM.requestMore()
    }

    // 30秒模式：让播放器只走当前歌曲的高潮片段，并自动接下一首
    function syncPeakMode() {
        if (!playlistmanager) return
        playlistmanager.setFmPeakMode(root.fmActive && !root.togetherMode
                                      && personalFM && personalFM.mode === 2)
    }

    function refreshFM() {
        if (!personalFM) return
        root.pendingRefreshPlay = root.fmActive && !root.togetherMode
        personalFM.refreshQueue()
    }

    function changeMode(mode) {
        if (!personalFM) return
        root.pendingRefreshPlay = root.fmActive && !root.togetherMode
        personalFM.setMode(mode)
    }

    function changePool(pool) {
        if (!personalFM) return
        root.pendingRefreshPlay = root.fmActive && !root.togetherMode
        personalFM.setPool(pool)
    }

    function likeCurrent() {
        if (!root.currentQueueSong) return
        var hash = playlistmanager.currentSonghash
        personalFM.like(hash)
        var liked = {}
        for (var k in root.likedHashes) liked[k] = root.likedHashes[k]
        liked[hash] = true
        root.likedHashes = liked
    }

    function dislikeCurrent() {
        if (!root.currentQueueSong) return
        personalFM.dislike(playlistmanager.currentSonghash)
        playlistmanager.playNext()
    }

    function banCurrentSinger() {
        if (!root.currentQueueSong) return
        personalFM.banSinger(playlistmanager.currentSonghash)
        playlistmanager.playNext()
    }

    function addSongToTogether(song) {
        if (!song || !websocket) return
        websocket.addSongToTogether(song.songname, song.songhash, song.singername,
                                    song.album_name, song.duration, song.union_cover)
        BasicConfig.noticeSuccess("已添加到一起听: " + song.songname)
    }

    function playQueueSong(song) {
        if (!song) return
        if (root.togetherMode) {
            root.addSongToTogether(song)
            return
        }
        if (root.fmActive && root.queueContains(song.songhash)) {
            if (song.songhash === playlistmanager.currentSonghash)
                playlistmanager.playstop()
            else
                playlistmanager.playSongbyhasg(song.songhash)
        } else {
            root.startFM(song.songhash)
        }
    }

    Component.onCompleted: {
        if (!personalFM) return
        if (personalFM.songs.length === 0 && !personalFM.isLoading)
            personalFM.fetch()
        // 页面打开时先备好 10 首推荐队列，但不会自动开始播放
        personalFM.startQueue()
    }

    onVisibleChanged: {
        if (visible)
            BasicConfig.playlistPageActive = false
    }

    onTogetherModeChanged: {
        if (root.togetherMode) {
            root.fmActive = false
        } else if (personalFM && personalFM.queueMode
                   && root.queueContains(playlistmanager.currentSonghash)) {
            root.fmActive = true
            root.maybePrefetch()
        }
        root.syncPeakMode()
    }

    onFmActiveChanged: root.syncPeakMode()

    Connections {
        target: personalFM
        function onSongsAppended(songs) {
            if (root.pendingPlay || root.pendingRefreshPlay) {
                root.beginPlayback(root.pendingStartHash)
                return
            }
            if (!root.fmActive || root._syncing) return
            root.appendSongsToPlaylist(songs)
        }
        function onQueueModeChanged() {
            if (personalFM && !personalFM.queueMode)
                root.fmActive = false
        }
        function onModeChanged() {
            root.syncPeakMode()
        }
        function onNotice(message) {
            if (message) BasicConfig.noticeSuccess(message)
        }
        function onErrorOccurred(message) {
            root.pendingRefreshPlay = false
            if (message) BasicConfig.noticeError(message)
        }
    }

    Connections {
        target: playlistmanager
        // 当前曲目离开 FM 队列（用户切去别的歌/歌单）就退出 FM 模式
        function onCurrentSongChanged() {
            if (!root.fmActive || root._syncing) return
            var hash = playlistmanager.currentSonghash
            if (hash === "") return
            if (!root.queueContains(hash)) {
                root.fmActive = false
                if (personalFM) personalFM.stopQueue()
                return
            }
            root.maybePrefetch()
        }
        function onPlaylistUpdated() {
            if (!root.fmActive || root._syncing) return
            if (playlistmanager.playlistcount === 0) {
                root.fmActive = false
                if (personalFM) personalFM.stopQueue()
            }
        }
    }

    // 小型胶囊选择器
    component ChoicePill: Rectangle {
        id: pill
        required property int index
        required property var modelData
        property string label: modelData
        property bool active: false
        signal clicked

        width: pillText.implicitWidth + 22
        height: 26
        radius: 13
        color: pill.active ? "#30FF6B6B" : (pillHover.hovered ? "#22FFFFFF" : "transparent")
        border.width: 1
        border.color: pill.active ? AppTheme.accent : "#26FFFFFF"

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            font.pixelSize: AppTheme.fontSizeCaption
            font.family: AppTheme.fontFamily
            font.bold: pill.active
            color: pill.active ? AppTheme.accent : AppTheme.textMuted
        }
        HoverHandler { id: pillHover }
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: pill.clicked()
        }
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
    }

    // 反馈按钮
    component FeedbackButton: Rectangle {
        id: fb
        property string label: ""
        property string iconSource: ""
        property bool active: false
        signal clicked

        width: fbText.implicitWidth + 46
        height: 32
        radius: 16
        opacity: root.fmPlayingThis ? 1 : 0.42
        color: fb.active ? "#30FF6B6B" : (fbHover.hovered ? "#1CFFFFFF" : "transparent")
        border.width: 1
        border.color: fb.active ? AppTheme.accent : "#26FFFFFF"

        Row {
            anchors.centerIn: parent
            spacing: 6

            Image {
                id: fbIcon
                width: 13
                height: 13
                source: fb.iconSource
                sourceSize: Qt.size(52, 52)
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: fbIcon
                    color: fb.active ? AppTheme.accent : AppTheme.textMuted
                }
            }
            Text {
                id: fbText
                text: fb.label
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
                color: fb.active ? AppTheme.accent : AppTheme.textMuted
            }
        }
        HoverHandler { id: fbHover }
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            enabled: root.fmPlayingThis
            onTapped: fb.clicked()
        }
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
    }

    Column {
        id: pageColumn
        anchors.fill: parent
        anchors.leftMargin: root.sideMargin
        anchors.rightMargin: root.sideMargin
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 14

        // ========== 页头：标题 ==========
        Item {
            id: pageHeader
            width: pageColumn.width
            height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    GlowText {
                        text: "✦ 个人FM"
                        font.pixelSize: AppTheme.fontSizeHeadline
                        font.bold: true
                        color: AppTheme.textPrimary
                        glowColor: AppTheme.accentGlow
                        glowRadius: 15
                    }
                    Text {
                        text: "根据你的口味持续推荐，自动续播不会停"
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                }
            }

            // ========== 主体：当前歌曲 + 播放队列 ==========
            Row {
                id: mainRow
                width: pageColumn.width
                height: pageColumn.height - pageHeader.height - pageColumn.spacing
                spacing: 18
                readonly property real queueWidth: Math.max(300, Math.min(380, width * 0.33))

                Rectangle {
                    id: heroCard
                    width: mainRow.width - mainRow.queueWidth - mainRow.spacing
                    height: mainRow.height
                    radius: 22
                    color: "#121219"
                    border.width: 1
                    border.color: "#1FFFFFFF"

                    // 顶部氛围光
                    RadialGradient {
                        anchors.fill: parent
                        opacity: 0.55
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 0.42, 0.42, 0.10) }
                            GradientStop { position: 0.55; color: Qt.rgba(1, 0.42, 0.42, 0.025) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Row {
                        id: heroTop
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 28
                        spacing: 26
                        height: 220

                        Rectangle {
                            width: 220
                            height: 220
                            radius: 18
                            clip: true
                            color: "#1C1C26"

                            RetryImage {
                                anchors.fill: parent
                                coverSource: root.displayCover
                                sourceSize.width: 440
                                sourceSize.height: 440
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                font.pixelSize: 62
                                font.family: AppTheme.fontFamily
                                color: "#44FFFFFF"
                                visible: root.displayCover === ""
                            }

                            // 正在播时的小角标
                            Rectangle {
                                visible: root.fmPlayingThis
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                width: 34
                                height: 24
                                radius: 12
                                color: "#B0000000"

                                NowPlayingIndicator {
                                    anchors.centerIn: parent
                                    width: 15
                                    height: 14
                                    playing: playlistmanager ? !playlistmanager.isPaused : true
                                }
                            }
                        }

                        Column {
                            id: heroInfoColumn
                            width: parent.width - 246
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: root.togetherMode ? "一起听推荐 · 个人FM"
                                      : (root.fmPlayingThis ? "正在播放 · 个人FM" : "为你推荐 · 个人FM")
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                font.bold: true
                                color: AppTheme.accent
                            }

                            Text {
                                width: parent.width
                                text: root.displayTitle !== "" ? root.displayTitle
                                      : (personalFM && personalFM.isLoading ? "正在加载推荐..." : "还没有推荐")
                                font.pixelSize: 26
                                font.family: AppTheme.fontFamily
                                font.bold: true
                                color: AppTheme.textPrimary
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }

                            Text {
                                width: parent.width
                                text: root.displaySinger !== "" ? root.displaySinger : "点击下方按钮开始"
                                font.pixelSize: AppTheme.fontSizeTitle
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textSecondary
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: root.displayAlbum !== ""
                                text: "专辑：" + root.displayAlbum
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 8

                                Rectangle {
                                    visible: root.recReason !== ""
                                    width: Math.min(heroInfoColumn.width, reasonText.implicitWidth + 20)
                                    height: 24
                                    radius: 12
                                    color: "#22FF6B6B"

                                    Text {
                                        id: reasonText
                                        anchors.centerIn: parent
                                        width: parent.width - 20
                                        elide: Text.ElideRight
                                        text: root.recReason
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.accent
                                    }
                                }
                            }
                        }
                    }

                    // 进度条
                    Item {
                        id: progressArea
                        visible: !root.togetherMode
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: heroTop.bottom
                        anchors.topMargin: 14
                        anchors.leftMargin: 28
                        anchors.rightMargin: 28
                        height: 16

                        readonly property real shownPercent: {
                            if (!root.fmPlayingThis)
                                return 0
                            if (progressMouse.dragging && progressMouse.tempPercent >= 0)
                                return progressMouse.tempPercent
                            return playlistmanager ? playlistmanager.percent : 0
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: progressMouse.containsMouse || progressMouse.dragging ? 5 : 3
                            radius: height / 2
                            color: "#24FFFFFF"
                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * Math.max(0, Math.min(1, progressArea.shownPercent))
                            height: progressMouse.containsMouse || progressMouse.dragging ? 5 : 3
                            radius: height / 2
                            color: AppTheme.accent
                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            visible: root.fmPlayingThis
                            width: 10
                            height: 10
                            radius: 5
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(progressArea.width - width,
                                             progressArea.width * progressArea.shownPercent - width / 2))
                        }

                        MouseArea {
                            id: progressMouse
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            hoverEnabled: true
                            property bool dragging: false
                            property real tempPercent: -1

                            function pct(mx) {
                                return Math.max(0, Math.min(1, mx / progressArea.width))
                            }
                            onPressed: {
                                if (!root.fmActive) return
                                dragging = true
                                tempPercent = pct(mouseX)
                            }
                            onPositionChanged: {
                                if (pressed && dragging)
                                    tempPercent = pct(mouseX)
                            }
                            onReleased: {
                                if (!dragging) return
                                if (root.fmActive && playlistmanager)
                                    playlistmanager.setposistion(tempPercent)
                                dragging = false
                                tempPercent = -1
                            }
                            onClicked: {
                                if (!root.fmActive || !playlistmanager) return
                                playlistmanager.setposistion(pct(mouseX))
                            }
                        }
                    }

                    Row {
                        id: timeRow
                        visible: !root.togetherMode
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: progressArea.bottom
                        anchors.topMargin: 4
                        anchors.leftMargin: 28
                        anchors.rightMargin: 28

                        Text {
                            text: (root.fmPlayingThis && playlistmanager) ? playlistmanager.percentstr : "00:00"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                        }
                        Item { width: parent.width - 70; height: 1 }
                        Text {
                            text: (root.fmPlayingThis && playlistmanager) ? playlistmanager.duration : "--:--"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                        }
                    }

                    // 播放控制
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: progressArea.bottom
                        anchors.topMargin: 24
                        spacing: 26

                        IconButton {
                            visible: !root.togetherMode
                            anchors.verticalCenter: parent.verticalCenter
                            iconSource: AppIcon.prev
                            size: 40
                            iconSize: 18
                            iconColor: root.fmActive ? AppTheme.textPrimary : AppTheme.textDim
                            onClicked: {
                                if (root.fmActive)
                                    playlistmanager.playPrevious()
                            }
                        }

                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            color: playHover.hovered ? AppTheme.accentHover : AppTheme.accent

                            Image {
                                id: playIcon
                                anchors.centerIn: parent
                                width: root.togetherMode ? 25 : 22
                                height: root.togetherMode ? 25 : 22
                                source: root.togetherMode ? AppIcon.addTogether
                                        : ((root.fmActive && playlistmanager && !playlistmanager.isPaused)
                                           ? AppIcon.pauseFill : AppIcon.playFill)
                                sourceSize: Qt.size(96, 96)
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay { source: playIcon; color: "#FFFFFF" }
                            }

                            HoverHandler { id: playHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    if (root.togetherMode)
                                        root.addSongToTogether(root.displaySong)
                                    else if (!root.fmActive)
                                        root.startFM("")
                                    else if (playlistmanager)
                                        playlistmanager.playstop()
                                }
                            }
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                        }

                        IconButton {
                            visible: !root.togetherMode
                            anchors.verticalCenter: parent.verticalCenter
                            iconSource: AppIcon.next
                            size: 40
                            iconSize: 18
                            iconColor: root.fmActive ? AppTheme.textPrimary : AppTheme.textDim
                            onClicked: {
                                if (root.fmActive)
                                    playlistmanager.playNext()
                            }
                        }
                    }

                    // 反馈按钮
                    Row {
                        id: feedbackRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: progressArea.bottom
                        anchors.topMargin: 90
                        spacing: 10

                        FeedbackButton {
                            label: root.likedCurrent ? "已喜欢" : "喜欢"
                            iconSource: root.likedCurrent ? AppIcon.heartFill : AppIcon.heart
                            active: root.likedCurrent
                            onClicked: root.likeCurrent()
                        }
                        FeedbackButton {
                            label: "不感兴趣"
                            iconSource: AppIcon.close
                            onClicked: root.dislikeCurrent()
                        }
                        FeedbackButton {
                            label: "屏蔽歌手"
                            iconSource: AppIcon.user
                            onClicked: root.banCurrentSinger()
                        }
                    }

                    // 模式和推荐源放在反馈按钮下方
                    Column {
                        id: selectors
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: feedbackRow.bottom
                        anchors.topMargin: 14
                        spacing: 8

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "模式"
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textDim
                            }
                            Repeater {
                                model: ["发现", "小众", "30秒", "电台"]
                                delegate: ChoicePill {
                                    label: modelData
                                    active: personalFM && personalFM.mode === index
                                    onClicked: {
                                        if (personalFM)
                                            root.changeMode(index)
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "推荐源"
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textDim
                            }
                            Repeater {
                                model: ["口味", "风格", "探索"]
                                delegate: ChoicePill {
                                    label: modelData
                                    active: personalFM && personalFM.pool === index
                                    onClicked: {
                                        if (personalFM)
                                            root.changePool(index)
                                    }
                                }
                            }
                        }
                    }
                }

                // ========== 右侧队列 ==========
                Rectangle {
                    width: mainRow.queueWidth
                    height: heroCard.height
                    radius: 22
                    color: "#121219"
                    border.width: 1
                    border.color: "#1FFFFFFF"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 30

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: root.togetherMode ? "一起听推荐"
                                          : ((personalFM && personalFM.queueMode) ? "播放队列" : "推荐预览")
                                    font.pixelSize: AppTheme.fontSizeTitle
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textPrimary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.queueModel.length + " 首"
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textMuted
                                }
                            }

                            SectionRefreshButton {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                busy: personalFM && personalFM.isLoading
                                onClicked: {
                                    if (!personalFM) return
                                    if (root.togetherMode)
                                        personalFM.refreshQueue()
                                    else
                                        root.refreshFM()
                                }
                            }
                        }

                        Item {
                            id: queueArea
                            width: parent.width
                            height: parent.height - 44

                            ListView {
                                id: queueList
                                anchors.fill: parent
                                clip: true
                                spacing: 2
                                model: root.queueModel

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
                                id: queueRow
                                required property int index
                                required property var modelData
                                width: queueList.width
                                height: 58
                                radius: 8
                                hovered: rowHover.hovered

                                readonly property var songData: modelData
                                readonly property bool isPlaying: !root.togetherMode
                                                                  && playlistmanager
                                                                  && playlistmanager.currentSonghash === songData.songhash

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Item {
                                        width: 18
                                        height: 18
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !queueRow.isPlaying
                                            text: (index + 1).toString().padStart(2, "0")
                                            font.pixelSize: AppTheme.fontSizeSmall
                                            font.family: AppTheme.fontFamily
                                            color: AppTheme.textMuted
                                        }
                                        NowPlayingIndicator {
                                            anchors.centerIn: parent
                                            visible: queueRow.isPlaying
                                            width: 15
                                            height: 15
                                            playing: playlistmanager ? !playlistmanager.isPaused : true
                                        }
                                    }

                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 8
                                        clip: true
                                        color: "#1C1C26"
                                        anchors.verticalCenter: parent.verticalCenter

                                        RetryImage {
                                            anchors.fill: parent
                                            coverSource: queueRow.songData.union_cover
                                            sourceSize.width: 80
                                            sourceSize.height: 80
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                    }

                                    Column {
                                        width: parent.width - 18 - 40 - 30
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: queueRow.songData.songname
                                            elide: Text.ElideRight
                                            font.pixelSize: AppTheme.fontSizeSmall
                                            font.bold: true
                                            font.family: AppTheme.fontFamily
                                            color: (queueRow.isPlaying || rowHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                        }
                                        Text {
                                            width: parent.width
                                            text: queueRow.songData.singername
                                            elide: Text.ElideRight
                                            font.pixelSize: AppTheme.fontSizeCaption
                                            font.family: AppTheme.fontFamily
                                            color: queueRow.isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                                        }
                                    }
                                }

                                // hover 操作区：试听 + 播放 / 添加到一起听
                                Rectangle {
                                    visible: queueActionRow.visible
                                    anchors.right: queueActionRow.right
                                    anchors.rightMargin: -4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: queueActionRow.width + 8
                                    height: 30
                                    radius: 15
                                    color: "#E614141C"
                                    z: 1
                                }

                                Row {
                                    id: queueActionRow
                                    width: 80
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    visible: rowHover.hovered || queuePreviewBtn.active
                                    z: 2

                                    HoverHandler { id: queueActionHover }

                                    ClimaxPreviewButton {
                                        id: queuePreviewBtn
                                        songHash: queueRow.songData.songhash || ""
                                        songTitle: queueRow.songData.songname || ""
                                        songSinger: queueRow.songData.singername || ""
                                        songCover: queueRow.songData.union_cover || ""
                                        rowHovered: rowHover.hovered
                                        compact: true
                                    }

                                    IconButton {
                                        visible: !root.togetherMode
                                        iconSource: AppIcon.playCircle
                                        size: 24
                                        iconSize: 14
                                        onClicked: root.playQueueSong(queueRow.songData)
                                    }

                                    IconButton {
                                        visible: root.togetherMode
                                        iconSource: AppIcon.addTogether
                                        size: 24
                                        iconSize: 14
                                        iconColor: hovered ? AppTheme.accent : AppTheme.iconDefault
                                        onClicked: root.addSongToTogether(queueRow.songData)
                                    }
                                }

                                HoverHandler { id: rowHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: {
                                        if (queueActionHover.hovered || queuePreviewBtn.active)
                                            return
                                        root.playQueueSong(queueRow.songData)
                                    }
                                }
                            }
                            }

                            EmptyState {
                                visible: root.queueModel.length === 0
                                anchors.fill: queueList
                                z: 2
                                iconText: "♪"
                                title: personalFM && personalFM.isLoading ? "正在加载推荐..." : "还没有推荐"
                                subtitle: personalFM && personalFM.isLoading ? "" : "点下面的按钮重新加载"
                                buttonText: personalFM && personalFM.isLoading ? "" : "加载推荐"
                                onButtonClicked: {
                                    if (personalFM)
                                        personalFM.fetch()
                                }
                            }
                        }
                    }
                }
            }
        }
}
