pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Window {
    id: desktopLyrics
    objectName: "desktopLyrics"

    // 从配置读取属性
    property bool isVertical: lyricsConfig ? lyricsConfig.isVertical : false
    property bool locked: lyricsConfig ? lyricsConfig.locked : false
    property real scale: lyricsConfig ? lyricsConfig.scale : 1.0
    property int fontSize: lyricsConfig ? lyricsConfig.fontSize : 22

    // 已播歌词染色（空=跟随主题 accent），glow 为其 40% 透明同色软发光（以前的效果）
    property color lyricsColor: (lyricsConfig && lyricsConfig.lyricsColor.length > 0) ? lyricsConfig.lyricsColor : AppTheme.accent
    property color lyricsGlow: Qt.rgba(lyricsColor.r, lyricsColor.g, lyricsColor.b, 0.4)
    // 跳跃歌词（星星+拖尾）颜色（空=跟随主题 accent）
    property color starColor: (lyricsConfig && lyricsConfig.starColor.length > 0) ? lyricsConfig.starColor : AppTheme.accent
    // 跳跃歌词开关（关=普通刷过，无压扁无星星）
    property bool jumpEnabled: lyricsConfig ? lyricsConfig.jumpEnabled : true

    // 桌面歌词开关：enabled 变化时同步窗口可见性（初始可见性由 main.cpp 按 enabled 决定）
    Connections {
        target: lyricsConfig
        function onConfigChanged() {
            if (lyricsConfig && visible !== lyricsConfig.enabled)
                visible = lyricsConfig.enabled;
        }
    }

    // 歌词进度同步（可见性隔离）：仅窗口可见时响应 currlyricChanged（60Hz 动画源），
    // 隐藏时 Connections 关闭 → 容器属性不变 → 逐字绑定零重算，主线程不卡
    Connections {
        target: playlistmanager
        enabled: desktopLyrics.visible
        function onCurrlyricChanged() { syncLyricValues() }
    }
    function syncLyricValues() {
        if (!playlistmanager) return
        horizontalLyricContainer.lyricText    = playlistmanager.currlyric || "网狗音乐"
        horizontalLyricContainer.charIndex    = playlistmanager.lyricCharIndex
        horizontalLyricContainer.charProgress = playlistmanager.lyricCharProgress || 0
        verticalTextContainer.lyricText       = playlistmanager.currlyric || "网狗音乐"
        verticalTextContainer.charIndex       = playlistmanager.lyricCharIndex
        verticalTextContainer.charProgress    = playlistmanager.lyricCharProgress || 0
    }
    onVisibleChanged: {
        // 向 C++ 上报本窗口是否为歌词动画消费方（可见 60Hz / 隐藏停用）
        if (playlistmanager)
            playlistmanager.setDesktopLyricsActive(desktopLyrics.visible)
        if (desktopLyrics.visible)
            syncLyricValues()  // 重新可见时立即同步（隐藏期间值已陈旧）
    }

    // 竖排歌词可视区固定高度上限（px）：长歌词不再顶满 80% 屏幕高，超出部分裁剪+滚动
    property int verticalHeightLimit: 350
    // 横排歌词可视区固定宽度上限（px）：长歌词在固定宽度内裁剪+滚动
    property int horizontalWidthLimit: 400

    // 窗口大小 - 保证最小能显示所有控制按钮，歌词居中
    width: desktopLyrics.isVertical ? Math.max(background.width + 70, 44 * desktopLyrics.scale + 16) : Math.max(background.width + 20, controlPanelHorizontal.implicitWidth + 20)
    height: desktopLyrics.isVertical ? Math.max(background.height + 20, controlPanelVertical.implicitHeight + 20) : Math.max(background.height + 72 * desktopLyrics.scale + 12, 28 * desktopLyrics.scale + 16 + 8 * desktopLyrics.scale)  // 横排:上下留白随 scale 放大(容下 28*scale 按钮 + 8*scale margin),否则 scale>100% 时按钮顶部被窗口裁掉一截

    // 歌词内容变化时保持中心位置不变（横向）/ 顶部位置不变（竖向）
    // 使用绝对中心点重新计算 x，避免增量补偿的整数截断累积误差（导致窗口逐渐左漂）
    property bool _suppressCentering: true
    property real _anchorCenterX: 0   // 目标中心 X（浮点，不受 width 取整影响）
    property real _anchorCenterY: 0   // 目标中心 Y
    onWidthChanged: {
        if (!_suppressCentering) {
            x = Math.round(_anchorCenterX - width / 2)
        }
    }
    onHeightChanged: {
        if (!_suppressCentering) {
            y = Math.round(_anchorCenterY - height / 2)
        }
    }

    color: "transparent"

    // 根据锁定状态设置窗口标志
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus

    // 根据配置恢复位置（带边界检查）
    function restorePosition() {
        // 多屏适配：按真实屏幕列表校验（Screen.desktopAvailable* 是整个虚拟桌面的
        // 包围盒，混合分辨率/错位排列时坐标可能在包围盒内却不在任何一块屏上）
        var screens = Qt.application.screens
        console.log("[DesktopLyrics] restorePosition: 屏幕数=" + screens.length
            + " windowSize=" + width + "x" + height
            + " isVertical=" + isVertical);

        if (!screens || screens.length === 0) {
            console.log("[DesktopLyrics] Screen not ready, skipping");
            return;
        }

        var targetX, targetY;
        if (lyricsConfig) {
            if (isVertical) {
                targetX = lyricsConfig.verticalX;
                targetY = lyricsConfig.verticalY;
            } else {
                targetX = lyricsConfig.horizontalX;
                targetY = lyricsConfig.horizontalY;
            }
        }
        console.log("[DesktopLyrics] config pos: " + targetX + "," + targetY);

        // 坐标落得的屏：取窗口中心点所在的屏
        var home = null;
        if (targetX !== undefined && !(targetX === 0 && targetY === 0)) {
            var cx = targetX + width / 2, cy = targetY + height / 2;
            for (var i = 0; i < screens.length; i++) {
                var s = screens[i];
                if (cx >= s.virtualX && cx < s.virtualX + s.width
                    && cy >= s.virtualY && cy < s.virtualY + s.height) {
                    home = s;
                    break;
                }
            }
        }
        // 不在任何屏上（拔了显示器/重排了布局/无有效配置）：用当前屏兜底
        if (!home) {
            home = screen || screens[0];
            targetX = home.virtualX + (home.width - width) / 2;
            targetY = home.virtualY + home.height - height - 50;
            console.log("[DesktopLyrics] 不在任何屏幕范围内，重置到: " + targetX + "," + targetY);
        }
        // 默认位置（首次使用，home 已定）
        else if (targetX === undefined || (targetX === 0 && targetY === 0)) {
            if (isVertical) {
                targetX = home.virtualX + home.width - width - 20;
                targetY = home.virtualY + (home.height - height) / 2;
            } else {
                targetX = home.virtualX + (home.width - width) / 2;
                targetY = home.virtualY + home.height - height - 50;
            }
            console.log("[DesktopLyrics] using default pos: " + targetX + "," + targetY);
        }
        x = targetX;
        y = targetY;
        _anchorCenterX = targetX + width / 2
        _anchorCenterY = targetY + height / 2
        console.log("[DesktopLyrics] final pos: " + x + "," + y);
    }

    // 启用居中补偿（延迟到布局稳定后）
    function enableCentering() {
        _anchorCenterX = x + width / 2
        _anchorCenterY = y + height / 2
        _suppressCentering = false;
    }

    Component.onCompleted: {
        if (playlistmanager)
            playlistmanager.setDesktopLyricsActive(desktopLyrics.visible)
        _suppressCentering = true;
        // 延迟到 Screen 属性就绪后再恢复位置
        Qt.callLater(function () {
            restorePosition();
            centeringTimer.start();
            // 如果启动时就处于锁定状态，启用鼠标穿透
            if (desktopLyrics.locked) {
                updateClickThroughRegion();
                if (clickThroughHelper)
                    clickThroughHelper.setEnabled(true);
            }
        });
    }

    Timer {
        id: centeringTimer
        interval: 300
        repeat: false
        onTriggered: enableCentering()
    }

    // 窗口关闭时保存配置
    onClosing: {
        saveCurrentConfig();
    }

    // 保存当前配置
    function saveCurrentConfig() {
        if (!lyricsConfig)
            return;

        if (isVertical) {
            lyricsConfig.verticalX = x;
            lyricsConfig.verticalY = y;
            lyricsConfig.verticalWidth = width;
            lyricsConfig.verticalHeight = height;
        } else {
            lyricsConfig.horizontalX = x;
            lyricsConfig.horizontalY = y;
            lyricsConfig.horizontalWidth = width;
            lyricsConfig.horizontalHeight = height;
        }
        lyricsConfig.isVertical = isVertical;
        lyricsConfig.locked = locked;
        lyricsConfig.scale = scale;
        lyricsConfig.fontSize = fontSize;
        lyricsConfig.saveConfig();
    }

    property point _dragPos: Qt.point(0, 0)
    property color textColor: "white"
    property bool showControls: false
    // 按钮背景色（深色，在白色背景下更清晰）
    property color btnBgNormal: "#CC333333"    // 默认：深灰80%透明度
    property color btnBgHover: "#EE555555"    // 悬停：深灰93%透明度
    property color btnBgActive: Qt.rgba(AppTheme.accent.r, AppTheme.accent.g, AppTheme.accent.b, 0.8)   // 激活（如解锁）：主题色80%

    // 延迟隐藏定时器（1.5秒，给用户足够时间点击解锁按钮）
    Timer {
        id: hideControlsTimer
        interval: 1500
        onTriggered: {
            if (!controlPanelHover.hovered && !controlPanelHoverV.hovered) {
                desktopLyrics.showControls = false;
            }
        }
    }

    // 主容器
    Item {
        id: mainContainer
        anchors.fill: parent

        // 歌词容器（无背景）
        Item {
            id: background
            // 始终居中于窗口
            anchors.centerIn: parent
            // 横向：宽度根据歌词内容 + 边距，最大屏幕80%
            // 竖向：宽度根据字体大小，高度根据容器高度（已限制最大屏幕80%）
            width: desktopLyrics.isVertical ? (desktopLyrics.fontSize * desktopLyrics.scale + 30) : Math.min(horizontalLyricContainer.width + 30, Screen.desktopAvailableWidth * 0.8)
            height: desktopLyrics.isVertical ? Math.min(verticalTextContainer.height + 30, Screen.desktopAvailableHeight * 0.8) : (desktopLyrics.fontSize * desktopLyrics.scale * 2.4 + 10 * desktopLyrics.scale)

            // 横向歌词文本
            Row {
                id: lyricRow
                anchors.centerIn: parent
                spacing: 20
                visible: !desktopLyrics.isVertical
                opacity: !desktopLyrics.isVertical ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                // 歌词内容容器
                Item {
                    id: horizontalLyricContainer
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(bgTextHorizontal.implicitWidth, Screen.desktopAvailableWidth * 0.8 - 30, desktopLyrics.horizontalWidthLimit)
                    height: bgTextHorizontal.implicitHeight
                    clip: false   // 星星 y 为负需伸出容器顶，裁剪交给内层 clipTextMask

                    // 由根级 syncLyricValues() 赋值（可见性隔离：窗口隐藏时零重算）
                    property string lyricText: "网狗音乐"
                    property int charIndex: -1
                    property real charProgress: 0

                    // 高亮比例
                    property real highlightRatio: {
                        var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || horizontalLyricContainer.lyricText.length) : horizontalLyricContainer.lyricText.length;
                        if (totalChars === 0 || horizontalLyricContainer.charIndex < 0)
                            return 0;
                        return (horizontalLyricContainer.charIndex + horizontalLyricContainer.charProgress) / totalChars;
                    }

                    // 跳跃星星的实际像素位置（由当前字 delegate 的 Binding 写入）
                    property real starX: 0

                    // 滚动偏移：跟随高亮位置
                    property real scrollOffset: {
                        var totalWidth = bgTextHorizontal.implicitWidth;
                        var visWidth = width;
                        if (totalWidth <= visWidth) return 0;
                        var hlX = highlightRatio * totalWidth;
                        var target = hlX - visWidth * 0.4;
                        return Math.max(0, Math.min(target, totalWidth - visWidth));
                    }
                    // 不用 Behavior 平滑：scrollOffset 随逐字进度 60Hz 变化，Behavior 的
                    // SmoothedAnimation 会把步进目标转成 60fps 持续动画，整窗钉在全速渲染；
                    // 60Hz 直接赋值步进（每步 <1px）视觉连续

                    // 底层（隐藏，仅测量整行宽度/高度，供容器宽度与 scrollOffset 使用）
                    Text {
                        id: bgTextHorizontal
                        visible: false
                        text: horizontalLyricContainer.lyricText
                        font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                        font.bold: true
                    }

                    // 横向裁剪层：只裁字、不裁星星
                    // 逐字渲染（原版效果：白色从左刷成红色、整行连续推进）。
                    // 每帧只重绘当前字（其他字 fillRatio 值不变不重绘）；
                    // 60fps 帧率由 C++ 16ms 定时器 + position 外推保证
                    Item {
                        anchors.fill: parent
                        clip: true

                        Row {
                            id: hLineRow
                            anchors.verticalCenter: parent.verticalCenter
                            x: -horizontalLyricContainer.scrollOffset
                            spacing: 0

                            Repeater {
                                model: playlistmanager ? playlistmanager.lyricChars : []
                                delegate: Item {
                                    required property int index
                                    required property var modelData
                                    width: hBaseChar.width
                                    height: hBaseChar.height
                                    property real fillRatio: index < horizontalLyricContainer.charIndex ? 1.0
                                        : (index === horizontalLyricContainer.charIndex ? horizontalLyricContainer.charProgress : 0.0)
                                    // 唱到字瞬间压到最扁 0.5，前段(0->a) ease-out 慢回弹到 1.0，之后保持等下一字
                                    property real squeeze: {
                                        if (!desktopLyrics.jumpEnabled) return 1.0
                                        if (index !== horizontalLyricContainer.charIndex || horizontalLyricContainer.charIndex < 0) return 1.0
                                        var p = horizontalLyricContainer.charProgress
                                        var a = 0.65
                                        if (p < a) {
                                            var t = p / a
                                            return 0.5 + (1.0 - 0.5) * (1 - (1 - t) * (1 - t))
                                        }
                                        return 1.0
                                    }
                                    transform: Scale { origin.x: 0; origin.y: height; yScale: squeeze }

                                    // 隐藏测量字：提供本字宽高
                                    Text {
                                        id: hBaseChar
                                        visible: false
                                        text: modelData.text
                                        font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                        font.bold: true
                                    }
                                    // 已唱色（左半，按 fillRatio 裁剪）+ 同色软发光
                                    Item {
                                        width: hBaseChar.width * fillRatio
                                        height: hBaseChar.height
                                        clip: true
                                        Text {
                                            text: modelData.text
                                            font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                            font.bold: true
                                            color: desktopLyrics.lyricsColor
                                            style: Text.Outline
                                            styleColor: desktopLyrics.lyricsGlow
                                        }
                                    }
                                    // 未唱色（右半，互补裁剪）+ 深色描边保可读
                                    Item {
                                        x: hBaseChar.width * fillRatio
                                        width: hBaseChar.width * (1 - fillRatio)
                                        height: hBaseChar.height
                                        clip: true
                                        Text {
                                            x: -hBaseChar.width * fillRatio
                                            text: modelData.text
                                            font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                            font.bold: true
                                            color: desktopLyrics.textColor
                                            style: Text.Outline
                                            styleColor: "#40000000"
                                        }
                                    }

                                    Binding {
                                        target: horizontalLyricContainer
                                        property: "starX"
                                        value: x + horizontalLyricContainer.charProgress * width
                                        when: index === horizontalLyricContainer.charIndex && horizontalLyricContainer.charIndex >= 0
                                    }
                                }
                            }
                        }
                    }

                    // 跳跃星星：跟在当前字上方（y 为负伸出容器顶，由容器 clip:false 可见）
                    Item {
                        id: hStarCursor
                        visible: desktopLyrics.jumpEnabled && horizontalLyricContainer.charIndex >= 0
                        property real fontPx: desktopLyrics.fontSize * desktopLyrics.scale
                        width: fontPx * 0.7
                        height: width
                        // 唱到字下沉压字顶(1)->前段(0->a)减速上抛到最高(0,慢)->后段(a->1)重力加速下落(1,快)
                        // 例外：最后一字末段不下落，保持高位往上淡出
                        // （charProgress 由 16ms 定时器刷新，60fps 平滑）
                        property real starBob: {
                            if (horizontalLyricContainer.charIndex < 0) return 0
                            var p = horizontalLyricContainer.charProgress
                            var a = 0.65
                            if (p < a) {
                                var t = p / a
                                return (1 - t) * (1 - t)
                            }
                            if (horizontalLyricContainer.charIndex >= horizontalLyricContainer.lyricText.length - 1) return 0
                            var t = (p - a) / (1 - a)
                            return t * t
                        }
                        x: -horizontalLyricContainer.scrollOffset + horizontalLyricContainer.starX - width / 2
                        y: -fontPx * 0.8
                        opacity: {
                            var ci = horizontalLyricContainer.charIndex
                            var cp = horizontalLyricContainer.charProgress
                            var total = playlistmanager ? playlistmanager.lyricCharCount : 0
                            if (ci < 0) return 0
                            if (ci === 0 && cp < 0.15) return cp / 0.15
                            if (ci >= total - 1 && cp > 0.95) return Math.max(0, (1 - cp) / 0.05)
                            return 1
                        }
                        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }

                        // 拖尾：从主星位置随机喷出的小星粒子，各自随机轨迹飘散+淡出；未播放时不动
                        Repeater {
                            model: 4
                            delegate: Canvas {
                                id: hTrailStar
                                required property int index
                                property real life: 0
                                property real fontPx: desktopLyrics.fontSize * desktopLyrics.scale
                                property real vx: -(0.5 + Math.random() * 0.4)
                                property real vy: -0.1 + Math.random() * 0.3
                                width: hStarCursor.width * (0.55 + Math.random() * 0.2)
                                height: width
                                x: hStarCursor.width * -0.2 + vx * life * (fontPx * 4) - width / 2
                                y: hStarCursor.height * 0.9 + vy * life * (fontPx * 1.5)
                                   + 0.2 * (life * 10) * (life * 10) - height / 2
                                opacity: Math.max(0, 1 - life) * 0.8 * hStarCursor.opacity
                                // 50ms 定时步进替代 60Hz 持续动画：拖尾周期 2s，20fps 视觉无差。
                                // 持续 NumberAnimation 会把整窗钉在全速渲染；与逐字刷新同频步进，
                                // 避免两个同频源相位交错让渲染器每帧都有活干
                                Timer {
                                    interval: 50
                                    running: hStarCursor.visible && playlistmanager && !playlistmanager.isPaused
                                    repeat: true
                                    property real t: 0
                                    onTriggered: {
                                        t += interval
                                        var tt = t - index * 500   // 与 PauseAnimation 相同的错峰起点
                                        hTrailStar.life = tt < 0 ? 0 : (tt % 2000) / 2000
                                    }
                                }
                                Connections {
                                    target: desktopLyrics
                                    function onStarColorChanged() { hTrailStar.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.fillStyle = desktopLyrics.starColor
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
                            id: hStarCanvas
                            width: parent.width
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: hStarCursor.starBob * (desktopLyrics.fontSize * desktopLyrics.scale * 0.6)
                            // 一字转一个角(72°)，跟随字进度
                            rotation: (horizontalLyricContainer.charIndex + horizontalLyricContainer.charProgress) * 72
                            Connections {
                                target: desktopLyrics
                                function onStarColorChanged() { hStarCanvas.requestPaint() }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = desktopLyrics.starColor
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
                }
            }

            // 竖向歌词文本
            Column {
                id: lyricColumn
                anchors.centerIn: parent
                spacing: 8
                visible: desktopLyrics.isVertical
                opacity: desktopLyrics.isVertical ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                // 竖排歌词内容容器
                Item {
                    id: verticalTextContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: verticalBgColumn.width
                    height: Math.min(verticalBgColumn.height, Screen.desktopAvailableHeight * 0.8 - 30, desktopLyrics.verticalHeightLimit)
                    clip: true

                    // 由根级 syncLyricValues() 赋值（可见性隔离：窗口隐藏时零重算）
                    property string lyricText: "网狗音乐"
                    property int charIndex: -1
                    property real charProgress: 0

                    // 高亮比例
                    property real highlightRatio: {
                        var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || verticalTextContainer.lyricText.length) : verticalTextContainer.lyricText.length;
                        if (totalChars === 0 || verticalTextContainer.charIndex < 0)
                            return 0;
                        return (verticalTextContainer.charIndex + verticalTextContainer.charProgress) / totalChars;
                    }

                    // 滚动偏移：跟随高亮位置
                    property real scrollOffset: {
                        var totalHeight = verticalBgColumn.height;
                        var visHeight = height;
                        if (totalHeight <= visHeight) return 0;
                        var hlY = highlightRatio * totalHeight;
                        var target = hlY - visHeight * 0.4;
                        return Math.max(0, Math.min(target, totalHeight - visHeight));
                    }

                    // 同横向：直接赋值步进，不用 Behavior（避免整窗钉在全速渲染）

                    // 底层：完整灰色文字（整列）
                    Column {
                        id: verticalBgColumn
                        spacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -verticalTextContainer.scrollOffset

                        Repeater {
                            model: verticalTextContainer.lyricText.length

                            Text {
                                required property int index
                                property string currentChar: verticalTextContainer.lyricText.charAt(index)
                                property int code: currentChar.charCodeAt(0)
                                property bool isAscii: code < 128 && currentChar !== ' '
                                property bool isLetterOrNumber: (currentChar >= 'a' && currentChar <= 'z') || (currentChar >= 'A' && currentChar <= 'Z') || (currentChar >= '0' && currentChar <= '9')
                                // 竖排时 CJK 标点/括号需旋转 90° 才不突兀。按 Unicode 区间判定，
                                // 覆盖 、。《》「」『』【】〔〕〈〉、全角标点（！？：；（）等）、
                                // 破折号/省略号/引号（—…""''）等，避免枚举遗漏（原白名单漏了《》等）。
                                property bool isCJKPunctuation: (code >= 0x3000 && code <= 0x303F)
                                        || (code >= 0xFF01 && code <= 0xFF0F)
                                        || (code >= 0xFF1A && code <= 0xFF20)
                                        || (code >= 0xFF3B && code <= 0xFF40)
                                        || (code >= 0xFF5B && code <= 0xFF65)
                                        || (code >= 0x2010 && code <= 0x2027)
                                        || (code >= 0x2030 && code <= 0x205E)
                                property bool isPunctuation: (isAscii && !isLetterOrNumber) || isCJKPunctuation

                                text: currentChar
                                font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                font.bold: true
                                color: desktopLyrics.textColor
                                style: Text.Outline
                                styleColor: "#40000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                rotation: isPunctuation ? 90 : 0
                                transformOrigin: Item.Center
                                width: desktopLyrics.fontSize * desktopLyrics.scale + 10
                                height: font.pixelSize
                            }
                        }
                    }

                    // 高亮层：从上到下刷过去
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -verticalTextContainer.scrollOffset
                        width: verticalBgColumn.width
                        height: verticalBgColumn.height * verticalTextContainer.highlightRatio
                        clip: true
                        visible: verticalTextContainer.highlightRatio > 0

                        Column {
                            id: verticalHlColumn
                            spacing: 2
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: verticalTextContainer.lyricText.length

                                Text {
                                    required property int index
                                    property string currentChar: verticalTextContainer.lyricText.charAt(index)
                                    property int code: currentChar.charCodeAt(0)
                                    property bool isAscii: code < 128 && currentChar !== ' '
                                    property bool isLetterOrNumber: (currentChar >= 'a' && currentChar <= 'z') || (currentChar >= 'A' && currentChar <= 'Z') || (currentChar >= '0' && currentChar <= '9')
                                    // 竖排时 CJK 标点/括号需旋转 90° 才不突兀。按 Unicode 区间判定，
                                    // 覆盖 、。《》「」『』【】〔〕〈〉、全角标点（！？：；（）等）、
                                    // 破折号/省略号/引号（—…""''）等，避免枚举遗漏（原白名单漏了《》等）。
                                    property bool isCJKPunctuation: (code >= 0x3000 && code <= 0x303F)
                                            || (code >= 0xFF01 && code <= 0xFF0F)
                                            || (code >= 0xFF1A && code <= 0xFF20)
                                            || (code >= 0xFF3B && code <= 0xFF40)
                                            || (code >= 0xFF5B && code <= 0xFF65)
                                            || (code >= 0x2010 && code <= 0x2027)
                                            || (code >= 0x2030 && code <= 0x205E)
                                    property bool isPunctuation: (isAscii && !isLetterOrNumber) || isCJKPunctuation

                                    text: currentChar
                                    font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                    font.bold: true
                                    color: desktopLyrics.lyricsColor
                                    // 同色软发光（以前的效果）
                                    style: Text.Outline
                                    styleColor: desktopLyrics.lyricsGlow
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    rotation: isPunctuation ? 90 : 0
                                    transformOrigin: Item.Center
                                    width: desktopLyrics.fontSize * desktopLyrics.scale + 10
                                    height: font.pixelSize
                                }
                            }
                        }
                    }
                }
            }
        }

        // 控制面板 - 横向模式（鼠标悬停时显示）
        Row {
            id: controlPanelHorizontal
            anchors.bottom: background.top
            anchors.bottomMargin: 8 * desktopLyrics.scale
            anchors.horizontalCenter: background.horizontalCenter
            spacing: 5 * desktopLyrics.scale
            // 锁定时显示解锁按钮，未锁定时悬停显示所有按钮
            visible: !desktopLyrics.isVertical
            opacity: desktopLyrics.showControls ? 1 : 0
            z: 100

            HoverHandler {
                id: controlPanelHover
                onHoveredChanged: {
                    if (hovered) {
                        hideControlsTimer.stop();
                        desktopLyrics.showControls = true;
                    } else {
                        hideControlsTimer.restart();
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: AppTheme.animFast
                }
            }

            // 缩小按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: "−"
                pixelSize: AppTheme.fontSizeTitle
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    if (desktopLyrics.scale > 0.6) {
                        desktopLyrics.scale -= 0.1;
                        saveCurrentConfig();
                    }
                }
            }

            // 缩放显示（未锁定时显示）
            Rectangle {
                width: 44 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: "#CC333333"
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: Math.round(desktopLyrics.scale * 100) + "%"
                    font.pixelSize: AppTheme.fontSizeCaption * desktopLyrics.scale
                    color: "white"
                    font.bold: true
                }
            }

            // 放大按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: "+"
                pixelSize: AppTheme.fontSizeTitle
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    if (desktopLyrics.scale < 1.5) {
                        desktopLyrics.scale += 0.1;
                        saveCurrentConfig();
                    }
                }
            }

            // 横向/竖向切换按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: desktopLyrics.isVertical ? "横" : "竖"
                pixelSize: AppTheme.fontSizeCaption
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    saveCurrentConfig();
                    _suppressCentering = true;
                    desktopLyrics.isVertical = !desktopLyrics.isVertical;
                    Qt.callLater(function () {
                        restorePosition();
                        enableCentering();
                    });
                }
            }

            // 播放/暂停按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: {
                    try {
                        return playlistmanager ? (playlistmanager.isPaused ? AppIcon.play : AppIcon.pause) : AppIcon.play;
                    } catch (e) {
                        return AppIcon.play;
                    }
                }
                onClicked: {
                    try {
                        if (playlistmanager)
                            playlistmanager.playstop();
                    } catch (e) {}
                }
            }

            // 分隔线
            Rectangle {
                width: 1
                height: 18 * desktopLyrics.scale
                color: "#40FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                visible: !desktopLyrics.locked
            }

            // 锁定/解锁按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: AppIcon.unlock
                onClicked: {
                    desktopLyrics.locked = !desktopLyrics.locked;
                    saveCurrentConfig();
                }
            }

            // 解锁按钮（锁定状态下显示）
            DesktopLyricsControlButton {
                visible: desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: "#80333333"
                hoverColor: btnBgActive
                iconSource: AppIcon.lock
                onClicked: {
                    desktopLyrics.locked = false;
                    saveCurrentConfig();
                }
            }

            // 关闭桌面歌词（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: AppIcon.close
                onClicked: {
                    if (lyricsConfig) {
                        lyricsConfig.enabled = false
                        lyricsConfig.saveConfig()
                    }
                }
            }
        }

        // 控制面板 - 竖向模式（鼠标悬停时显示）
        Column {
            id: controlPanelVertical
            anchors.left: parent.left
            anchors.leftMargin: 8 * desktopLyrics.scale
            anchors.verticalCenter: background.verticalCenter
            spacing: 5 * desktopLyrics.scale
            // 悬停显示控制按钮（含解锁按钮）
            visible: desktopLyrics.isVertical
            opacity: desktopLyrics.showControls ? 1 : 0
            z: 100

            HoverHandler {
                id: controlPanelHoverV
                onHoveredChanged: {
                    if (hovered) {
                        hideControlsTimer.stop();
                        desktopLyrics.showControls = true;
                    } else {
                        hideControlsTimer.restart();
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: AppTheme.animFast
                }
            }

            // 缩小按钮
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: "−"
                pixelSize: AppTheme.fontSizeTitle
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    if (desktopLyrics.scale > 0.6) {
                        desktopLyrics.scale -= 0.1;
                        saveCurrentConfig();
                    }
                }
            }

            // 缩放显示
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: "#CC333333"
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: Math.round(desktopLyrics.scale * 100) + "%"
                    font.pixelSize: 9 * desktopLyrics.scale
                    color: "white"
                    font.bold: true
                }
            }

            // 放大按钮
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: "+"
                pixelSize: AppTheme.fontSizeTitle
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    if (desktopLyrics.scale < 1.5) {
                        desktopLyrics.scale += 0.1;
                        saveCurrentConfig();
                    }
                }
            }

            // 横向/竖向切换按钮
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                label: "横"
                pixelSize: AppTheme.fontSizeCaption
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                onClicked: {
                    saveCurrentConfig();
                    _suppressCentering = true;
                    desktopLyrics.isVertical = !desktopLyrics.isVertical;
                    Qt.callLater(function () {
                        restorePosition();
                        enableCentering();
                    });
                }
            }

            // 播放/暂停按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: {
                    try {
                        return playlistmanager ? (playlistmanager.isPaused ? AppIcon.play : AppIcon.pause) : AppIcon.play;
                    } catch (e) {
                        return AppIcon.play;
                    }
                }
                onClicked: {
                    try {
                        if (playlistmanager)
                            playlistmanager.playstop();
                    } catch (e) {}
                }
            }

            // 锁定/解锁按钮（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: AppIcon.unlock
                onClicked: {
                    desktopLyrics.locked = !desktopLyrics.locked;
                    saveCurrentConfig();
                }
            }

            // 解锁按钮（锁定状态下显示）
            DesktopLyricsControlButton {
                visible: desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: "#80333333"
                hoverColor: btnBgActive
                iconSource: AppIcon.lock
                onClicked: {
                    desktopLyrics.locked = false;
                    saveCurrentConfig();
                }
            }

            // 关闭桌面歌词（未锁定时显示）
            DesktopLyricsControlButton {
                visible: !desktopLyrics.locked
                scaleFactor: desktopLyrics.scale
                animateColor: true
                normalColor: btnBgNormal
                hoverColor: btnBgHover
                iconSource: AppIcon.close
                onClicked: {
                    if (lyricsConfig) {
                        lyricsConfig.enabled = false
                        lyricsConfig.saveConfig()
                    }
                }
            }
        }

        // 悬停检测区域（始终启用）
        HoverHandler {
            id: mainHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    hideControlsTimer.stop();
                    desktopLyrics.showControls = true;
                } else {
                    hideControlsTimer.restart();
                }
            }
        }

        // 拖动区域（未锁定时）- 只覆盖歌词背景
        MouseArea {
            id: dragMouseArea
            anchors.fill: background
            enabled: !desktopLyrics.locked
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            z: 50

            onPressed: function (mouse) {
                desktopLyrics._dragPos = Qt.point(mouse.x + background.x, mouse.y + background.y);
                cursorShape = Qt.ClosedHandCursor;
            }
            onReleased: {
                cursorShape = Qt.ArrowCursor;
                saveCurrentConfig();
            }
            onPositionChanged: function (mouse) {
                if ((mouse.buttons & Qt.LeftButton) && !desktopLyrics.locked) {
                    var newX = desktopLyrics.x + (mouse.x + background.x - desktopLyrics._dragPos.x);
                    var newY = desktopLyrics.y + (mouse.y + background.y - desktopLyrics._dragPos.y);

                    // 边界检查
                    var minVisible = 50;
                    var screenRight = Screen.virtualX + Screen.width;
                    var screenBottom = Screen.virtualY + Screen.height;

                    if (newX > screenRight - minVisible)
                        newX = screenRight - minVisible;
                    if (newX + desktopLyrics.width - minVisible < Screen.virtualX)
                        newX = Screen.virtualX - desktopLyrics.width + minVisible;
                    if (newY > screenBottom - minVisible)
                        newY = screenBottom - minVisible;
                    if (newY + desktopLyrics.height - minVisible < Screen.virtualY)
                        newY = Screen.virtualY - desktopLyrics.height + minVisible;

                    desktopLyrics.x = newX;
                    desktopLyrics.y = newY;
                    // 拖动时同步更新锚点中心，确保歌词变化时从新位置保持居中
                    _anchorCenterX = newX + desktopLyrics.width / 2
                    _anchorCenterY = newY + desktopLyrics.height / 2
                }
            }
        }
    }

    // 锁定状态变化时的提示
    Rectangle {
        anchors.centerIn: parent
        width: lockTipRow.width + 30
        height: 36
        radius: 18
        color: "#CC000000"
        visible: lockTipTimer.running
        z: 100

        Row {
            id: lockTipRow
            anchors.centerIn: parent
            spacing: 8

            Image {
                source: desktopLyrics.locked ? AppIcon.lock : AppIcon.unlock
                sourceSize: Qt.size(128, 128)
                mipmap: true
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: parent
                    color: "#FFFFFF"
                }
            }

            Text {
                text: desktopLyrics.locked ? "已锁定 - 点击解锁图标解锁" : "已解锁 - 可拖动调整"
                font.pixelSize: AppTheme.fontSizeBody
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Timer {
            id: lockTipTimer
            interval: 1500
            running: false
        }
    }

    // 更新穿透捕获区域和监控区域
    function updateClickThroughRegion() {
        if (!clickThroughHelper || !desktopLyrics.locked) return;
        // 监控区域 = 整个窗口（鼠标进入时显示锁按钮）
        clickThroughHelper.setMonitorRegion(
            desktopLyrics.x, desktopLyrics.y,
            desktopLyrics.width, desktopLyrics.height
        );
        // 捕获区域 = 锁按钮位置（鼠标进入时取消穿透使其可点击）
        var panel = desktopLyrics.isVertical ? controlPanelVertical : controlPanelHorizontal;
        var pos = panel.mapToGlobal(0, 0);
        clickThroughHelper.setCaptureRegion(
            pos.x - 10, pos.y - 10,
            panel.width + 20, panel.height + 20
        );
    }

    Timer {
        id: regionUpdateTimer
        interval: 200
        repeat: true
        running: desktopLyrics.locked && desktopLyrics.visible
        onTriggered: updateClickThroughRegion()
    }

    // 穿透控制器信号：鼠标进入/离开窗口区域（穿透时不依赖 HoverHandler）
    Connections {
        target: clickThroughHelper
        function onHoverInWindowChanged(inside) {
            if (inside) {
                // 鼠标进入窗口区域 -> 显示锁按钮
                hideControlsTimer.stop();
                desktopLyrics.showControls = true;
            } else {
                // 鼠标离开窗口区域 -> 延迟隐藏
                hideControlsTimer.restart();
            }
        }
    }

    onLockedChanged: {
        lockTipTimer.restart();
        if (desktopLyrics.locked) {
            // 延迟到布局更新后再设置区域 + 启用穿透
            Qt.callLater(function() {
                updateClickThroughRegion();
                if (clickThroughHelper)
                    clickThroughHelper.setEnabled(true);
            });
        } else {
            if (clickThroughHelper)
                clickThroughHelper.setEnabled(false);
        }
    }
}
