import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Rectangle {
    id: controlBar
    color: "#1a1a24"

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
                color: "#30FF6B6B"
            }
            GradientStop {
                position: 0.5
                color: "#50FF6B6B"
            }
            GradientStop {
                position: 0.7
                color: "#30FF6B6B"
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
        anchors.rightMargin: 20
        spacing: 15

        // ========== 左侧：歌曲信息 ==========
        Row {
            id: leftSection
            width: 180
            height: parent.height
            spacing: 12

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
                    border.color: playlistmanager && !playlistmanager.isPaused ? "#40FF6B6B" : "transparent"
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
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                    width: parent.width
                    wrapMode: Text.NoWrap
                }

                Text {
                    id: singerNameText
                    text: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
                    font.family: "黑体"
                    font.pixelSize: 12
                    color: "#888899"
                    elide: Text.ElideRight
                    width: parent.width
                    wrapMode: Text.NoWrap
                }
            }
        }

        // ========== 中间：播放控制（横向排列）==========
        Row {
            height: parent.height
            spacing: 16
            anchors.verticalCenter: parent.verticalCenter

            // 上一曲
            Rectangle {
                id: prevBtn
                width: 36
                height: 36
                radius: 18
                color: prevHandler.hovered ? "#25FFFFFF" : "transparent"
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
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: prevHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: playlistmanager.playPrevious()
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
                color: playPauseHandler.hovered ? "#FF5252" : "#FF6B6B"
                anchors.verticalCenter: parent.verticalCenter

                // 发光效果
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 6
                    radius: (parent.width + 6) / 2
                    color: "transparent"
                    border.width: 2
                    border.color: "#40FF6B6B"
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
                        color: "#FFFFFF"
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
                color: nextHandler.hovered ? "#25FFFFFF" : "transparent"
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
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: nextHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: playlistmanager.playNext()
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
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
                color: "#666677"
                anchors.verticalCenter: parent.verticalCenter
            }

            // 进度条容器
            Item {
                id: progressContainer
                height: parent.height
                // 进度条宽度 = 总宽度 - 左侧(180) - 中间控制(152) - 右侧(120) - 边距(40) - spacing(45) - 时间文字(约80)
                width: Math.max(100, controlBar.width - 180 - 152 - 120 - 40 - 45 - 80)

                // 进度条
                Rectangle {
                    id: progressSlider
                    anchors.centerIn: parent
                    width: parent.width
                    height: 4
                    radius: 2
                    color: "#2A2A35"

                    property real value: playlistmanager ? playlistmanager.percent : 0.0
                    property bool dragging: false

                    // 悬停高亮边框
                    border.width: progressMouseArea.containsMouse ? 1 : 0
                    border.color: "#80FF6B6B"
                    Behavior on border.width {
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
                        radius: 2
                        color: "#FF6B6B"
                        width: progressSlider.dragging ? tempWidth : parent.width * progressSlider.value
                        property real tempWidth: 0
                    }

                    // 播放指示点
                    Rectangle {
                        id: progressDot
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressFill.width - width / 2

                        // 发光效果
                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: "#30FF6B6B"
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
                color: "#666677"
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
                color: playlistBtnHandler.hovered ? "#25FFFFFF" : "transparent"
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
                        color: playlistBtnHandler.hovered ? "#FFFFFF" : "#AAAABB"
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
                color: volumeBtnHandler.hovered ? "#25FFFFFF" : "transparent"
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
                        color: volumeBtnHandler.hovered ? "#FFFFFF" : "#AAAABB"
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
                color: lyricsBtnHandler.hovered ? "#25FFFFFF" : "transparent"
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
                        color: desktopLyricsWindow && desktopLyricsWindow.visible ? "#FF6B6B" : (lyricsBtnHandler.hovered ? "#FFFFFF" : "#AAAABB")
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
