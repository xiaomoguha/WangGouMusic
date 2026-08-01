import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Rectangle {
    id: lyricspage
    color: AppTheme.bgContent
    radius: 20

    property string albumCover: playlistmanager ? (playlistmanager.union_cover === "" ? "qrc:/image/touxi.jpg" : playlistmanager.union_cover) : "qrc:/image/touxi.jpg"
    property string songName: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
    property string singerName: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
    property string dominantColor: playlistmanager ? playlistmanager.dominantColor : "#FF6B6B"

    // 安全地把 "#RRGGBB" 转为 rgba：避免 dominantColor 为空 / 非 #RRGGBB 格式时
    // substring + parseInt 产生 NaN，进而让 Qt.rgba 渲染出异常颜色甚至崩溃
    function rgbFromHex(hex, alpha) {
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#")
            return Qt.rgba(1.0, 0.42, 0.42, alpha)
        var r = parseInt(hex.substring(1, 3), 16)
        var g = parseInt(hex.substring(3, 5), 16)
        var b = parseInt(hex.substring(5, 7), 16)
        if (isNaN(r) || isNaN(g) || isNaN(b))
            return Qt.rgba(1.0, 0.42, 0.42, alpha)
        return Qt.rgba(r / 255, g / 255, b / 255, alpha)
    }

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
        radius: 80  // 固定值：避免随窗口 resize 重算；80px 背景模糊足够柔和
        samples: 81  // 略大于 radius 即可（原 120 过高），降低 GPU 采样开销
        transparentBorder: false  // 全屏背景图：边缘钳制、不向透明衰减，避免四边发黑
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
    IconButton {
        id: collapseBtn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0.03 * root.height
        anchors.leftMargin: 0.03 * root.width
        size: 32; iconSize: 16; iconRotation: -90
        iconSource: "qrc:/image/left_line.png"
        iconColor: "#FFFFFF"
        hoverColor: "#30FFFFFF"
        normalColor: "transparent"
        onClicked: root.lyricsOpened = !root.lyricsOpened
    }

    // ======================= 右上角窗口控制按钮 =======================
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0.03 * root.height
        anchors.rightMargin: 0.03 * root.width
        spacing: 8

        // 最小化按钮
        IconButton {
            iconSize: 14
            iconSource: "qrc:/image/minus_line.png"
            iconColor: "#FFFFFF"
            hoverColor: "#30FFFFFF"
            normalColor: "transparent"
            onClicked: root.showMinimized()
        }

        // 最大化按钮
        IconButton {
            iconSize: 14
            iconSource: root.visibility === Window.Maximized ? "qrc:/image/fullscreen-exit_line.png" : "qrc:/image/fullscreen_line.png"
            iconColor: "#FFFFFF"
            hoverColor: "#30FFFFFF"
            normalColor: "transparent"
            onClicked: {
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

        // 关闭按钮
        IconButton {
            iconSize: 14
            iconSource: "qrc:/image/close-circle_line.png"
            iconColor: "#FFFFFF"
            hoverColor: "#FF5252"
            normalColor: "transparent"
            onClicked: root.close()
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
            font.pixelSize: AppTheme.fontSizeHeadline
            font.bold: true
            color: AppTheme.textSongTitle
            font.family: AppTheme.fontFamily
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: singerName
            font.pixelSize: AppTheme.fontSizeTitle
            font.bold: true
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
                color: rgbFromHex(dominantColor,0.06)
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
                color: rgbFromHex(dominantColor,0.10)
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
                color: rgbFromHex(dominantColor,0.15)
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
                color: rgbFromHex(dominantColor,0.22)
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
                color: rgbFromHex(dominantColor,0.32)
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
                color: rgbFromHex(dominantColor,0.45)
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
                    sourceSize: Qt.size(720, 720)
                    // Rectangle.clip 不裁圆角，圆形封面需 OpacityMask。
                    // 静态单实例（非 delegate），离屏 FBO 开销可接受。
                    layer.enabled: true
                    layer.textureSize: Qt.size(720, 720)
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
                        duration: 30000
                        loops: Animation.Infinite
                        running: true  // 创建即转，保证一定旋转；下面用 pause/resume 控制启停
                    }
                    // pause/resume（而非 stop/start）：保留当前角度，恢复时不跳变（不闪角）；
                    // 暂停/隐藏/最小化时暂停，避免持续渲染拉高 CPU。
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
                    Component.onCompleted: avatarImage.updateRotation()
                    Connections {
                        target: playlistmanager
                        function onIsPausedChanged() { avatarImage.updateRotation(); }
                    }
                    Connections {
                        target: root
                        function onVisibleChanged() { avatarImage.updateRotation(); }
                        function onVisibilityChanged() { avatarImage.updateRotation(); }
                    }
                }
            }
        }

        Item {
            height: 16
            width: 1
        }
    }

    // ================== 右侧歌词区 ==========================
    ListView {
        id: lyricList
        anchors.left: leftAlbumSection.right
        anchors.leftMargin: parent.width * 0.13
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0.2 * root.height
        anchors.topMargin: 80
        clip: true
        width: parent.width * 0.32
        cacheBuffer: 1500

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
            id: lyricLine
            width: lyricList.width
            height: isCurrentLine ? 52 : (lineText.contentHeight + 8)

            property bool isCurrentLine: ListView.isCurrentItem
            property bool isPastLine: index < lyricList.currentIndex && lyricList.currentIndex >= 0
            property int charIdx: playlistmanager ? playlistmanager.lyricCharIndex : -1
            property real charProgress: playlistmanager ? playlistmanager.lyricCharProgress : 0.0

            // 歌词文本容器
            Item {
                anchors.centerIn: parent
                width: isCurrentLine ? currentLineWrap.width : lineText.width
                height: isCurrentLine ? currentLineWrap.height : lineText.height

                // 非当前行：单行灰色文本
                Text {
                    id: lineText
                    anchors.centerIn: parent
                    visible: !isCurrentLine
                    text: modelData.text || ""
                    textFormat: Text.PlainText
                    font.pixelSize: AppTheme.fontSizeTitle
                    font.family: AppTheme.fontFamily
                    color: "#dddddd"
                    opacity: 0.7
                }

                // 当前行：酷狗跳跃歌词 —— 整行亮（未唱亮白），
                // 五角星从上方跟进度横向滚过：星压到的当前字被压扁+染已播放色（主色调），
                // 星滚过后该字 spring 回弹到原大小，颜色保留为主色调。
                Item {
                    id: currentLineWrap
                    anchors.centerIn: parent
                    visible: isCurrentLine
                    // 成为当前行时弹性放大入场，替代瞬间放大
                    scale: isCurrentLine ? 1.0 : 0.85
                    Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.45 } }
                    width: currentLineRow.width
                    height: currentLineRow.height
                    // 单元数（中文=字数、英文=词数），与 charIdx 一致
                    property int totalChars: playlistmanager ? playlistmanager.lyricCharCount : 0
                    // 星星实际像素位置（相对本行左端）：由当前字 delegate 的 Binding 写入，
                    // = 当前字在 Row 里的 x + 字内进度×字宽。按真实字符宽度跟随，
                    // 空格/标点等窄字符处不会按字符数比例"闪过"。
                    property real starX: 0
                    // 非当前行时把星星位置重置回行首(0)，避免下次成为当前行时星星从上一行
                    // 残留的行末位置 spring"滚回"左边
                    onVisibleChanged: if (!visible) starX = 0

                    Row {
                        id: currentLineRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: playlistmanager ? playlistmanager.lyricChars : []
                            delegate: Item {
                                required property int index
                                required property var modelData
                                width: baseChar.width
                                height: baseChar.height
                                // 字内染色比例：已唱字全染、当前字按 charProgress 从左向右刷过去、未唱字不染
                                property real fillRatio: index < charIdx ? 1.0
                                    : (index === charIdx ? charProgress : 0.0)
                                // 唱到字瞬间压到最扁 0.5，前段(0->a) ease-out 慢回弹到 1.0，之后保持等下一字
                                property real squeeze: {
                                    if (!lyricsConfig || !lyricsConfig.jumpEnabled) return 1.0
                                    if (index !== charIdx || charIdx < 0) return 1.0
                                    var p = charProgress
                                    var a = 0.65
                                    if (p < a) {
                                        var t = p / a
                                        return 0.5 + (1.0 - 0.5) * (1 - (1 - t) * (1 - t))
                                    }
                                    return 1.0
                                }
                                transform: Scale { origin.x: 0; origin.y: height; yScale: squeeze }

                                // 隐藏测量字：提供本字宽高供两个裁剪层定位（modelData 为 LyricChar，text 可能是中文字或英文词）
                                Text {
                                    id: baseChar
                                    visible: false
                                    text: modelData.text
                                    font.pixelSize: AppTheme.fontSizeHeadline
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                }
                                // 已唱色（左半，按 fillRatio 裁剪）
                                Item {
                                    width: baseChar.width * fillRatio
                                    height: baseChar.height
                                    clip: true
                                    Text {
                                        text: modelData.text
                                        font.pixelSize: AppTheme.fontSizeHeadline
                                        font.bold: true
                                        font.family: AppTheme.fontFamily
                                        color: dominantColor
                                    }
                                }
                                // 未唱白（右半，互补裁剪）：与已唱色不重叠，既无叠加透白、又不加描边，字形不发糊
                                Item {
                                    x: baseChar.width * fillRatio
                                    width: baseChar.width * (1 - fillRatio)
                                    height: baseChar.height
                                    clip: true
                                    Text {
                                        x: -baseChar.width * fillRatio
                                        text: modelData.text
                                        font.pixelSize: AppTheme.fontSizeHeadline
                                        font.bold: true
                                        font.family: AppTheme.fontFamily
                                        color: "#ffffff"
                                    }
                                }

                                // 当前字把实际像素位置写回给星星游标（按真实字符宽度跟随）
                                Binding {
                                    target: currentLineWrap
                                    property: "starX"
                                    value: x + charProgress * width
                                    when: isCurrentLine && index === charIdx && charIdx >= 0
                                }
                            }
                        }
                    }

                    // 五角星游标：跟在当前字上方，横向滚过当前行
                    Item {
                        id: starCursor
                        visible: isCurrentLine && charIdx >= 0 && lyricsConfig && lyricsConfig.jumpEnabled
                        width: 16; height: 16
                        // 唱到字下沉压字顶(1)->前段(0->a)减速上抛到最高(0,慢)->后段(a->1)重力加速下落(1,快)
                        // 例外：最后一字末段不下落，保持高位往上淡出
                        property real starBob: {
                            if (charIdx < 0) return 0
                            var p = charProgress
                            var a = 0.65
                            if (p < a) {
                                var t = p / a
                                return (1 - t) * (1 - t)
                            }
                            if (charIdx >= currentLineWrap.totalChars - 1) return 0
                            var t = (p - a) / (1 - a)
                            return t * t
                        }
                        x: currentLineWrap.starX - width / 2
                        y: -21
                        // 行首/行末淡入淡出按"首/末字的字内进度 charProgress"判断，而非像素比例：
                        // 否则最后一字处于行末、starRatio 一上来就 >0.9，星刚到最后一字就淡出看不见。
                        // 改成第一字前 15% 淡入、最后一字滚到 85% 后才淡出，中间每一字（含最后）都能被星完整压到。
                        opacity: {
                            if (charIdx < 0) return 0
                            if (charIdx === 0 && charProgress < 0.15)
                                return charProgress / 0.15
                            if (charIdx >= currentLineWrap.totalChars - 1 && charProgress > 0.95)
                                return Math.max(0, (1 - charProgress) / 0.05)
                            return 1
                        }
                        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }

                        // 拖尾：从主星位置随机喷出的小星粒子，各自随机轨迹飘散+淡出；未播放时不动
                        Repeater {
                            model: 4
                            delegate: Canvas {
                                id: trailStar
                                required property int index
                                property real life: 0
                                // 每粒子随机初速/大小：vx 向左、vy 向上，加重力成抛物线轨迹
                                property real vx: -(0.5 + Math.random() * 0.4)
                                property real vy: -0.1 + Math.random() * 0.3
                                width: starCursor.width * (0.35 + Math.random() * 0.15)
                                height: width
                                x: starCursor.width * -0.2 + vx * life * 70 - width / 2
                                y: starCursor.height * 0.9 + vy * life * 60
                                   + 0.2 * (life * 10) * (life * 10) - height / 2
                                opacity: Math.max(0, 1 - life) * 0.8 * starCursor.opacity
                                SequentialAnimation on life {
                                    running: starCursor.visible && playlistmanager && !playlistmanager.isPaused
                                    PauseAnimation { duration: index * 500 }
                                    NumberAnimation { from: 0; to: 1; duration: 2000; loops: Animation.Infinite }
                                }
                                Connections {
                                    target: AppTheme
                                    function onAccentChanged() { trailStar.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.fillStyle = AppTheme.accent
                                    ctx.beginPath()
                                    var cx = width / 2, cy = height / 2
                                    var R = Math.min(width, height) / 2
                                    var r = R * 0.5
                                    for (var k = 0; k < 5; k++) {
                                        var oA = -Math.PI / 2 + k * 2 * Math.PI / 5
                                        var iA = oA + Math.PI / 5
                                        if (k === 0) ctx.moveTo(cx + R * Math.cos(oA), cy + R * Math.sin(oA))
                                        else ctx.lineTo(cx + R * Math.cos(oA), cy + R * Math.sin(oA))
                                        ctx.lineTo(cx + r * Math.cos(iA), cy + r * Math.sin(iA))
                                    }
                                    ctx.closePath()
                                    ctx.fill()
                                }
                            }
                        }

                        Canvas {
                            id: starCanvas
                            width: parent.width
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: starCursor.starBob * 16
                            // 自转跟随实际像素位置（滚动模型），与位移完全同步
                            // 一字转一个角(72°)，跟随字进度
                            rotation: (lyricLine.charIdx + lyricLine.charProgress) * 72
                            // 主题色变化时重绘（Canvas 不会自动跟随属性重绘）
                            Connections {
                                target: AppTheme
                                function onAccentChanged() { starCanvas.requestPaint() }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = AppTheme.accent
                                ctx.beginPath()
                                var cx = width / 2, cy = height / 2
                                var R = Math.min(width, height) / 2
                                var r = R * 0.5
                                for (var i = 0; i < 5; i++) {
                                    var oA = -Math.PI / 2 + i * 2 * Math.PI / 5
                                    var iA = oA + Math.PI / 5
                                    if (i === 0) ctx.moveTo(cx + R * Math.cos(oA), cy + R * Math.sin(oA))
                                    else ctx.lineTo(cx + R * Math.cos(oA), cy + R * Math.sin(oA))
                                    ctx.lineTo(cx + r * Math.cos(iA), cy + r * Math.sin(iA))
                                }
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }
                }
            }
        }
    }

    // 缓冲提示（覆盖在歌词区上方）
    Rectangle {
        anchors.fill: lyricList
        color: "#8013131a"
        visible: playlistmanager && playlistmanager.isBuffering
        radius: 12

        Column {
            anchors.centerIn: parent
            spacing: 12

            // 旋转加载圈
            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.width: 3
                border.color: "#30FFFFFF"

                Rectangle {
                    width: 10
                    height: 3
                    radius: 1.5
                    color: "#FFFFFF"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -1
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: parent.parent.parent.visible
                }
            }

            Text {
                text: "正在缓冲..."
                font.pixelSize: AppTheme.fontSizeTitle
                color: "#CCCCCC"
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200 } }
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
                        duration: AppTheme.animFast
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
                        duration: AppTheme.animFast
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

                Text {
                    id: currentTimeText
                    text: playlistmanager ? playlistmanager.percentstr : "00:00"
                    font.pixelSize: AppTheme.fontSizeBody
                    color: "#AAAAAA"
                    font.family: AppTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 进度条
                Rectangle {
                    id: progressBar
                    height: 2
                    radius: 2
                    color: "#3A3A4A"
                    anchors.verticalCenter: parent.verticalCenter
                    Layout.fillWidth: true
                    width: parent.width - currentTimeText.width - totalTimeText.width - 36

                    property real value: playlistmanager ? playlistmanager.percent : 0.0
                    property real dlProgress: playlistmanager ? playlistmanager.downloadProgress : 1.0
                    property bool dragging: false

                    border.width: 0

                    // 已下载部分（中间色）
                    Rectangle {
                        id: downloadFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 2
                        color: "#5A5A6A"
                        width: parent.width * progressBar.dlProgress
                        visible: progressBar.dlProgress < 1.0
                    }

                    // 已播放部分
                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 2
                        color: dominantColor
                        width: progressBar.dragging ? tempWidth : parent.width * progressBar.value
                        property real tempWidth: 0
                    }

                    // 滑块
                    Rectangle {
                        id: progressThumb
                        width: 12
                        height: 12
                        radius: 6
                        color: dominantColor
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
                    font.pixelSize: AppTheme.fontSizeBody
                    color: "#AAAAAA"
                    font.family: AppTheme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

    }
}
