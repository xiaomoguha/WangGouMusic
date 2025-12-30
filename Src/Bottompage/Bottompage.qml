import QtQuick 2.15
import Qt5Compat.GraphicalEffects
Rectangle{
    Row{
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
                id:avatarImage
                anchors.fill: parent
                property real currentRotation: 0
                source: playlistmanager ?(playlistmanager.union_cover === ""?"qrc:/image/touxi.jpg":playlistmanager.union_cover):"qrc:/image/touxi.jpg"
                rotation: currentRotation
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 60
                        height: 60
                        radius: width/2
                    }
                }
                NumberAnimation on currentRotation{
                    id: rotationAnim
                    from: 0
                    to: 360
                    duration: 5000
                    loops: Animation.Infinite
                    running: false
                }
                // 根据 isPaused 启停动画
                Connections
                {
                    target: playlistmanager
                    function onIsPausedChanged()
                    {
                        if (!playlistmanager.isPaused)
                        {
                            // 从当前角度重新开始动画
                            rotationAnim.from = avatarImage.currentRotation % 360
                            rotationAnim.to = rotationAnim.from + 360
                            rotationAnim.start()
                        }
                        else
                        {
                            rotationAnim.stop()
                        }
                    }
                }
                MouseArea{
                    anchors.fill: parent
                    onClicked: {
                        root.lyricsOpened = !root.lyricsOpened
                    }
                }
            }
        }
        Column{
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                id: songnameText
                text: playlistmanager?(playlistmanager.currentTitle === ""?"默认歌曲":playlistmanager.currentTitle):"........"
                font.family: "黑体"
                font.pixelSize: 16
                color:"white"
                elide: Text.ElideRight
                width: 120
                wrapMode: Text.NoWrap

            }
            Text {
                id: singernameText
                text: playlistmanager?(playlistmanager.currentsingername=== ""?"默认歌手":playlistmanager.currentsingername):"....."
                font.family: "黑体"
                font.pixelSize: 14
                color:"#cdcdcd"
                elide: Text.ElideRight
                width: 120
                wrapMode: Text.NoWrap
            }
        }
        Item{
            width: 1
            height: 1
        }
        Image {
            id: pinlunicon
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            fillMode: Image.PreserveAspectCrop
            source: "qrc:/image/pinlun.png"
            layer.effect: ColorOverlay{
                source:pinlunicon
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
            }
        }
    }
    Column{
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        Item{
            width: 1
            height: 15
        }
        Row{
            spacing: 25
            anchors.horizontalCenter: parent.horizontalCenter
            Image {
                id: loveaddbutton
                anchors.verticalCenter:playstoprect.verticalCenter
                source: "qrc:/image/shoucang.png"
                width: 25
                height: 25
                fillMode: Image.PreserveAspectCrop
                layer.effect: ColorOverlay{
                    source:loveaddbutton
                    color:"white"
                }
                MouseArea{
                    hoverEnabled: true
                    anchors.fill: parent
                    onEntered: {
                        parent.layer.enabled = true
                    }
                    onExited: {
                        parent.layer.enabled = false
                    }
                }
            }
            Image {
                id: upplayicon
                anchors.verticalCenter:playstoprect.verticalCenter
                source: "qrc:/image/upplay.png"
                width: 25
                height: 25
                fillMode: Image.PreserveAspectCrop
                layer.effect: ColorOverlay{
                    source:upplayicon
                    color:"white"
                }
                MouseArea{
                    hoverEnabled: true
                    anchors.fill: parent
                    onEntered: {
                        parent.layer.enabled = true
                    }
                    onExited: {
                        parent.layer.enabled = false
                    }
                    onClicked: {
                        //上一曲
                        playlistmanager.playPrevious()
                    }
                }
            }
            Rectangle{
                id: playstoprect
                width: 35
                height: 35
                color: "#fc3d49"
                radius: width/2
                Image {
                    id: playstopicon
                    anchors.fill: parent
                    source: playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png"
                    fillMode: Image.PreserveAspectCrop
                    scale: 0.6
                    layer.effect: ColorOverlay{
                        source:playstopicon
                        color:"white"
                    }
                    MouseArea{
                        hoverEnabled: true
                        anchors.fill: parent
                        onEntered: {
                            parent.layer.enabled = true
                        }
                        onExited: {
                            parent.layer.enabled = false
                        }
                        onClicked: {
                            playlistmanager.playstop()
                        }
                    }
                }
            }

            Image {
                id: nextplayicon
                anchors.verticalCenter:playstoprect.verticalCenter
                source: "qrc:/image/nextplay.png"
                width: 25
                height: 25
                fillMode: Image.PreserveAspectCrop
                layer.effect: ColorOverlay{
                    source:nextplayicon
                    color:"white"
                }
                MouseArea{
                    hoverEnabled: true
                    anchors.fill: parent
                    onEntered: {
                        parent.layer.enabled = true
                    }
                    onExited: {
                        parent.layer.enabled = false
                    }
                    onClicked: {
                        playlistmanager.playNext()
                    }
                }
            }
            Image {
                id: playlisticon
                anchors.verticalCenter:playstoprect.verticalCenter
                source: "qrc:/image/shunxv.png"
                width: 25
                height: 25
                fillMode: Image.PreserveAspectCrop
                layer.effect: ColorOverlay{
                    source:playlisticon
                    color:"white"
                }
                MouseArea{
                    hoverEnabled: true
                    anchors.fill: parent
                    onEntered: {
                        parent.layer.enabled = true
                    }
                    onExited: {
                        parent.layer.enabled = false
                    }
                }
            }
        }
        Row{
            spacing: 10
            Text{
                id:aplaytext
                anchors.verticalCenter: progressSlideritem.verticalCenter
                text: playlistmanager?playlistmanager.percentstr:"00:00"
                font.family: "黑体"
                font.pixelSize: 13
                color: "#cdcdcd"
            }
            Item{
                id:progressSlideritem
                width: 400
                height: 30
                // 鼠标交互区域
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onPressed: {
                        progressSlider.dragging = true
                        updateProgress(mouseX)
                    }

                    onPositionChanged: {
                        if (pressed) {
                            updateProgress(mouseX)
                        }
                    }

                    onReleased: {
                        if (progressSlider.dragging) {
                            commitProgress()  // 拖动结束时提交到后端
                            progressSlider.dragging = false
                        }
                    }

                    onClicked: {  // 点击跳转（非拖动）
                        updateProgress(mouseX)
                        commitProgress()
                    }

                    // 更新进度显示（不提交到后端）
                    function updateProgress(mouseX) {
                        var newValue = Math.max(0, Math.min(1, mouseX / progressSlider.width))
                        progressContentRect.tempWidth = progressSlider.width * newValue
                    }

                    // 提交进度到后端
                    function commitProgress() {
                        var newValue = progressContentRect.tempWidth / progressSlider.width
                        if (playlistmanager) {
                            playlistmanager.setposistion(newValue)  // 调用C++方法
                        }
                    }
                }
                Rectangle {
                    id: progressSlider
                    color: "#4d4d56"
                    height: 2
                    width: 400
                    radius: height/2
                    anchors.verticalCenter: parent.verticalCenter
                    property real value: playlistmanager ? playlistmanager.percent : 0.0  // 绑定后端进度（0~1）
                    property bool dragging: false       // 标记是否正在拖动
                    // 已播放的部分（进度条填充）
                    Rectangle {
                        id: progressContentRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: height/2
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
                        anchors.rightMargin: -width/2
                        anchors.verticalCenter: progressContentRect.verticalCenter

                        // 点光源核心
                        Rectangle {
                            id: lightCore
                            width: parent.height * 0.4 // 核心尺寸
                            height: width
                            radius: width/2
                            color: "#ff8e9e"
                            anchors.centerIn: parent

                            // 核心发光动画
                            SequentialAnimation on scale {
                                id: coreAnimation
                                loops: Animation.Infinite
                                running: playlistmanager ? (playlistmanager.isPaused ? false : true):false
                                NumberAnimation { to: 1.2; duration: 800; easing.type: Easing.OutCubic }
                                NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                            }
                        }

                        // 点光源光晕
                        Rectangle {
                            id: lightHalo
                            anchors.fill: parent
                            radius: width/2
                            visible: false // 仅作为源使用
                        }

                        // 径向渐变发光
                        RadialGradient {
                            id: radialGradient
                            anchors.fill: lightHalo
                            source: lightHalo
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#40ff8e9e" } // 中心颜色
                                GradientStop { position: 0.7; color: "#20ff8e9e" } // 中间过渡
                                GradientStop { position: 1.0; color: "#00ff8e9e" } // 边缘透明
                            }

                            // 光晕呼吸动画
                            SequentialAnimation on scale {
                                id: haloAnimation
                                loops: Animation.Infinite
                                running: playlistmanager ? (playlistmanager.isPaused ? false : true):false
                                NumberAnimation { to: 1.2; duration: 1000; easing.type: Easing.OutCubic }
                                NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
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
                            coreAnimation.running = running
                            haloAnimation.running = running
                        }
                    }
                }
            }
            Text{
                id:eplaytext
                anchors.verticalCenter: progressSlideritem.verticalCenter
                text: playlistmanager?playlistmanager.duration:"00:00"
                font.family: "黑体"
                font.pixelSize: 13
                color: "#cdcdcd"
            }
        }
    }
    Row{
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 40
        spacing: 10
        Image {
            id: geciicon
            source: "qrc:/image/geci.png"
            width: 25
            height: 25
            scale: 1.2
            fillMode: Image.PreserveAspectCrop
            layer.effect: ColorOverlay{
                source:geciicon
                color:Qt.platform.os === "windows"?desktopLyricsWindow?(desktopLyricsWindow.visible?"#E74F50":"white"):"white":"white"
            }
            // 组件初始化完成后执行
            Component.onCompleted: {
                if(Qt.platform.os === "windows")
                    layer.enabled = desktopLyricsWindow?desktopLyricsWindow.visible:false
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    if(Qt.platform.os === "windows")
                    {
                        if(!desktopLyricsWindow.visible)
                        {
                            parent.layer.enabled = false
                        }
                    }

                }
                onClicked: {
                    if(Qt.platform.os ==="windows"&&desktopLyricsWindow)
                    {
                        desktopLyricsWindow.visible = !desktopLyricsWindow.visible
                    }
                }
            }
        }
        Image {
            id: shenyingicon
            source: "qrc:/image/shenying.png"
            width: 25
            height: 25
            fillMode: Image.PreserveAspectCrop
            layer.effect: ColorOverlay{
                source:shenyingicon
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
            }
        }
        Image {
            id: liebiaoicon
            source: "qrc:/image/24gl-playlistHeart.png"
            width: 25
            height: 25
            fillMode: Image.PreserveAspectCrop
            layer.effect: ColorOverlay{
                source:liebiaoicon
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
            }
        }
    }
}
