import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Rectangle {
    id: controlBar
    color: AppTheme.bgBottomBarInner

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
            width: 155
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
                            duration: 300
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
                        running: playlistmanager && !playlistmanager.isPaused && root.visible
                    }

                    Connections {
                        target: playlistmanager
                        function onIsPausedChanged() {
                            if (!playlistmanager.isPaused && root.visible) {
                                rotationAnim.from = albumCover.currentRotation % 360;
                                rotationAnim.to = rotationAnim.from + 360;
                                rotationAnim.start();
                            } else {
                                rotationAnim.stop();
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onVisibleChanged() {
                            if (playlistmanager && !playlistmanager.isPaused && root.visible) {
                                rotationAnim.from = albumCover.currentRotation % 360;
                                rotationAnim.to = rotationAnim.from + 360;
                                rotationAnim.start();
                            } else {
                                rotationAnim.stop();
                            }
                        }
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
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: 80

                Text {
                    id: songNameText
                    text: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
                    font.family: "黑体"
                    font.pixelSize: 14
                    font.bold: true
                    color: AppTheme.textPrimary
                    elide: Text.ElideRight
                    width: parent.width
                    wrapMode: Text.NoWrap
                }

                Text {
                    id: singerNameText
                    text: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
                    font.family: "黑体"
                    font.pixelSize: 12
                    color: AppTheme.textMuted
                    elide: Text.ElideRight
                    width: parent.width
                    wrapMode: Text.NoWrap
                }
            }
        }

        // ========== 中间：播放控制（歌词/按钮切换）==========
        Item {
            id: lyricsControlContainer
            width: 260
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            // 是否显示控制按钮：暂停时始终显示，播放时根据悬停状态
            property bool isPaused: playlistmanager ? playlistmanager.isPaused : false
            readonly property bool showControls: isPaused || containerHovered
            property bool containerHovered: false

            // 延迟隐藏定时器（仅播放状态使用）
            Timer {
                id: hideControlsDelay
                interval: 1500
                onTriggered: {
                    if (!lyricsControlContainer.isPaused) {
                        lyricsControlContainer.containerHovered = false;
                    }
                }
            }

            // 鼠标区域（覆盖整个按钮区域）
            MouseArea {
                id: lyricsContainerMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: {
                    hideControlsDelay.stop();
                    lyricsControlContainer.containerHovered = true;
                }
                onExited: {
                    hideControlsDelay.stop();
                    // 暂停状态立即重置，播放状态延迟重置
                    if (lyricsControlContainer.isPaused) {
                        lyricsControlContainer.containerHovered = false;
                    } else {
                        hideControlsDelay.restart();
                    }
                }
            }

            HoverHandler {
                id: lyricsContainerHover
            }

            // ===== 歌词滚动层（默认显示） =====
            Item {
                id: lyricsScrollLayer
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                opacity: lyricsControlContainer.showControls ? 0 : 1.0

                property string lyricText: playlistmanager ? (playlistmanager.currlyric || "网狗音乐") : "网狗音乐"
                property int charIndex: playlistmanager ? playlistmanager.lyricCharIndex : -1
                property real charProgress: playlistmanager ? playlistmanager.lyricCharProgress : 0.0

                property real highlightRatio: {
                    var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || lyricText.length) : lyricText.length;
                    if (totalChars === 0 || charIndex < 0)
                        return 0;
                    return (charIndex + charProgress) / totalChars;
                }

                // 是否需要滚动（文字超出容器）
                property bool needsScroll: bgText.implicitWidth > lyricsContainer.width
                // 高亮位置的 x 坐标
                property real highlightX: hlText.width * highlightRatio
                // 滚动偏移：保证高亮位置始终在容器中可见
                property real scrollOffset: {
                    if (!needsScroll) return 0;
                    var viewW = lyricsContainer.width;
                    // 目标：高亮点在容器 40%~60% 的位置
                    var target = highlightX - viewW * 0.45;
                    // 限制范围：不超出 [0, maxScroll]
                    var maxScroll = bgText.implicitWidth - viewW;
                    return Math.max(0, Math.min(maxScroll, target));
                }

                // 歌词内容容器
                Item {
                    id: lyricsContainer
                    anchors.fill: parent
                    height: 24
                    clip: true

                    // 内部可滑动层
                    Item {
                        id: lyricsSlide
                        width: Math.max(bgText.implicitWidth, lyricsContainer.width)
                        height: parent.height
                        // 短歌词居中，长歌词跟随高亮滚动
                        x: lyricsScrollLayer.needsScroll
                           ? -lyricsScrollLayer.scrollOffset
                           : (lyricsContainer.width - bgText.implicitWidth) / 2

                        Behavior on x {
                            enabled: lyricsScrollLayer.needsScroll
                            SmoothedAnimation { duration: 300; velocity: 150 }
                        }

                        // 底层：完整灰色文字
                        Text {
                            id: bgText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: lyricsScrollLayer.lyricText
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "黑体"
                            color: AppTheme.textMuted
                            maximumLineCount: 1
                        }

                        // 高亮层
                        Item {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: hlText.width * lyricsScrollLayer.highlightRatio
                            height: bgText.height
                            clip: true
                            visible: lyricsScrollLayer.highlightRatio > 0

                            Text {
                                id: hlText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: lyricsScrollLayer.lyricText
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "黑体"
                                color: AppTheme.accent
                                maximumLineCount: 1
                            }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ===== 控制按钮层（悬停显示，按钮在歌词区域居中） =====
            Row {
                id: controlButtonsLayer
                anchors.centerIn: parent
                spacing: 16
                opacity: lyricsControlContainer.showControls ? 1.0 : 0.0
                visible: opacity > 0

                // 上一曲
                Rectangle {
                    id: prevBtn
                    width: 36
                    height: 36
                    radius: 18
                    color: prevHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: prevIcon
                        anchors.centerIn: parent
                        source: "qrc:/image/upplay.png"
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

                    opacity: playlistmanager.type === 1 ? 0.3 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
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
                        source: playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png"
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
                            duration: 150
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
                        source: "qrc:/image/nextplay.png"
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
                            duration: 150
                        }
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
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

            // 当前时间
            Text {
                id: currentTimeText
                text: playlistmanager ? playlistmanager.percentstr : "00:00"
                font.family: "黑体"
                font.pixelSize: 11
                color: AppTheme.isDark ? "#99FFFFFF" : AppTheme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            // 进度条容器
            Item {
                id: progressContainer
                height: parent.height
                width: root.width - 640

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

            // 总时间
            Text {
                id: totalTimeText
                text: playlistmanager ? playlistmanager.duration : "00:00"
                font.family: "黑体"
                font.pixelSize: 11
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
                    source: "qrc:/image/liebiao.png"
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

                    background: Rectangle {
                        radius: 12
                        color: AppTheme.bgCard
                        border.width: 1
                        border.color: AppTheme.borderDefault
                    }

                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                        NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                    }
                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                        NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 100 }
                    }

                    Column {
                        anchors.fill: parent

                        // 标题栏
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
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "黑体"
                                    color: AppTheme.textPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "(" + playlistView.count + ")"
                                    font.pixelSize: 12
                                    font.family: "黑体"
                                    color: AppTheme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: parent.width - 200; height: 1 }

                                Text {
                                    text: "清空"
                                    font.pixelSize: 12
                                    font.family: "黑体"
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

                            model: playlistmanager ? (playlistmanager.type === 1 ? playlistmanager.togetherplaylist : playlistmanager.playlist) : []

                            delegate: Rectangle {
                                width: playlistView.width
                                height: 44
                                color: {
                                    if (index === playlistmanager.currentIndex) return AppTheme.accentDim
                                    return songItemMA.containsMouse ? AppTheme.bgCardHover : "transparent"
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    // 序号或播放指示
                                    Text {
                                        width: 24
                                        height: parent.height
                                        text: index === playlistmanager.currentIndex ? "♪" : (index + 1)
                                        font.pixelSize: index === playlistmanager.currentIndex ? 14 : 12
                                        font.family: "黑体"
                                        color: index === playlistmanager.currentIndex ? AppTheme.accent : AppTheme.textMuted
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // 歌名 + 歌手
                                    Column {
                                        width: parent.width - 24 - 50 - 24
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true

                                        Text {
                                            text: modelData.title
                                            font.pixelSize: 13
                                            font.family: "黑体"
                                            color: index === playlistmanager.currentIndex ? AppTheme.accent : AppTheme.textPrimary
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: modelData.singername
                                            font.pixelSize: 10
                                            font.family: "黑体"
                                            color: AppTheme.textMuted
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    // 时长
                                    Text {
                                        text: {
                                            var d = modelData.duration
                                            if (d.indexOf(":") >= 0) return d
                                            var sec = parseInt(d) || 0
                                            var m = Math.floor(sec / 60)
                                            var s = sec % 60
                                            return m + ":" + (s < 10 ? "0" : "") + s
                                        }
                                        font.pixelSize: 11
                                        font.family: "黑体"
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
                                            font.pixelSize: 14
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
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
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
                    source: "qrc:/image/geci.png"
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: lyricsIcon
                        color: desktopLyricsWindow && desktopLyricsWindow.visible ? AppTheme.accent : (lyricsBtnHandler.hovered ? AppTheme.iconHover : AppTheme.textMuted)
                    }
                }

                HoverHandler {
                    id: lyricsBtnHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyricsWindow) {
                            desktopLyricsWindow.visible = !desktopLyricsWindow.visible;
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
