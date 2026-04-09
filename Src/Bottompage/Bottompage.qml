import QtQuick 2.15
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
        anchors.leftMargin: 35
        anchors.rightMargin: 20
        spacing: 8

        // ========== 左侧：歌曲信息 ==========
        Row {
            id: leftSection
            width: 180
            height: parent.height
            spacing: 5

            // 专辑封面（旋转动画）
            Rectangle {
                id: albumCoverContainer
                width: 50
                height: 50
                radius: 25
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
                    sourceSize.width: 100
                    sourceSize.height: 100
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                        }
                    }

                    property real currentRotation: 0
                    rotation: currentRotation

                    NumberAnimation on currentRotation {
                        id: rotationAnim
                        from: 0
                        to: 360
                        duration: 8000
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
                width: 110

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
        Item {
            width: -1
            height: parent.height
        }

        // ========== 中间：播放控制（歌词/按钮切换）==========
        Item {
            id: lyricsControlContainer
            width: 200  // 扩大宽度，让歌词区域更靠近左侧歌曲信息
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

                // 高亮比例
                property real highlightRatio: {
                    var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || lyricText.length) : lyricText.length;
                    if (totalChars === 0 || charIndex < 0)
                        return 0;
                    return (charIndex + charProgress) / totalChars;
                }

                // 歌词内容容器（左对齐，与桌面歌词一致）
                Item {
                    id: lyricsContainer
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: lyricsScrollLayer.width - 20
                    height: 24
                    clip: true  // 裁剪超出部分

                    // 底层：完整灰色文字（左对齐）
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

                    // 高亮层：从左到右刷过去（与桌面歌词一致）
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

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ===== 控制按钮层（悬停显示，按钮在歌词区域左侧中间） =====
            Row {
                id: controlButtonsLayer
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
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
                        onTapped: playlistmanager.playPrevious()
                    }

                    scale: prevHandler.hovered ? 1.1 : 1.0
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
                        onTapped: playlistmanager.playstop()
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
                        onTapped: playlistmanager.playNext()
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
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            // 当前时间
            Text {
                id: currentTimeText
                text: playlistmanager ? playlistmanager.percentstr : "00:00"
                font.family: "黑体"
                font.pixelSize: 12
                color: AppTheme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }

            // 进度条容器
            Item {
                id: progressContainer
                height: parent.height
                // 进度条宽度 = 总宽度 - 左侧(180) - 中间控制(152) - 右侧(120) - 边距(40) - spacing(45) - 时间文字(约80)
                width: 0.35 * root.width

                // 进度条
                Rectangle {
                    id: progressSlider
                    anchors.centerIn: parent
                    width: parent.width
                    height: progressMouseArea.containsMouse ? 6 : 4
                    radius: height / 2
                    color: AppTheme.progressTrack

                    property real value: playlistmanager ? playlistmanager.percent : 0.0
                    property bool dragging: false

                    // 悬停高亮边框
                    border.width: progressMouseArea.containsMouse ? 1 : 0
                    border.color: AppTheme.accentGlow
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    MouseArea {
                        id: progressMouseArea
                        anchors.fill: parent
                        // 扩大悬停检测范围
                        anchors.leftMargin: -8
                        anchors.rightMargin: -8
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        hoverEnabled: true

                        onPressed: {
                            progressSlider.dragging = true;
                            updateProgress(mouseX);
                        }

                        onPositionChanged: {
                            if (pressed)
                                updateProgress(mouseX);
                        }

                        onReleased: {
                            if (progressSlider.dragging) {
                                commitProgress();
                                progressSlider.dragging = false;
                            }
                        }

                        onClicked: {
                            updateProgress(mouseX);
                            commitProgress();
                        }

                        function updateProgress(mouseX) {
                            var newValue = Math.max(0, Math.min(1, mouseX / progressSlider.width));
                            progressFill.tempWidth = progressSlider.width * newValue;
                        }

                        function commitProgress() {
                            var newValue = progressFill.tempWidth / progressSlider.width;
                            if (playlistmanager) {
                                playlistmanager.setposistion(newValue);
                            }
                        }
                    }

                    // 已播放进度
                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius
                        color: AppTheme.accent
                        width: progressSlider.dragging ? tempWidth : parent.width * progressSlider.value
                        property real tempWidth: 0

                        // 播放时脉冲发光效果
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: AppTheme.accentGlow
                            visible: playlistmanager && !playlistmanager.isPaused
                            opacity: 0

                            SequentialAnimation on opacity {
                                running: playlistmanager && !playlistmanager.isPaused
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 0.3
                                    to: 0.8
                                    duration: 1200
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 0.8
                                    to: 0.3
                                    duration: 1200
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }

                    // 播放指示点
                    Rectangle {
                        id: progressDot
                        width: 12
                        height: 12
                        radius: 6
                        color: AppTheme.progressDot
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressFill.width - width / 2

                        // 发光效果 - 播放时脉冲
                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: AppTheme.accentGlow
                            visible: playlistmanager && !playlistmanager.isPaused

                            SequentialAnimation on scale {
                                running: playlistmanager && !playlistmanager.isPaused
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 0.8
                                    to: 1.3
                                    duration: 1000
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 1.3
                                    to: 0.8
                                    duration: 1000
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        scale: progressMouseArea.containsMouse ? 1.2 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }
                }
            }

            // 总时间
            Text {
                id: totalTimeText
                text: playlistmanager ? playlistmanager.duration : "00:00"
                font.family: "黑体"
                font.pixelSize: 12
                color: AppTheme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ========== 右侧：功能按钮 ==========
        Row {
            id: rightSection
            width: 120
            height: parent.height
            spacing: 6
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
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 音量
            Rectangle {
                id: volumeBtn
                width: 32
                height: 32
                radius: 16
                color: volumeBtnHandler.hovered ? AppTheme.iconButtonHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: volumeIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/shenying.png"
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: volumeIcon
                        color: volumeBtnHandler.hovered ? AppTheme.iconHover : AppTheme.textMuted
                    }
                }

                HoverHandler {
                    id: volumeBtnHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
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
