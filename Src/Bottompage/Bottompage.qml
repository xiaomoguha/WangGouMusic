import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Rectangle {
    Row {
        spacing: 8
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        Rectangle {
            width: 60
            height: 60
            radius: width / 2
            clip: true
            Image {
                id: avatarImage
                anchors.fill: parent
                property real currentRotation: 0
                source: playlistmanager ? (playlistmanager.union_cover === "" ? "qrc:/image/touxi.jpg" : playlistmanager.union_cover) : "qrc:/image/touxi.jpg"
                rotation: currentRotation
                asynchronous: true
                cache: true
                mipmap: true
                sourceSize.width: 120
                sourceSize.height: 120
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 60
                        height: 60
                        radius: width / 2
                    }
                }
                NumberAnimation on currentRotation {
                    id: rotationAnim
                    from: 0
                    to: 360
                    duration: 5000
                    loops: Animation.Infinite
                    running: playlistmanager && !playlistmanager.isPaused && root.visible
                }
                // 根据 isPaused 启停动画
                Connections {
                    target: playlistmanager
                    function onIsPausedChanged() {
                        if (!playlistmanager.isPaused && root.visible) {
                            // 从当前角度重新开始动画
                            rotationAnim.from = avatarImage.currentRotation % 360;
                            rotationAnim.to = rotationAnim.from + 360;
                            rotationAnim.start();
                        } else {
                            rotationAnim.stop();
                        }
                    }
                }
                // 窗口可见性变化时控制动画
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (playlistmanager && !playlistmanager.isPaused && root.visible) {
                            rotationAnim.from = avatarImage.currentRotation % 360;
                            rotationAnim.to = rotationAnim.from + 360;
                            rotationAnim.start();
                        } else {
                            rotationAnim.stop();
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.lyricsOpened = !root.lyricsOpened;
                    }
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                id: songnameText
                text: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
                font.family: "黑体"
                font.pixelSize: 16
                color: "white"
                elide: Text.ElideRight
                width: 120
                wrapMode: Text.NoWrap
            }
            Text {
                id: singernameText
                text: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
                font.family: "黑体"
                font.pixelSize: 14
                color: "#cdcdcd"
                elide: Text.ElideRight
                width: 120
                wrapMode: Text.NoWrap
            }
        }
        Item {
            width: 1
            height: 1
        }
        // 评论按钮
        Rectangle {
            id: pinlunicon
            width: 32
            height: 32
            radius: 16
            color: pinlunMouseArea.containsMouse ? "#30FFFFFF" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: pinlunImg
                anchors.centerIn: parent
                source: "qrc:/image/pinlun.png"
                width: 18
                height: 18
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: pinlunImg
                    color: pinlunMouseArea.containsMouse ? "#4FC3F7" : "#FFFFFF"
                }
            }

            MouseArea {
                id: pinlunMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        Item {
            width: 1
            height: 15
        }
        Row {
            spacing: 20
            anchors.horizontalCenter: parent.horizontalCenter

            // 收藏按钮
            Rectangle {
                id: loveaddbutton
                width: 36
                height: 36
                radius: 18
                color: loveaddMouseArea.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: playstoprect.verticalCenter

                Image {
                    id: loveaddImg
                    anchors.centerIn: parent
                    source: "qrc:/image/shoucang.png"
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: loveaddImg
                        color: loveaddMouseArea.containsMouse ? "#FF6B6B" : "#FFFFFF"
                    }
                }

                MouseArea {
                    id: loveaddMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 上一曲按钮
            Rectangle {
                id: upplayicon
                width: 36
                height: 36
                radius: 18
                color: upplayMouseArea.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: playstoprect.verticalCenter

                Image {
                    id: upplayImg
                    anchors.centerIn: parent
                    source: "qrc:/image/upplay.png"
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: upplayImg
                        color: "#FFFFFF"
                    }
                }

                MouseArea {
                    id: upplayMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playlistmanager.playPrevious();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 播放/暂停按钮
            Rectangle {
                id: playstoprect
                width: 40
                height: 40
                color: "#FFFFFF"
                radius: width / 2

                Image {
                    id: playstopicon
                    anchors.centerIn: parent
                    source: playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png"
                    width: 18
                    height: 18
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playstopicon
                        color: "#333333"
                    }
                }

                MouseArea {
                    id: playstopMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playlistmanager.playstop();
                    }
                }

                scale: playstopMouseArea.pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            // 下一曲按钮
            Rectangle {
                id: nextplayicon
                width: 36
                height: 36
                radius: 18
                color: nextplayMouseArea.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: playstoprect.verticalCenter

                Image {
                    id: nextplayImg
                    anchors.centerIn: parent
                    source: "qrc:/image/nextplay.png"
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: nextplayImg
                        color: "#FFFFFF"
                    }
                }

                MouseArea {
                    id: nextplayMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playlistmanager.playNext();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 播放模式按钮
            Rectangle {
                id: playlisticon
                width: 36
                height: 36
                radius: 18
                color: playlistMouseArea.containsMouse ? "#30FFFFFF" : "transparent"
                anchors.verticalCenter: playstoprect.verticalCenter

                Image {
                    id: playlistImg
                    anchors.centerIn: parent
                    source: "qrc:/image/shunxv.png"
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playlistImg
                        color: "#FFFFFF"
                    }
                }

                MouseArea {
                    id: playlistMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
        Row {
            spacing: 10
            Text {
                id: aplaytext
                anchors.verticalCenter: progressSlideritem.verticalCenter
                text: playlistmanager ? playlistmanager.percentstr : "00:00"
                font.family: "黑体"
                font.pixelSize: 13
                color: "#cdcdcd"
            }
            Item {
                id: progressSlideritem
                width: 400
                height: 30
                // 鼠标交互区域
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onPressed: {
                        progressSlider.dragging = true;
                        updateProgress(mouseX);
                    }

                    onPositionChanged: {
                        if (pressed) {
                            updateProgress(mouseX);
                        }
                    }

                    onReleased: {
                        if (progressSlider.dragging) {
                            commitProgress();  // 拖动结束时提交到后端
                            progressSlider.dragging = false;
                        }
                    }

                    onClicked: {  // 点击跳转（非拖动）
                        updateProgress(mouseX);
                        commitProgress();
                    }

                    // 更新进度显示（不提交到后端）
                    function updateProgress(mouseX) {
                        var newValue = Math.max(0, Math.min(1, mouseX / progressSlider.width));
                        progressContentRect.tempWidth = progressSlider.width * newValue;
                    }

                    // 提交进度到后端
                    function commitProgress() {
                        var newValue = progressContentRect.tempWidth / progressSlider.width;
                        if (playlistmanager) {
                            playlistmanager.setposistion(newValue);  // 调用C++方法
                        }
                    }
                }
                Rectangle {
                    id: progressSlider
                    color: "#4d4d56"
                    height: 2
                    width: 400
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    property real value: playlistmanager ? playlistmanager.percent : 0.0  // 绑定后端进度（0~1）
                    property bool dragging: false       // 标记是否正在拖动
                    // 已播放的部分（进度条填充）
                    Rectangle {
                        id: progressContentRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: height / 2
                        color: "#b94d51"
                        width: progressSlider.dragging ? tempWidth : parent.width * progressSlider.value  // 拖动时用临时值，否则用后端值
                        property real tempWidth: 0  // 拖动时的临时宽度
                    }

                    // 点光源发光效果容器
                    Item {
                        id: lightSource
                        width: parent.height + 20 // 比滑块大一些
                        height: width
                        anchors.right: progressContentRect.right
                        anchors.rightMargin: -width / 2
                        anchors.verticalCenter: progressContentRect.verticalCenter

                        // 点光源核心
                        Rectangle {
                            id: lightCore
                            width: parent.height * 0.4 // 核心尺寸
                            height: width
                            radius: width / 2
                            color: "#ff8e9e"
                            anchors.centerIn: parent

                            // 核心发光动画
                            SequentialAnimation on scale {
                                id: coreAnimation
                                loops: Animation.Infinite
                                running: playlistmanager ? (playlistmanager.isPaused ? false : true) : false
                                NumberAnimation {
                                    to: 1.2
                                    duration: 800
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 1200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        // 点光源光晕
                        Rectangle {
                            id: lightHalo
                            anchors.fill: parent
                            radius: width / 2
                            visible: false // 仅作为源使用
                        }

                        // 径向渐变发光
                        RadialGradient {
                            id: radialGradient
                            anchors.fill: lightHalo
                            source: lightHalo
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: "#40ff8e9e"
                                } // 中心颜色
                                GradientStop {
                                    position: 0.7
                                    color: "#20ff8e9e"
                                } // 中间过渡
                                GradientStop {
                                    position: 1.0
                                    color: "#00ff8e9e"
                                } // 边缘透明
                            }

                            // 光晕呼吸动画
                            SequentialAnimation on scale {
                                id: haloAnimation
                                loops: Animation.Infinite
                                running: playlistmanager ? (playlistmanager.isPaused ? false : true) : false
                                NumberAnimation {
                                    to: 1.2
                                    duration: 1000
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 1500
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        // 光晕模糊效果
                        FastBlur {
                            anchors.fill: radialGradient
                            source: radialGradient
                            radius: 16 // 模糊程度
                            transparentBorder: true
                        }
                        // 点光源动画控制器
                        function toggleLightAnimation(running) {
                            coreAnimation.running = running;
                            haloAnimation.running = running;
                        }
                    }
                }
            }
            Text {
                id: eplaytext
                anchors.verticalCenter: progressSlideritem.verticalCenter
                text: playlistmanager ? playlistmanager.duration : "00:00"
                font.family: "黑体"
                font.pixelSize: 13
                color: "#cdcdcd"
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 40
        spacing: 12

        // 歌词按钮
        Rectangle {
            id: geciicon
            width: 36
            height: 36
            radius: 18
            color: geciMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

            Image {
                id: geciImg
                anchors.centerIn: parent
                source: "qrc:/image/geci.png"
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: geciImg
                    color: desktopLyricsWindow ? (desktopLyricsWindow.visible ? "#FF6B6B" : "#FFFFFF") : "#FFFFFF"
                }
            }

            Component.onCompleted: {
                geciImg.layer.enabled = desktopLyricsWindow ? desktopLyricsWindow.visible : false;
            }

            MouseArea {
                id: geciMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
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

        // 解锁桌面歌词按钮（锁定时显示）
        Rectangle {
            id: unlockLyricsBtn
            width: 36
            height: 36
            radius: 18
            color: unlockMouseArea.containsMouse ? "#FF8080" : "#FF6B6B"
            visible: desktopLyricsWindow && desktopLyricsWindow.locked && desktopLyricsWindow.visible

            Image {
                id: unlockIcon
                anchors.centerIn: parent
                source: "qrc:/image/lock_close.png"
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: unlockIcon
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: unlockMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (desktopLyricsWindow) {
                        desktopLyricsWindow.locked = false;
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 音量按钮
        Rectangle {
            id: shenyingicon
            width: 36
            height: 36
            radius: 18
            color: shenyingMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

            Image {
                id: shenyingImg
                anchors.centerIn: parent
                source: "qrc:/image/shenying.png"
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: shenyingImg
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: shenyingMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 播放列表按钮
        Rectangle {
            id: liebiaoicon
            width: 36
            height: 36
            radius: 18
            color: liebiaoMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

            Image {
                id: liebiaoImg
                anchors.centerIn: parent
                source: "qrc:/image/liebiao.png"
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: liebiaoImg
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: liebiaoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }
}
