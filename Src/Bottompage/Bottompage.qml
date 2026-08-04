import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Rectangle {
    id: controlBar
    color: AppTheme.bgBottomBarInner

    // 播放列表弹窗的队列镜像同步：加载更多时增量 append，保留滚动位置（不弹回/不闪）
    function makeQueueItem(s) {
        return {
            "title": s.title,
            "singername": s.singername,
            "duration": s.duration,
            "songhash": s.songhash
        }
    }
    function syncQueueModel() {
        if (!playlistmanager) {
            queueModel.clear()
            return
        }
        var q = playlistmanager.type === 1 ? playlistmanager.togetherplaylist : playlistmanager.playlist
        var qCount = q.count   // SongListModel::count()，替代原 QVariantList.length
        // 前缀一致（末尾追加）-> 只 append 差量，保留 contentY；否则整体重建
        var prefixOk = queueModel.count > 0 && qCount >= queueModel.count
        if (prefixOk) {
            for (var i = 0; i < queueModel.count; i++) {
                if (queueModel.get(i).songhash !== q.get(i).songhash) {
                    prefixOk = false
                    break
                }
            }
        }
        if (prefixOk) {
            for (var j = queueModel.count; j < qCount; j++) queueModel.append(makeQueueItem(q.get(j)))
        } else {
            queueModel.clear()
            for (var k = 0; k < qCount; k++) queueModel.append(makeQueueItem(q.get(k)))
        }
    }

    // 整窗统一渐变：本面板切片（面板根色在 main.qml 改为透明时生效）。
    // 底部栏整段都在淡出线以下，实际渲染为纯底色，但保留切片以维持结构统一。
    WindowTintGradient {
        baseColor: AppTheme.bgBottomBar
        panelTopY: BasicConfig.windowHeight - controlBar.height
    }

    // 顶部渐变分隔线
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 0.3
                color: AppTheme.accentDim
            }
            GradientStop {
                position: 0.5
                color: AppTheme.accentGlow
            }
            GradientStop {
                position: 0.7
                color: AppTheme.accentDim
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    // 主内容区域 - 横向布局
    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 4
        spacing: 4

        // ========== 左侧：歌曲信息 ==========
        Row {
            id: leftSection
            width: albumCoverContainer.width + spacing + songInfoColumn.width
            height: parent.height
            spacing: 5

            // 专辑封面（旋转动画）
            Rectangle {
                id: albumCoverContainer
                width: 65
                height: 65
                radius: 32
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                // 外圈发光
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: parent.height + 4
                    radius: (parent.width + 4) / 2
                    color: "transparent"
                    border.width: 2
                    border.color: playlistmanager && !playlistmanager.isPaused ? AppTheme.accentGlow : "transparent"
                    Behavior on border.color {
                        ColorAnimation {
                            duration: AppTheme.animThemeTransition
                        }
                    }
                }

                Image {
                    id: albumCover
                    anchors.fill: parent
                    source: playlistmanager ? (playlistmanager.union_cover === "" ? "qrc:/image/touxi.jpg" : playlistmanager.union_cover) : "qrc:/image/touxi.jpg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize.width: 130
                    sourceSize.height: 130
                    // Rectangle.clip 不裁圆角，圆形需 OpacityMask。
                    // 此处为静态单实例（非 delegate），离屏 FBO 开销可接受。
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 65
                            height: 65
                            radius: 32
                        }
                    }

                    property real currentRotation: 0
                    rotation: currentRotation

                    NumberAnimation on currentRotation {
                        id: rotationAnim
                        from: 0
                        to: 360
                        duration: 20000
                        loops: Animation.Infinite
                        running: true  // 创建即转；下面用 pause/resume 控制启停
                    }
                    // pause/resume（而非 stop/start）：保留角度、恢复不跳变（不闪角）；
                    // 最小化时暂停，避免底栏封面持续旋转驱动整窗渲染拉高 CPU。
                    function updateRotation() {
                        const active = playlistmanager && !playlistmanager.isPaused
                                       && root.visible && root.visibility !== Window.Minimized;
                        if (active) {
                            if (rotationAnim.paused)
                                rotationAnim.resume();
                        } else {
                            if (!rotationAnim.paused)
                                rotationAnim.pause();
                        }
                    }
                    Component.onCompleted: albumCover.updateRotation()
                    Connections {
                        target: playlistmanager
                        function onIsPausedChanged() { albumCover.updateRotation(); }
                    }
                    Connections {
                        target: root
                        function onVisibleChanged() { albumCover.updateRotation(); }
                        function onVisibilityChanged() { albumCover.updateRotation(); }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lyricsOpened = !root.lyricsOpened
                    }
                }
            }

            // 歌曲名称和歌手
            Column {
                id: songInfoColumn
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                // 宽度贴合实际文字（短歌名不留空，让歌词紧跟歌名尾端）；长名上限 80 省略号
                width: Math.min(Math.max(songNameText.implicitWidth, singerNameText.implicitWidth), 80)

                // 歌名（超出列宽时连续向左滚动，穿墙式无缝循环）
                Item {
                    id: songNameClip
                    width: parent.width
                    height: songNameText.implicitHeight
                    clip: true
                    property real unitWidth: songNameText.implicitWidth + 28
                    property bool overflow: songNameText.implicitWidth > width
                    Row {
                        id: songNameRow
                        spacing: 28
                        Text {
                            id: songNameText
                            text: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
                            font.family: AppTheme.fontFamily
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.bold: true
                            color: AppTheme.textSongTitle
                        }
                        Text {
                            text: songNameText.text
                            font.family: AppTheme.fontFamily
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.bold: true
                            color: AppTheme.textSongTitle
                            visible: songNameClip.overflow
                        }
                        NumberAnimation on x {
                            running: songNameClip.overflow
                            from: 0; to: -songNameClip.unitWidth
                            duration: Math.max(3000, songNameClip.unitWidth * 40)
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }
                        // overflow 关闭（短文字）时把 x 归零，避免动画停在负值导致左边字被裁
                        Connections {
                            target: songNameClip
                            function onOverflowChanged() {
                                if (!songNameClip.overflow) songNameRow.x = 0
                            }
                        }
                    }
                }

                // 歌手名（超出列宽时连续向左滚动）
                Item {
                    id: singerNameClip
                    width: parent.width
                    height: singerNameText.implicitHeight
                    clip: true
                    property real unitWidth: singerNameText.implicitWidth + 28
                    property bool overflow: singerNameText.implicitWidth > width
                    Row {
                        id: singerNameRow
                        spacing: 28
                        Text {
                            id: singerNameText
                            text: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
                            font.family: AppTheme.fontFamily
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: AppTheme.textMuted
                        }
                        Text {
                            text: singerNameText.text
                            font.family: AppTheme.fontFamily
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: AppTheme.textMuted
                            visible: singerNameClip.overflow
                        }
                        NumberAnimation on x {
                            running: singerNameClip.overflow
                            from: 0; to: -singerNameClip.unitWidth
                            duration: Math.max(3000, singerNameClip.unitWidth * 40)
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                        }
                        Connections {
                            target: singerNameClip
                            function onOverflowChanged() {
                                if (!singerNameClip.overflow) singerNameRow.x = 0
                            }
                        }
                    }
                }
            }
        }

        // ========== 中间：播放控制（歌词/按钮切换）==========
        Item {
            id: lyricsControlContainer
            width: 220
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            // ===== 控制按钮（常驻显示，不再切换歌词） =====
            Row {
                id: controlButtonsLayer
                anchors.centerIn: parent
                spacing: 16

                // 上一曲
                Rectangle {
                    id: prevBtn
                    width: 36
                    height: 36
                    radius: 18
                    enabled: playlistmanager ? playlistmanager.type !== 1 : true
                    color: prevHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: prevIcon
                        anchors.centerIn: parent
                        source: AppIcon.prev
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 20
                        height: 20
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: prevIcon
                            color: AppTheme.iconDefault
                        }
                    }

                    HoverHandler {
                        id: prevHandler
                    }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (playlistmanager.type === 1) return; // TOGETHER 模式禁用上一曲
                            playlistmanager.playPrevious();
                        }
                    }

                    opacity: enabled ? 1.0 : 0.3
                    Behavior on opacity {
                        NumberAnimation {
                            duration: AppTheme.animFast
                        }
                    }
                }

                // 播放/暂停（主按钮）
                Rectangle {
                    id: playPauseBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: playPauseHandler.hovered ? AppTheme.accentHover : AppTheme.accent
                    anchors.verticalCenter: parent.verticalCenter

                    // 发光效果
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: parent.height + 6
                        radius: (parent.width + 6) / 2
                        color: "transparent"
                        border.width: 2
                        border.color: AppTheme.accentGlow
                    }

                    Image {
                        id: playPauseIcon
                        anchors.centerIn: parent
                        source: playlistmanager ? (playlistmanager.isPaused ? AppIcon.playFill : AppIcon.pauseFill) : AppIcon.playFill
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 22
                        height: 22
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: playPauseIcon
                            color: AppTheme.iconDefault
                        }
                    }

                    HoverHandler {
                        id: playPauseHandler
                    }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (playlistmanager.type === 1) {
                                // TOGETHER 模式：没有歌曲时不发指令
                                if (playlistmanager.currentIndex < 0) return;
                                if (playlistmanager.isPaused) {
                                    websocket.resumeTogether();
                                } else {
                                    websocket.pauseTogether();
                                }
                            } else {
                                playlistmanager.playstop();
                            }
                        }
                    }

                    scale: playPauseHandler.hovered ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: AppTheme.animFast
                        }
                    }
                }

                // 下一曲
                Rectangle {
                    id: nextBtn
                    width: 36
                    height: 36
                    radius: 18
                    color: nextHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: nextIcon
                        anchors.centerIn: parent
                        source: AppIcon.next
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 20
                        height: 20
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: nextIcon
                            color: AppTheme.iconDefault
                        }
                    }

                    HoverHandler {
                        id: nextHandler
                    }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (playlistmanager.type === 1) {
                                websocket.playNextTogether();
                            } else {
                                playlistmanager.playNext();
                            }
                        }
                    }

                    scale: nextHandler.hovered ? 1.1 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: AppTheme.animFast
                        }
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: AppTheme.animThemeTransition
                    easing.type: Easing.OutCubic
                }
            }
        }

        // ========== 进度条（弹性宽度）==========
        Row {
            id: progressSection
            height: parent.height
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: currentTimeText
                text: playlistmanager ? playlistmanager.percentstr : "00:00"
                font.family: AppTheme.fontFamily
                font.pixelSize: AppTheme.fontSizeCaption
                color: AppTheme.isDark ? "#99FFFFFF" : AppTheme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                id: progressContainer
                height: parent.height
                // 弹性填充剩余宽度：随 leftSection(贴合歌名)/歌词容器宽度动态变化，保证右端按钮始终贴右
                width: controlBar.width - leftSection.width - lyricsControlContainer.width - rightSection.width - currentTimeText.implicitWidth - totalTimeText.implicitWidth - 56

                // 底层轨道
                Rectangle {
                    id: progressSlider
                    anchors.centerIn: parent
                    width: parent.width
                    height: progressMouseArea.containsMouse || progressSlider.dragging ? 4 : 2
                    radius: height / 2
                    color: AppTheme.isDark ? "#1AFFFFFF" : "#1A000000"

                    property real value: playlistmanager ? playlistmanager.percent : 0.0
                    property real dlProgress: playlistmanager ? playlistmanager.downloadProgress : 1.0
                    property bool dragging: false

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        id: progressMouseArea
                        anchors.fill: parent
                        anchors.leftMargin: -8
                        anchors.rightMargin: -8
                        anchors.topMargin: -14
                        anchors.bottomMargin: -14
                        hoverEnabled: true

                        onPressed: {
                            if (playlistmanager.type === 1) return;
                            progressSlider.dragging = true;
                            updateProgress(mouseX);
                        }
                        onPositionChanged: {
                            if (playlistmanager.type === 1) return;
                            if (pressed) updateProgress(mouseX);
                        }
                        onReleased: {
                            if (progressSlider.dragging) {
                                commitProgress();
                                progressSlider.dragging = false;
                            }
                        }
                        onClicked: {
                            if (playlistmanager.type === 1) return;
                            updateProgress(mouseX);
                            commitProgress();
                        }

                        function updateProgress(mouseX) {
                            var v = Math.max(0, Math.min(1, mouseX / progressSlider.width));
                            progressFill.tempWidth = progressSlider.width * v;
                        }
                        function commitProgress() {
                            var v = progressFill.tempWidth / progressSlider.width;
                            if (playlistmanager) playlistmanager.setposistion(v);
                        }
                    }

                    // 已下载进度（中间色）
                    Rectangle {
                        id: downloadFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius
                        color: AppTheme.isDark ? "#30FFFFFF" : "#20FF8A80"
                        width: parent.width * progressSlider.dlProgress
                        visible: progressSlider.dlProgress < 1.0
                    }

                    // 已播放进度
                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius
                        width: progressSlider.dragging ? tempWidth : parent.width * progressSlider.value
                        property real tempWidth: 0

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: AppTheme.isDark ? "#B0FFFFFF" : AppTheme.accent }
                            GradientStop { position: 1.0; color: AppTheme.isDark ? "#FFFFFFFF" : AppTheme.accentHover }
                        }
                    }

                    // 拖拽指示点（仅悬停/拖拽时显示）
                    Rectangle {
                        id: progressDot
                        width: 12
                        height: 12
                        radius: 6
                        color: AppTheme.isDark ? "#FFFFFF" : AppTheme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressFill.width - width / 2
                        opacity: progressMouseArea.containsMouse || progressSlider.dragging ? 1 : 0
                        scale: progressMouseArea.containsMouse || progressSlider.dragging ? 1 : 0.5

                        // 柔和阴影
                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: AppTheme.isDark ? "#33FFFFFF" : "#20FF8A80"
                        }

                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Text {
                id: totalTimeText
                text: playlistmanager ? playlistmanager.duration : "00:00"
                font.family: AppTheme.fontFamily
                font.pixelSize: AppTheme.fontSizeCaption
                color: AppTheme.isDark ? "#99FFFFFF" : AppTheme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ========== 右侧：功能按钮 ==========
        Row {
            id: rightSection
            width: 72
            height: parent.height
            spacing: 4
            layoutDirection: Qt.RightToLeft
            anchors.verticalCenter: parent.verticalCenter

            // 播放列表弹窗：本地 ListModel 镜像 C++ 队列（同步函数定义在根 controlBar 上，全文档可见）
            ListModel {
                id: queueModel
            }
            Connections {
                target: playlistmanager
                function onPlaylistUpdated() { controlBar.syncQueueModel() }
                function onTogetherplaylistUpdated() { controlBar.syncQueueModel() }
                function onPlaylist_typeChanged() { controlBar.syncQueueModel() }
            }

            // 播放列表
            Rectangle {
                id: playlistBtn
                width: 32
                height: 32
                radius: 16
                color: playlistBtnHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: playlistIcon
                    anchors.centerIn: parent
                    source: AppIcon.queue
                    sourceSize: Qt.size(128, 128)
                    mipmap: true
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playlistIcon
                        color: playlistBtnHandler.hovered ? AppTheme.iconHover : AppTheme.textMuted
                    }
                }

                HoverHandler {
                    id: playlistBtnHandler
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: playlistPopup.open()
                }

                Popup {
                    id: playlistPopup
                    x: -(320 - playlistBtn.width)
                    y: -420
                    width: 320
                    height: 400
                    padding: 0
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    onOpened: {
                        controlBar.syncQueueModel()
                        // 队列必含当前歌，打开即定位到正在播放
                        if (playlistmanager && playlistmanager.currentIndex >= 0
                            && playlistmanager.currentIndex < queueModel.count)
                            playlistView.positionViewAtIndex(playlistmanager.currentIndex, ListView.Center)
                    }

                    background: Rectangle {
                        radius: 12
                        color: AppTheme.bgCard
                        border.width: 1
                        border.color: AppTheme.borderDefault
                    }

                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: AppTheme.animFast }
                        NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: AppTheme.animFast; easing.type: Easing.OutCubic }
                    }
                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                        NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 100 }
                    }

                    Column {
                        anchors.fill: parent

                        Rectangle {
                            width: parent.width
                            height: 44
                            radius: 12
                            color: "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 6

                                Text {
                                    text: "播放列表"
                                    font.pixelSize: AppTheme.fontSizeBodyLg
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    // 懒加载源歌单时直接显示真实总数（拉取过程中也是准的）；
                                    // 普通/一起听队列 count 即实际大小，两者数值一致
                                    text: "(" + (playlistmanager && playlistmanager.playlistTotalCount > playlistView.count
                                                 ? playlistmanager.playlistTotalCount : playlistView.count) + ")"
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: parent.width - 200; height: 1 }

                                Text {
                                    text: "清空"
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.family: AppTheme.fontFamily
                                    color: clearBtnArea.containsMouse ? AppTheme.accent : AppTheme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: playlistmanager && playlistmanager.type === 0

                                    MouseArea {
                                        id: clearBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (playlistmanager) playlistmanager.clearPlaylist()
                                        }
                                    }
                                }
                            }

                            // 底部分隔线
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: AppTheme.borderDefault
                            }
                        }

                        // 歌曲列表
                        ListView {
                            id: playlistView
                            width: parent.width
                            height: parent.height - 44
                            clip: true
                            spacing: 0
                            cacheBuffer: 1500

                            model: queueModel

                            // 滚到底按需加载更多源数据（仅本地懒加载模式）
                            onContentYChanged: {
                                if (playlistmanager && playlistmanager.type === 0
                                    && contentHeight > height
                                    && contentY >= contentHeight - height - 120) {
                                    playlistmanager.requestMoreSourceTracks()
                                }
                            }

                            footer: Component {
                                Item {
                                    width: playlistView.width
                                    height: visible ? 32 : 0
                                    visible: playlistmanager && playlistmanager.type === 0 && playlistmanager.playlistTotalCount > 0

                                    Text {
                                        anchors.centerIn: parent
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.textDim
                                        text: {
                                            var loaded = playlistmanager ? playlistmanager.playlistcount : 0
                                            var total = playlistmanager ? playlistmanager.playlistTotalCount : 0
                                            return loaded >= total ? ("共 " + total + " 首")
                                                                   : ("已加载 " + loaded + " / " + total)
                                        }
                                    }
                                }
                            }

                            delegate: Rectangle {
                                width: playlistView.width
                                height: 44
                                // 防护：Popup 首次实例化时 playlistmanager 可能尚未就绪
                                readonly property int curIdx: playlistmanager ? playlistmanager.currentIndex : -1
                                readonly property bool isCurrent: index === curIdx
                                // hover/播放改为文字高亮（背景透明，渐变下无块状覆盖层）
                                color: "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    // 序号或播放指示
                                    Text {
                                        width: 24
                                        height: parent.height
                                        text: index === curIdx ? "♪" : (index + 1)
                                        font.pixelSize: index === curIdx ? 14 : 12
                                        font.family: AppTheme.fontFamily
                                        color: index === curIdx ? AppTheme.accent : AppTheme.textMuted
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Column {
                                        width: parent.width - 24 - 50 - 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true

                                        Text {
                                            text: model.title
                                            font.pixelSize: AppTheme.fontSizeBody
                                            font.family: AppTheme.fontFamily
                                            font.bold: true
                                            // hover 歌曲名高亮，当前播放行保持强调色
                                            color: (index === curIdx || songItemMA.containsMouse) ? AppTheme.accent : AppTheme.textSongTitle
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: model.singername
                                            font.pixelSize: AppTheme.fontSizeXs
                                            font.family: AppTheme.fontFamily
                                            font.bold: true
                                            color: AppTheme.textMuted
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    Text {
                                        text: {
                                            var d = model.duration
                                            if (d.indexOf(":") >= 0) return d
                                            var sec = parseInt(d) || 0
                                            var m = Math.floor(sec / 60)
                                            var s = sec % 60
                                            return m + ":" + (s < 10 ? "0" : "") + s
                                        }
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // 删除按钮（仅本地模式）
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: delBtnMA.containsMouse ? AppTheme.bgCardHover : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: playlistmanager && playlistmanager.type === 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.pixelSize: AppTheme.fontSizeBodyLg
                                            color: delBtnMA.containsMouse ? AppTheme.accent : AppTheme.textMuted
                                        }

                                        MouseArea {
                                            id: delBtnMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (playlistmanager) playlistmanager.removeSong(index)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: songItemMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (playlistmanager) playlistmanager.playSongbyindex(index)
                                    }
                                }
                            }
                        }
                    }

                    // 右下角浮动「定位到正在播放」按钮
                    LocateCurrentButton {
                        target: playlistView
                        currentSongIndex: playlistmanager ? playlistmanager.currentIndex : -1
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        z: 10
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: AppTheme.animFast
                    }
                }
            }

            // 歌词
            Rectangle {
                id: lyricsBtn
                width: 32
                height: 32
                radius: 16
                color: lyricsBtnHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: lyricsIcon
                    anchors.centerIn: parent
                    source: AppIcon.lyrics
                    sourceSize: Qt.size(128, 128)
                    mipmap: true
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: lyricsIcon
                        color: (lyricsConfig && lyricsConfig.enabled) ? AppTheme.accent : (lyricsBtnHandler.hovered ? AppTheme.iconHover : AppTheme.textMuted)
                    }
                }

                HoverHandler {
                    id: lyricsBtnHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: BasicConfig.requestDesktopLyricsSettings()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: AppTheme.animFast
                    }
                }
            }
        }
    }
}
