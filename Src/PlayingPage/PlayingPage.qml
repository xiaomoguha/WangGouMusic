import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: lyricspage
    color: "#13131a"
    radius: 20

    property string albumCover: playlistmanager ? (playlistmanager.union_cover === "" ? "qrc:/image/touxi.jpg" : playlistmanager.union_cover) : "qrc:/image/touxi.jpg"
    property string songName: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
    property string singerName: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
    property string dominantColor: playlistmanager ? playlistmanager.dominantColor : "#FF6B6B"

    // 1. 原始图片
    Image {
        id: originalImage
        anchors.fill: parent
        source: albumCover
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false  // 隐藏原图
        sourceSize.width: 600
        sourceSize.height: 600
    }

    // 2. 先进行高斯模糊
    GaussianBlur {
        id: blurredImage
        anchors.fill: parent
        source: originalImage
        radius: Math.min(parent.width, parent.height) * 0.4
        samples: 120
        transparentBorder: true  // 重要！
        visible: false  // 隐藏模糊结果
    }

    // === 最终覆盖层 ===
    ColorOverlay {
        id: cover
        anchors.fill: blurredImage
        source: blurredImage
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: 1.0
        visible: false
    }

    // 3. 最后应用圆角裁剪
    OpacityMask {
        id: bgopmk
        anchors.fill: parent
        source: cover
        maskSource: Rectangle {
            width: originalImage.width
            height: originalImage.height
            radius: 20
            visible: false
        }
    }

    MouseArea {
        id: eventBlocker
        anchors.fill: parent
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        property real dragThreshold: 5 // 判断是否真的拖动的最小距离
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            dragged = false;
        }
        onPositionChanged: mouse => {
            // 判断是否拖动超过阈值
            if (!dragged && (Math.abs(mouse.x - pressX) > dragThreshold || Math.abs(mouse.y - pressY) > dragThreshold)) {
                dragged = true;
                if (root.visibility === Window.Maximized) {
                    root.showNormal();
                    leftrect.radius = 20;
                    rightrect.radius = 20;
                    bottomrect.radius = 20;
                }
                root.startSystemMove();
            }
        }
        onReleased: mouse => {
            if (!dragged) {
                // 没有拖动就是点击
            }
        }
    }

    // ======================= 左上角收起按钮 =======================
    Rectangle {
        id: collapseBtn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0.03 * root.height
        anchors.leftMargin: 0.03 * root.width
        width: 32
        height: 32
        radius: 16
        color: collapseHoverHandler.hovered ? "#30FFFFFF" : "transparent"

        Image {
            id: collapseIcon
            anchors.centerIn: parent
            source: "qrc:/image/left_line.png"
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
            rotation: -90
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: collapseIcon
                color: "#FFFFFF"
            }
        }

        HoverHandler {
            id: collapseHoverHandler
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                root.lyricsOpened = !root.lyricsOpened;
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // ======================= 右上角窗口控制按钮 =======================
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0.03 * root.height
        anchors.rightMargin: 0.03 * root.width
        spacing: 8

        // 最小化按钮
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: minHoverHandler.hovered ? "#30FFFFFF" : "transparent"

            Image {
                id: minIcon
                anchors.centerIn: parent
                source: "qrc:/image/minus_line.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: minIcon
                    color: "#FFFFFF"
                }
            }

            HoverHandler {
                id: minHoverHandler
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: root.showMinimized()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 最大化按钮
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: maxHoverHandler.hovered ? "#30FFFFFF" : "transparent"

            Image {
                id: maxIcon
                anchors.centerIn: parent
                source: root.visibility === Window.Maximized ? "qrc:/image/fullscreen-exit_line.png" : "qrc:/image/fullscreen_line.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: maxIcon
                    color: "#FFFFFF"
                }
            }

            HoverHandler {
                id: maxHoverHandler
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: {
                    if (root.visibility === Window.Maximized) {
                        root.showNormal();
                        leftrect.radius = 20;
                        rightrect.radius = 20;
                        bottomrect.radius = 20;
                    } else {
                        root.showMaximized();
                        leftrect.radius = 0;
                        rightrect.radius = 0;
                        bottomrect.radius = 0;
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 关闭按钮
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: closeHoverHandler.hovered ? "#FF5252" : "transparent"

            Image {
                id: closeIcon
                anchors.centerIn: parent
                source: "qrc:/image/close-circle_line.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: closeIcon
                    color: "#FFFFFF"
                }
            }

            HoverHandler {
                id: closeHoverHandler
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: root.close()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }

    // ======================= 顶部 ===========================
    Row {
        id: topBar
        spacing: 16
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 24

        Text {
            text: "歌曲"
            font.pixelSize: 20
            color: "white"
        }
        Text {
            text: "·"
            font.pixelSize: 20
            color: "#AAAAAA"
        }
        Text {
            text: "评论"
            font.pixelSize: 20
            color: "#666666"
        }
        Text {
            text: "·"
            font.pixelSize: 20
            color: "#AAAAAA"
        }
        Text {
            text: "相关"
            font.pixelSize: 20
            color: "#666666"
        }
    }

    // ================== 左侧唱片区 ==========================
    Column {
        id: leftAlbumSection
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.08
        anchors.top: parent.top
        anchors.topMargin: 0.12 * lyricspage.height

        spacing: 8
        width: parent.width * 0.3

        Text {
            text: songName
            font.pixelSize: 20
            font.bold: true
            color: "white"
            font.family: "黑体"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: singerName
            font.pixelSize: 16
            color: "#DDDDDD"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Item {
            height: 20
            width: 1
        }

        // 专辑图片容器（带发光效果）
        Item {
            id: albumContainer
            width: 340
            height: 340
            anchors.horizontalCenter: parent.horizontalCenter

            // 发光层 - 第6层（最外层）
            Rectangle {
                id: glowLayer6
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.06)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 500
                height: 500
                source: glowLayer6
                radius: 80
                transparentBorder: true
            }

            // 发光层 - 第5层
            Rectangle {
                id: glowLayer5
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.10)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 455
                height: 455
                source: glowLayer5
                radius: 62
                transparentBorder: true
            }

            // 发光层 - 第4层
            Rectangle {
                id: glowLayer4
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.15)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 415
                height: 415
                source: glowLayer4
                radius: 48
                transparentBorder: true
            }

            // 发光层 - 第3层
            Rectangle {
                id: glowLayer3
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.22)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 385
                height: 385
                source: glowLayer3
                radius: 35
                transparentBorder: true
            }

            // 发光层 - 第2层
            Rectangle {
                id: glowLayer2
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.32)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 360
                height: 360
                source: glowLayer2
                radius: 24
                transparentBorder: true
            }

            // 发光层 - 第1层（最内层）
            Rectangle {
                id: glowLayer1
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                color: Qt.rgba(parseInt(dominantColor.substring(1, 3), 16) / 255, parseInt(dominantColor.substring(3, 5), 16) / 255, parseInt(dominantColor.substring(5, 7), 16) / 255, 0.45)
                visible: false
            }
            FastBlur {
                anchors.centerIn: parent
                width: 345
                height: 345
                source: glowLayer1
                radius: 14
                transparentBorder: true
            }

            // 专辑图片
            Rectangle {
                anchors.centerIn: parent
                width: 340
                height: 340
                radius: width / 2
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    property real currentRotation: 0
                    source: albumCover
                    rotation: currentRotation
                    asynchronous: true
                    cache: true
                    mipmap: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 340
                            height: 340
                            radius: width / 2
                        }
                    }
                    NumberAnimation on currentRotation {
                        id: rotationAnim
                        from: 0
                        to: 360
                        duration: 15000
                        loops: Animation.Infinite
                        running: !playlistmanager.isPaused && root.visible
                    }
                    Connections {
                        target: playlistmanager
                        function onIsPausedChanged() {
                            if (!playlistmanager.isPaused && root.visible) {
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
                            if (!playlistmanager.isPaused && root.visible) {
                                rotationAnim.from = avatarImage.currentRotation % 360;
                                rotationAnim.to = rotationAnim.from + 360;
                                rotationAnim.start();
                            } else {
                                rotationAnim.stop();
                            }
                        }
                    }
                }
            }
        }

        Item {
            height: 16
            width: 1
        }

        Row {
            spacing: 40
            anchors.horizontalCenter: parent.horizontalCenter

            // 收藏按钮
            Rectangle {
                id: favoriteBtn
                width: 40
                height: 40
                radius: 20
                color: favoriteMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

                Image {
                    id: favoriteIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/shoucang.png"
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: favoriteIcon
                        color: favoriteMouseArea.containsMouse ? "#FF6B6B" : "#FFFFFF"
                    }
                }

                MouseArea {
                    id: favoriteMouseArea
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

            // 下载按钮
            Rectangle {
                id: downloadBtn
                width: 40
                height: 40
                radius: 20
                color: downloadMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

                Image {
                    id: downloadIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/xiazai.png"
                    width: 22
                    height: 22
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: downloadIcon
                        color: downloadMouseArea.containsMouse ? "#4FC3F7" : "#FFFFFF"
                    }
                }

                MouseArea {
                    id: downloadMouseArea
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

    // ================== 右侧歌词区 ==========================
    ListView {
        id: lyricList
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: parent.width * 0.15
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0.2 * root.height
        anchors.topMargin: 160
        clip: true
        width: parent.width * 0.3
        cacheBuffer: 150

        model: playlistmanager ? playlistmanager.m_lyrics : 0
        interactive: false   //是否可以手动滚动
        spacing: 8

        currentIndex: playlistmanager ? playlistmanager.lyricsindex : -1

        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: lyricList.height * 0.4
        preferredHighlightEnd: lyricList.height * 0.6

        // 滚动动画配置
        highlightMoveDuration: 400      // 动画持续时间（毫秒），值越大越慢
        highlightMoveVelocity: -1       // -1 表示使用 duration 控制；设置正值则按速度控制

        delegate: Item {
            width: lyricList.width
            height: lineText.contentHeight + 8

            property bool isCurrentLine: ListView.isCurrentItem
            property bool isPastLine: index < lyricList.currentIndex && lyricList.currentIndex >= 0
            property int charIdx: playlistmanager ? playlistmanager.lyricCharIndex : -1
            property real charProgress: playlistmanager ? playlistmanager.lyricCharProgress : 0.0

            // 歌词文本容器
            Item {
                anchors.centerIn: parent
                width: lineText.width
                height: lineText.height

                // 底层：完整灰色歌词
                Text {
                    id: lineText
                    anchors.centerIn: parent
                    text: modelData.text || ""
                    textFormat: Text.PlainText
                    font.pixelSize: isCurrentLine ? 20 : 16
                    font.bold: isCurrentLine
                    font.family: "黑体"
                    color: "#dddddd"
                    opacity: isCurrentLine ? 1.0 : 0.7
                }

                // 高亮层：带裁剪的渐变高亮（从左到右）
                Item {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: highlightText.width * highlightRatio
                    height: parent.height
                    clip: true
                    visible: isCurrentLine && charIdx >= 0

                    property real highlightRatio: {
                        if (!isCurrentLine || charIdx < 0)
                            return 0;
                        // 计算已高亮字符比例 + 当前字符的部分进度
                        var totalChars = (modelData.text || "").length;
                        if (totalChars === 0)
                            return 0;
                        return (charIdx + charProgress) / totalChars;
                    }

                    Text {
                        id: highlightText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text || ""
                        textFormat: Text.PlainText
                        font.pixelSize: isCurrentLine ? 20 : 16
                        font.bold: isCurrentLine
                        font.family: "黑体"
                        color: dominantColor
                    }
                }
            }
        }
    }

    // ================== 底部播放控制区 ==================
    RowLayout {
        id: bottomControlBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.bottomMargin: 50
        height: 50
        spacing: 20

        // ===== 左侧：播放控制按钮 =====
        Row {
            spacing: 25
            Layout.alignment: Qt.AlignVCenter
            height: parent.height

            // 上一曲
            Image {
                id: prevBtn
                source: "qrc:/image/upplay.png"
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
                opacity: prevMouseArea.containsMouse ? 1.0 : 0.7
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: prevBtn
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: prevMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (playlistmanager) {
                            playlistmanager.playPrevious();
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            // 播放/暂停
            Rectangle {
                id: playPauseBtn
                width: 44
                height: 44
                radius: 22
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: playPauseIcon
                    anchors.centerIn: parent
                    source: playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png"
                    width: 20
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playPauseIcon
                        color: "#333333"
                    }
                }

                MouseArea {
                    id: playPauseMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (playlistmanager) {
                            playlistmanager.playstop();
                        }
                    }
                }

                scale: playPauseMouseArea.pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            // 下一曲
            Image {
                id: nextBtn
                source: "qrc:/image/nextplay.png"
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
                opacity: nextMouseArea.containsMouse ? 1.0 : 0.7
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: nextBtn
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: nextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (playlistmanager) {
                            playlistmanager.playNext();
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }

        // ===== 中间：进度条 =====
        Item {
            id: progressArea
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height

            Row {
                anchors.fill: parent
                spacing: 12

                // 当前时间
                Text {
                    id: currentTimeText
                    text: playlistmanager ? playlistmanager.percentstr : "00:00"
                    font.pixelSize: 13
                    color: "#AAAAAA"
                    font.family: "黑体"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 进度条
                Rectangle {
                    id: progressBar
                    height: 4
                    radius: 2
                    color: "#3A3A4A"
                    anchors.verticalCenter: parent.verticalCenter
                    Layout.fillWidth: true
                    width: parent.width - currentTimeText.width - totalTimeText.width - 36

                    property real value: playlistmanager ? playlistmanager.percent : 0.0
                    property bool dragging: false

                    // 悬停高亮边框
                    border.width: progressMouseArea.containsMouse ? 1 : 0
                    border.color: "#80FFFFFF"
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    // 已播放部分
                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 2
                        color: "#FFFFFF"
                        width: progressBar.dragging ? tempWidth : parent.width * progressBar.value
                        property real tempWidth: 0
                    }

                    // 滑块
                    Rectangle {
                        id: progressThumb
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressFill.width - width / 2
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
                            progressBar.dragging = true;
                            updateProgress(mouseX);
                        }
                        onPositionChanged: {
                            if (pressed) {
                                updateProgress(mouseX);
                            }
                        }
                        onReleased: {
                            if (progressBar.dragging) {
                                commitProgress();
                                progressBar.dragging = false;
                            }
                        }
                        onClicked: {
                            updateProgress(mouseX);
                            commitProgress();
                        }

                        function updateProgress(mouseX) {
                            var newValue = Math.max(0, Math.min(1, mouseX / progressBar.width));
                            progressFill.tempWidth = progressBar.width * newValue;
                        }

                        function commitProgress() {
                            var newValue = progressFill.tempWidth / progressBar.width;
                            if (playlistmanager) {
                                playlistmanager.setposistion(newValue);
                            }
                        }
                    }
                }

                // 总时长
                Text {
                    id: totalTimeText
                    text: playlistmanager ? playlistmanager.duration : "00:00"
                    font.pixelSize: 13
                    color: "#AAAAAA"
                    font.family: "黑体"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ===== 右侧：功能图标 =====
        Row {
            spacing: 20
            Layout.alignment: Qt.AlignVCenter

            // 倍速
            Text {
                id: speedBtn
                text: "1.0x"
                font.pixelSize: 13
                color: speedMouseArea.containsMouse ? "#FFFFFF" : "#AAAAAA"
                font.family: "黑体"
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    id: speedMouseArea
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

            // 音量
            Image {
                id: volumeBtn
                source: "qrc:/image/shenying.png"
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                opacity: volumeMouseArea.containsMouse ? 1.0 : 0.7
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: volumeBtn
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: volumeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            // 歌词
            Text {
                id: lyricBtn
                text: "词"
                font.pixelSize: 14
                font.bold: true
                color: lyricMouseArea.containsMouse ? "#FFFFFF" : "#AAAAAA"
                font.family: "黑体"
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    id: lyricMouseArea
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

            // 播放列表
            Image {
                id: playlistBtn
                source: "qrc:/image/liebiao.png"
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                opacity: playlistMouseArea.containsMouse ? 1.0 : 0.7
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: playlistBtn
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: playlistMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
