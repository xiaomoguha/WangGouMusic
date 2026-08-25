import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Rectangle {
    id: lyricspage
    color: AppTheme.bgContent
    radius: 20

    property string albumCover: playlistmanager ? (playlistmanager.union_cover === "" ? "qrc:/image/touxi.jpg" : playlistmanager.union_cover) : "qrc:/image/touxi.jpg"
    property string songName: playlistmanager ? (playlistmanager.currentTitle === "" ? "默认歌曲" : playlistmanager.currentTitle) : "........"
    property string singerName: playlistmanager ? (playlistmanager.currentsingername === "" ? "默认歌手" : playlistmanager.currentsingername) : "....."
    property string dominantColor: playlistmanager ? playlistmanager.dominantColor : "#FF6B6B"

    // ── 逐字歌词进度（可见性隔离）──
    // 本页由 main.qml 的 lyricsPageLoader 加载（active 常驻、y 滑动切换）：
    // 收起/最小化时 Connections 关闭 → proxy 不变 → 逐字绑定零重算。
    // 注意不能用 parent.opacity 判断——该 Loader 的 opacity 恒为 1
    property bool _lyricsVisible: root.lyricsOpened && root.appActive
    property int lyricCharIdxProxy: -1
    property real lyricCharProgressProxy: 0.0
    property int lyricCharCountProxy: 0

    Connections {
        target: playlistmanager
        enabled: lyricspage._lyricsVisible
        function onCurrlyricChanged() { syncLyricValues() }
    }
    function syncLyricValues() {
        if (!playlistmanager) return
        lyricCharIdxProxy       = playlistmanager.lyricCharIndex
        lyricCharProgressProxy  = playlistmanager.lyricCharProgress
        lyricCharCountProxy     = playlistmanager.lyricCharCount
    }
    on_LyricsVisibleChanged: {
        // 向 C++ 上报本页是否为歌词动画消费方：展开 60Hz / 收起停用（桌面歌词另计）
        if (playlistmanager)
            playlistmanager.setPlayingPageLyricsActive(_lyricsVisible)
        if (_lyricsVisible) {
            syncLyricValues()  // 切回播放页时立即同步（隐藏期间值已陈旧）
            // 进入页面立即无动画居中当前行：页面隐藏期间的行切换视图未必跟随，
            // 不主动定位要等下一次切行才归位
            if (lyricList.count > 0 && lyricList.currentIndex >= 0)
                lyricList.positionViewAtIndex(lyricList.currentIndex, ListView.Center)
        }
    }

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

    // 全页拖动窗口（评论列表/歌词在上层自行滚动，未消费的拖动落到这里）
    MouseArea {
        id: eventBlocker
        anchors.fill: parent
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        property real dragThreshold: 5
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            dragged = false;
        }
        onPositionChanged: mouse => {
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

    // ── 评论页状态 ──
    property bool showComments: false
    property string commentsLoadedHash: ""

    // 五角星共享纹理：母版 Canvas 只画一次导出 dataURL，主星 + 4 颗拖尾 Image
    // 共用同一 source（QQuickPixmap 缓存复用单张纹理）——替代原先 5 个独立
    // Canvas（各占一个离屏 FBO + Context2D 光栅机制），动画只驱动便宜的变换
    property string starTexture: ""
    Canvas {
        id: starSourceCanvas
        width: 64; height: 64
        visible: false
        Component.onCompleted: requestPaint()
        Connections {
            target: AppTheme
            function onAccentChanged() { starSourceCanvas.requestPaint() }
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
            lyricspage.starTexture = toDataURL("image/png")
        }
    }
    function ensureComments() {
        if (!playlistmanager || !songComments) return
        var hash = playlistmanager.currentSonghash
        if (hash === "") return
        if (lyricspage.commentsLoadedHash !== hash) {
            // fetchComments 返回 false = 有请求在途，不标记已加载，等下一轮重试
            if (songComments.fetchComments(songName, hash))
                lyricspage.commentsLoadedHash = hash
        } else if (songComments.comments.length === 0 && !songComments.isLoading) {
            songComments.fetchComments(songName, hash)
        }
    }

    // 切歌后后台预拉评论列表：tab 上的评论数（取列表响应 count）不用点击即可显示
    Connections {
        target: playlistmanager
        function onCurrentSongChanged() {
            lyricspage.ensureComments()
        }
    }

    // 页面加载时预拉当前歌曲评论（打开播放页立即显示评论数）
    Component.onCompleted: {
        lyricspage.ensureComments()
        if (playlistmanager)
            playlistmanager.setPlayingPageLyricsActive(_lyricsVisible)
    }

    // ======================= 左上角收起按钮 =======================
    IconButton {
        id: collapseBtn
        z: 200
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Qt.platform.os === "osx" ? 52 : 0.03 * root.height
        anchors.leftMargin: Qt.platform.os === "osx" ? 22 : 0.03 * root.width
        size: 32; iconSize: 16; iconRotation: -90
        iconSource: AppIcon.back
        iconColor: "#FFFFFF"
        hoverColor: "#30FFFFFF"
        normalColor: "transparent"
        onClicked: root.lyricsOpened = !root.lyricsOpened
    }

    // ======================= 右上角窗口控制按钮 =======================
    Row {
        z: 200
        visible: Qt.platform.os !== "osx"   // mac 用原生 traffic lights
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 0.03 * root.height
        anchors.rightMargin: 0.03 * root.width
        spacing: 8

        // 最小化按钮
        IconButton {
            iconSize: 14
            iconSource: AppIcon.minimize
            iconColor: "#FFFFFF"
            hoverColor: "#30FFFFFF"
            normalColor: "transparent"
            onClicked: root.showMinimized()
        }

        // 最大化按钮
        IconButton {
            iconSize: 14
            iconSource: root.visibility === Window.Maximized ? AppIcon.restore : AppIcon.maximize
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
            iconSource: AppIcon.close
            iconColor: "#FFFFFF"
            hoverColor: "#FF5252"
            normalColor: "transparent"
            onClicked: root.close()
        }
    }

    // ================== 右侧区：歌词 | 评论（二选一显示） ==================
    Item {
        id: lyricsPageView
        width: parent.width
        height: parent.height

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

        // 专辑图片容器
        Item {
            id: albumContainer
            width: 340
            height: 340
            anchors.horizontalCenter: parent.horizontalCenter

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
                                       && root.lyricsOpened && root.appActive;
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
                        function onLyricsOpenedChanged() { avatarImage.updateRotation(); }
                        function onAppActiveChanged() { avatarImage.updateRotation(); }
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

    // 歌词 / 评论 切换 tab（点击平滑滑页，水平居中于歌词/评论区）
    Row {
        id: panelTabs
        anchors.horizontalCenter: panelHost.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 40
        spacing: 10

        Rectangle {
            width: 60
            height: 30
            radius: 15
            color: !lyricspage.showComments ? "#FFFFFF" : "transparent"
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "歌词"
                color: !lyricspage.showComments ? "#222222" : "#AAFFFFFF"
                font.bold: true
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: lyricspage.showComments = false }
        }

        Rectangle {
            width: commentTabLabel.implicitWidth + 34
            height: 30
            radius: 15
            color: lyricspage.showComments ? "#FFFFFF" : "transparent"
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

            Text {
                id: commentTabLabel
                anchors.centerIn: parent
                text: "评论" + (songComments && songComments.totalCount > 0 ? " " + songComments.totalCount : "")
                color: lyricspage.showComments ? "#222222" : "#AAFFFFFF"
                font.bold: true
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    lyricspage.showComments = true
                    lyricspage.ensureComments()
                }
            }
        }
    }

    // 歌词/评论滑动切换容器（两页各占半宽，x 平移切换）
    Item {
        id: panelHost
        anchors.left: leftAlbumSection.right
        anchors.leftMargin: parent.width * 0.13
        anchors.top: parent.top
        anchors.topMargin: 80
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0.2 * root.height
        width: parent.width * 0.32
        clip: true

        Item {
            id: panelContent
            width: panelHost.width * 2
            height: panelHost.height
            x: lyricspage.showComments ? -panelHost.width : 0
            Behavior on x {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

    ListView {
        id: lyricList
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: panelHost.width
        clip: true
        cacheBuffer: 600

        model: playlistmanager ? playlistmanager.m_lyrics : 0
        interactive: false   //是否可以手动滚动
        spacing: 8

        currentIndex: playlistmanager ? playlistmanager.lyricsindex : -1

        highlightFollowsCurrentItem: true
        // StrictlyEnforceRange：任何时刻（含首次创建的初始布局）强制当前行落在中间带。
        // ApplyRange 不在初始布局时归位，是"一进页面当前行不在中间"的根因；
        // interactive=false 下也用不到 ApplyRange 的自由滚动
        highlightRangeMode: ListView.StrictlyEnforceRange
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
            // 由页面根 proxy 驱动（可见性隔离：页面隐藏时零重算）
            property int charIdx: lyricspage.lyricCharIdxProxy
            property real charProgress: lyricspage.lyricCharProgressProxy

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
                    property int totalChars: lyricspage.lyricCharCountProxy
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
                            // 仅当前行实例化字符行：cacheBuffer 内每行 delegate 都常驻，
                            // 若无条件建模，25+ 行 × 每行一份字符 Repeater = 2000+ item，
                            // 且全部随 16ms 逐字进度重算绑定。非当前行建空模型，实例数降一个量级
                            model: isCurrentLine && playlistmanager ? playlistmanager.lyricChars : []
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
                                    if (p <= 0) return 1.0  // 进度为0=还没唱到(前奏/行首留白/暂停冻结)：不压扁
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
                        // 共享 lyricspage.starTexture 纹理（原先每粒子独立 Canvas 离屏 FBO）
                        Repeater {
                            model: 4
                            delegate: Image {
                                id: trailStar
                                required property int index
                                property real life: 0
                                // 每粒子随机初速/大小：vx 向左、vy 向上，加重力成抛物线轨迹
                                property real vx: -(0.5 + Math.random() * 0.4)
                                property real vy: -0.1 + Math.random() * 0.3
                                width: starCursor.width * (0.35 + Math.random() * 0.15)
                                height: width
                                source: lyricspage.starTexture
                                fillMode: Image.PreserveAspectFit
                                x: starCursor.width * -0.2 + vx * life * 70 - width / 2
                                y: starCursor.height * 0.9 + vy * life * 60
                                   + 0.2 * (life * 10) * (life * 10) - height / 2
                                opacity: Math.max(0, 1 - life) * 0.8 * starCursor.opacity
                                SequentialAnimation on life {
                                    running: starCursor.visible && lyricspage._lyricsVisible
                                             && playlistmanager && !playlistmanager.isPaused
                                    PauseAnimation { duration: index * 500 }
                                    NumberAnimation { from: 0; to: 1; duration: 2000; loops: Animation.Infinite }
                                }
                            }
                        }

                        Image {
                            id: starImage
                            width: parent.width
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: starCursor.starBob * 16
                            // 自转跟随实际像素位置（滚动模型），与位移完全同步
                            // 一字转一个角(72°)，跟随字进度
                            rotation: (lyricLine.charIdx + lyricLine.charProgress) * 72
                            source: lyricspage.starTexture
                            fillMode: Image.PreserveAspectFit
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


        // 评论列表（右半页）：首次切到评论页才实例化（active 一旦为 true 不再回 false），
        // 之后常驻复用，避免只看歌词时几十条评论 delegate 空占内存/绑定
        Loader {
            id: commentLoader
            x: panelHost.width
            width: panelHost.width
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            active: lyricspage.showComments || item !== null

            ListView {
                id: commentList
                anchors.fill: parent
                clip: true
                model: songComments ? songComments.comments : []
                spacing: 18
                cacheBuffer: 600

        ScrollBar.vertical: ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 1
            width: 8
            policy: ScrollBar.AlwaysOn
            contentItem: Rectangle {
                width: 8
                radius: 4
                color: parent.pressed ? "#99FFFFFF" : "#66FFFFFF"
            }
        }

        // 滚动到底加载下一页
        onContentYChanged: {
            if (songComments && !songComments.isLoading && songComments.hasMore
                && contentHeight > height && contentY >= contentHeight - height - 300) {
                songComments.fetchMore()
            }
        }

        header: Item {
            width: commentList.width - 14
            height: 40
            Text {
                anchors.centerIn: parent
                text: songComments ? "共 " + songComments.totalCount + " 条评论" : ""
                color: "#99FFFFFF"
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }

        delegate: Item {
            id: commentDelegate
            width: commentList.width - 14
            height: delegateColumn.height

            // 本评论是否处于展开态（显示回复）
            property bool open: false

            Column {
                id: delegateColumn
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 12

                    // 头像
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        clip: true
                        color: "#33FFFFFF"

                        Image {
                            anchors.fill: parent
                            source: modelData.user_pic
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectCrop
                        }
                        // 无头像时显示昵称首字
                        Text {
                            visible: !modelData.user_pic
                            anchors.centerIn: parent
                            text: modelData.user_name ? modelData.user_name.charAt(0) : "?"
                            color: "#FFFFFF"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: AppTheme.fontFamily
                        }
                    }

                    Column {
                        width: parent.width - 48
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: 10
                            Text {
                                text: modelData.user_name
                                color: "#FFFFFF"
                                font.bold: true
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                            }
                            Text {
                                text: modelData.addtime
                                color: "#66FFFFFF"
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            text: modelData.content
                            color: "#E6FFFFFF"
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            wrapMode: Text.Wrap
                            lineHeight: 1.5
                        }

                        Row {
                            spacing: 16
                            Text {
                                text: "♥ " + modelData.like_count
                                color: "#99FFFFFF"
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                            }
                        }

                        // 展开回复按钮（未展开 >，展开后旋转为 ↓）
                        Rectangle {
                            width: expandRow.implicitWidth + 22
                            height: 26
                            radius: 13
                            color: expandHover.hovered ? "#33FFFFFF" : "#22FFFFFF"
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                            Row {
                                id: expandRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: modelData.reply_num > 0 ? "展开 " + modelData.reply_num + " 条回复" : "暂无回复"
                                    color: "#B3FFFFFF"
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                }
                                Text {
                                    text: "❯"
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1
                                    color: "#99FFFFFF"
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                    rotation: commentDelegate.open ? 90 : 0
                                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }
                            }
                            HoverHandler { id: expandHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    if (modelData.reply_num <= 0) return
                                    commentDelegate.open = !commentDelegate.open
                                    if (commentDelegate.open
                                            && songComments.repliesCommentId !== String(modelData.id)) {
                                        songComments.fetchReplies(modelData.audio_id, String(modelData.id))
                                    }
                                }
                            }
                        }
                    }
                }

                // 回复区块（缩进显示）
                Column {
                    visible: commentDelegate.open
                    width: parent.width - 24
                    anchors.right: parent.right
                    spacing: 10

                    // 加载中
                    Text {
                        visible: songComments && songComments.repliesLoading
                        text: "回复加载中..."
                        color: "#99FFFFFF"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                    }

                    // 该评论没有回复
                    Text {
                        visible: commentDelegate.open && songComments
                                 && !songComments.repliesLoading
                                 && songComments.repliesCommentId === String(modelData.id)
                                 && songComments.replies.length === 0
                        text: "暂无回复"
                        color: "#77FFFFFF"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                    }

                    Repeater {
                        model: (commentDelegate.open && songComments
                                && songComments.repliesCommentId === String(modelData.id))
                               ? songComments.replies : []

                        Row {
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                clip: true
                                color: "#26FFFFFF"

                                Image {
                                    anchors.fill: parent
                                    source: modelData.user_pic
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Text {
                                    visible: !modelData.user_pic
                                    anchors.centerIn: parent
                                    text: modelData.user_name ? modelData.user_name.charAt(0) : "?"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.family: AppTheme.fontFamily
                                }
                            }

                            Column {
                                width: parent.width - 38
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Text {
                                        text: modelData.user_name
                                        color: "#D9FFFFFF"
                                        font.bold: true
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                    }
                                    Text {
                                        text: modelData.addtime
                                        color: "#55FFFFFF"
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "♥ " + modelData.like_count
                                        color: "#77FFFFFF"
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.content
                                    color: "#B3FFFFFF"
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.5
                                }
                            }
                        }
                    }
                }
            }
        }

            // 空状态 / 加载中
            Text {
                visible: songComments && songComments.comments.length === 0
                anchors.centerIn: parent
                text: songComments && songComments.isLoading ? "正在加载评论..." : "暂无评论"
                color: "#99FFFFFF"
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }
        } // commentLoader
        }
    }
    } // ── 歌词页容器结束 ──
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
                source: AppIcon.prev
                sourceSize: Qt.size(128, 128)
                mipmap: true
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
                    source: playlistmanager ? (playlistmanager.isPaused ? AppIcon.play : AppIcon.pause) : AppIcon.play
                    sourceSize: Qt.size(128, 128)
                    mipmap: true
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
                source: AppIcon.next
                sourceSize: Qt.size(128, 128)
                mipmap: true
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

                    // 高潮开始点：小圆点（颜色与已播放进度一致），点击可直接跳到高潮
                    ClimaxDot {
                        color: dominantColor
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
