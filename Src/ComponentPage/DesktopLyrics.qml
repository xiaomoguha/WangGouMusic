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

    // 窗口大小 - 保证最小能显示所有控制按钮，歌词居中
    width: desktopLyrics.isVertical ? Math.max(background.width + 70, 44 * desktopLyrics.scale + 16) : Math.max(background.width + 20, controlPanelHorizontal.implicitWidth + 20)
    height: desktopLyrics.isVertical ? Math.max(background.height + 20, controlPanelVertical.implicitHeight + 20) : Math.max(background.height + 70, 28 * desktopLyrics.scale + 16 + 8 * desktopLyrics.scale)

    // 歌词内容变化时保持中心位置不变
    property real _prevWidth: width
    property real _prevHeight: height
    onWidthChanged: {
        if (_prevWidth > 0) {
            var delta = width - _prevWidth;
            desktopLyrics.x -= delta / 2;
        }
        _prevWidth = width;
    }
    onHeightChanged: {
        if (_prevHeight > 0) {
            var delta = height - _prevHeight;
            desktopLyrics.y -= delta / 2;
        }
        _prevHeight = height;
    }

    visible: true
    color: "transparent"

    // 根据锁定状态设置窗口标志
    // 窗口大小跟随歌词内容，不需要 WindowTransparentForInput
    // WindowDoesNotAcceptFocus: 点击时不获取焦点，避免激活主窗口
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus

    // 初始化位置 - 从配置读取，延迟处理确保配置已加载
    Component.onCompleted: {
        Qt.callLater(function () {
            if (lyricsConfig) {
                if (isVertical) {
                    if (lyricsConfig.verticalX !== 0 || lyricsConfig.verticalY !== 0) {
                        desktopLyrics.x = lyricsConfig.verticalX;
                        desktopLyrics.y = lyricsConfig.verticalY;
                    } else {
                        // 默认位置：屏幕右侧居中
                        desktopLyrics.x = Screen.desktopAvailableWidth - desktopLyrics.width - 20;
                        desktopLyrics.y = (Screen.desktopAvailableHeight - desktopLyrics.height) / 2;
                    }
                } else {
                    if (lyricsConfig.horizontalX !== 0 || lyricsConfig.horizontalY !== 0) {
                        desktopLyrics.x = lyricsConfig.horizontalX;
                        desktopLyrics.y = lyricsConfig.horizontalY;
                    } else {
                        // 默认位置：屏幕底部居中
                        desktopLyrics.x = (Screen.desktopAvailableWidth - desktopLyrics.width) / 2;
                        desktopLyrics.y = Screen.desktopAvailableHeight - desktopLyrics.height - 50;
                    }
                }
            } else {
                // 无配置时使用默认位置
                if (isVertical) {
                    desktopLyrics.x = Screen.desktopAvailableWidth - desktopLyrics.width - 20;
                    desktopLyrics.y = (Screen.desktopAvailableHeight - desktopLyrics.height) / 2;
                } else {
                    desktopLyrics.x = (Screen.desktopAvailableWidth - desktopLyrics.width) / 2;
                    desktopLyrics.y = Screen.desktopAvailableHeight - desktopLyrics.height - 50;
                }
            }
        });
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
            // 竖向：宽度根据字体大小（旋转后的英文需要更大宽度），高度根据歌词行数，最大屏幕80%
            width: desktopLyrics.isVertical ? (desktopLyrics.fontSize * desktopLyrics.scale + 30) : Math.min(horizontalLyricContainer.width + 30, Screen.desktopAvailableWidth * 0.8)
            height: desktopLyrics.isVertical ? Math.min(verticalTextContainer.height + 30, Screen.desktopAvailableHeight * 0.8) : (50 * desktopLyrics.scale)

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
                    width: Math.min(bgTextHorizontal.implicitWidth, Screen.desktopAvailableWidth * 0.8 - 30)
                    height: bgTextHorizontal.implicitHeight

                    property string lyricText: {
                        try {
                            return playlistmanager ? (playlistmanager.currlyric || "网狗音乐") : "网狗音乐";
                        } catch (e) {
                            return "网狗音乐";
                        }
                    }

                    property int charIndex: {
                        try {
                            return playlistmanager ? playlistmanager.lyricCharIndex : -1;
                        } catch (e) {
                            return -1;
                        }
                    }

                    property real charProgress: {
                        try {
                            return playlistmanager ? (playlistmanager.lyricCharProgress || 0) : 0;
                        } catch (e) {
                            return 0;
                        }
                    }

                    // 高亮比例
                    property real highlightRatio: {
                        // 使用 lyricCharCount（时间标签数）而不是 text.length，因为英文歌词可能按单词分割
                        var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || horizontalLyricContainer.lyricText.length) : horizontalLyricContainer.lyricText.length;
                        if (totalChars === 0 || horizontalLyricContainer.charIndex < 0)
                            return 0;
                        return (horizontalLyricContainer.charIndex + horizontalLyricContainer.charProgress) / totalChars;
                    }

                    // 底层：完整白色文字
                    Text {
                        id: bgTextHorizontal
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: horizontalLyricContainer.lyricText
                        font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                        font.bold: true
                        color: desktopLyrics.textColor
                        style: Text.Outline
                        styleColor: "#40000000"
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    // 高亮层：从左到右刷过去
                    Item {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: hlTextHorizontal.width * horizontalLyricContainer.highlightRatio
                        height: bgTextHorizontal.height
                        clip: true
                        visible: horizontalLyricContainer.highlightRatio > 0

                        Text {
                            id: hlTextHorizontal
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: horizontalLyricContainer.lyricText
                            font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                            font.bold: true
                            color: AppTheme.accent
                            style: Text.Outline
                            styleColor: AppTheme.accentGlow
                            maximumLineCount: 1
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
                    height: verticalBgColumn.height

                    property string lyricText: {
                        try {
                            var text = playlistmanager ? (playlistmanager.currlyric || "网狗音乐") : "网狗音乐";
                            // 计算最大可显示字符数（屏幕高度80%）
                            var maxHeight = Screen.desktopAvailableHeight * 0.8 - 30;
                            var charHeight = desktopLyrics.fontSize * desktopLyrics.scale + 2;
                            var maxChars = Math.floor(maxHeight / charHeight);
                            // 如果超出，保留前面的字符，最后加省略号
                            if (text.length > maxChars && maxChars > 3) {
                                return text.substring(0, maxChars - 1) + "…";
                            }
                            return text;
                        } catch (e) {
                            return "网狗音乐";
                        }
                    }

                    property int charIndex: {
                        try {
                            return playlistmanager ? playlistmanager.lyricCharIndex : -1;
                        } catch (e) {
                            return -1;
                        }
                    }

                    property real charProgress: {
                        try {
                            return playlistmanager ? (playlistmanager.lyricCharProgress || 0) : 0;
                        } catch (e) {
                            return 0;
                        }
                    }

                    // 高亮比例
                    property real highlightRatio: {
                        // 使用 lyricCharCount（时间标签数）而不是 text.length，因为英文歌词可能按单词分割
                        var totalChars = playlistmanager ? (playlistmanager.lyricCharCount || verticalTextContainer.lyricText.length) : verticalTextContainer.lyricText.length;
                        if (totalChars === 0 || verticalTextContainer.charIndex < 0)
                            return 0;
                        return (verticalTextContainer.charIndex + verticalTextContainer.charProgress) / totalChars;
                    }

                    // 底层：完整灰色文字（整列）
                    Column {
                        id: verticalBgColumn
                        spacing: 2
                        anchors.centerIn: parent

                        Repeater {
                            model: verticalTextContainer.lyricText.length

                            Text {
                                required property int index
                                property string currentChar: verticalTextContainer.lyricText.charAt(index)
                                property bool isAscii: currentChar.charCodeAt(0) < 128 && currentChar !== ' '

                                text: currentChar
                                font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                font.bold: true
                                color: desktopLyrics.textColor
                                style: Text.Outline
                                styleColor: "#40000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                rotation: isAscii ? 90 : 0
                                transformOrigin: Item.Center
                                width: desktopLyrics.fontSize * desktopLyrics.scale + 10
                                height: isAscii ? font.pixelSize * 0.6 : font.pixelSize
                            }
                        }
                    }

                    // 高亮层：从上到下刷过去
                    Item {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
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
                                    property bool isAscii: currentChar.charCodeAt(0) < 128 && currentChar !== ' '

                                    text: currentChar
                                    font.pixelSize: desktopLyrics.fontSize * desktopLyrics.scale
                                    font.bold: true
                                    color: AppTheme.accent
                                    style: Text.Outline
                                    styleColor: AppTheme.accentGlow
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    rotation: isAscii ? 90 : 0
                                    transformOrigin: Item.Center
                                    width: desktopLyrics.fontSize * desktopLyrics.scale + 10
                                    height: isAscii ? font.pixelSize * 0.6 : font.pixelSize
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
                    duration: 150
                }
            }

            // 缩小按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: zoomOutHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.pixelSize: 16 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: zoomOutHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.scale > 0.6) {
                            desktopLyrics.scale -= 0.1;
                            saveCurrentConfig();
                        }
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
                    font.pixelSize: 11 * desktopLyrics.scale
                    color: "white"
                    font.bold: true
                }
            }

            // 放大按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: zoomInHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 16 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: zoomInHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.scale < 1.5) {
                            desktopLyrics.scale += 0.1;
                            saveCurrentConfig();
                        }
                    }
                }
            }

            // 横向/竖向切换按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: rotateHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: desktopLyrics.isVertical ? "横" : "竖"
                    font.pixelSize: 11 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: rotateHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        // 先保存当前位置
                        saveCurrentConfig();
                        // 切换模式
                        desktopLyrics.isVertical = !desktopLyrics.isVertical;
                        // 恢复到新模式的位置
                        if (desktopLyrics.isVertical) {
                            desktopLyrics.x = lyricsConfig ? lyricsConfig.verticalX : (Screen.desktopAvailableWidth - desktopLyrics.width - 20);
                            desktopLyrics.y = lyricsConfig ? lyricsConfig.verticalY : (Screen.desktopAvailableHeight - desktopLyrics.height) / 2;
                        } else {
                            desktopLyrics.x = lyricsConfig ? lyricsConfig.horizontalX : (Screen.desktopAvailableWidth - desktopLyrics.width) / 2;
                            desktopLyrics.y = lyricsConfig ? lyricsConfig.horizontalY : (Screen.desktopAvailableHeight - desktopLyrics.height - 50);
                        }
                    }
                }
            }

            // 播放/暂停按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: playPauseDlHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Image {
                    id: playPauseDlIcon
                    anchors.centerIn: parent
                    source: {
                        try {
                            return playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png";
                        } catch (e) {
                            return "qrc:/image/play.png";
                        }
                    }
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playPauseDlIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: playPauseDlHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        try {
                            if (playlistmanager)
                                playlistmanager.playstop();
                        } catch (e) {}
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
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
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: lockHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Image {
                    id: lockIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/lock_open.png"
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: lockIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: lockHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        desktopLyrics.locked = !desktopLyrics.locked;
                        saveCurrentConfig();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 解锁按钮（锁定状态下显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: unlockHandler.hovered ? btnBgActive : "#80333333"
                visible: desktopLyrics.locked

                Image {
                    id: unlockIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/lock_close.png"
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: unlockIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: unlockHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        desktopLyrics.locked = false;
                        saveCurrentConfig();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
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
                    duration: 150
                }
            }

            // 缩小按钮
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: zoomOutHandlerV.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.pixelSize: 16 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: zoomOutHandlerV
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.scale > 0.6) {
                            desktopLyrics.scale -= 0.1;
                            saveCurrentConfig();
                        }
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
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: zoomInHandlerV.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 16 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: zoomInHandlerV
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.scale < 1.5) {
                            desktopLyrics.scale += 0.1;
                            saveCurrentConfig();
                        }
                    }
                }
            }

            // 横向/竖向切换按钮
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: rotateHandlerV.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Text {
                    anchors.centerIn: parent
                    text: "横"
                    font.pixelSize: 11 * desktopLyrics.scale
                    font.bold: true
                    color: "white"
                }

                HoverHandler {
                    id: rotateHandlerV
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        // 先保存当前位置
                        saveCurrentConfig();
                        // 切换模式
                        desktopLyrics.isVertical = !desktopLyrics.isVertical;
                        // 恢复到新模式的位置
                        if (desktopLyrics.isVertical) {
                            desktopLyrics.x = lyricsConfig ? lyricsConfig.verticalX : (Screen.desktopAvailableWidth - desktopLyrics.width - 20);
                            desktopLyrics.y = lyricsConfig ? lyricsConfig.verticalY : (Screen.desktopAvailableHeight - desktopLyrics.height) / 2;
                        } else {
                            desktopLyrics.x = lyricsConfig ? lyricsConfig.horizontalX : (Screen.desktopAvailableWidth - desktopLyrics.width) / 2;
                            desktopLyrics.y = lyricsConfig ? lyricsConfig.horizontalY : (Screen.desktopAvailableHeight - desktopLyrics.height - 50);
                        }
                    }
                }
            }

            // 播放/暂停按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: playPauseDlVHandler.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Image {
                    id: playPauseDlVIcon
                    anchors.centerIn: parent
                    source: {
                        try {
                            return playlistmanager ? (playlistmanager.isPaused ? "qrc:/image/play.png" : "qrc:/image/paused.png") : "qrc:/image/play.png";
                        } catch (e) {
                            return "qrc:/image/play.png";
                        }
                    }
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playPauseDlVIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: playPauseDlVHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        try {
                            if (playlistmanager)
                                playlistmanager.playstop();
                        } catch (e) {}
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 锁定/解锁按钮（未锁定时显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: lockHandlerV.hovered ? btnBgHover : btnBgNormal
                visible: !desktopLyrics.locked

                Image {
                    id: lockIconV
                    anchors.centerIn: parent
                    source: "qrc:/image/lock_open.png"
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: lockIconV
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: lockHandlerV
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        desktopLyrics.locked = !desktopLyrics.locked;
                        saveCurrentConfig();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            // 解锁按钮（锁定状态下显示）
            Rectangle {
                width: 28 * desktopLyrics.scale
                height: 28 * desktopLyrics.scale
                radius: 14 * desktopLyrics.scale
                color: unlockHandlerV.hovered ? btnBgActive : "#80333333"
                visible: desktopLyrics.locked

                Image {
                    id: unlockIconV
                    anchors.centerIn: parent
                    source: "qrc:/image/lock_close.png"
                    width: 12 * desktopLyrics.scale
                    height: 12 * desktopLyrics.scale
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: unlockIconV
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: unlockHandlerV
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        desktopLyrics.locked = false;
                        saveCurrentConfig();
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
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
                source: desktopLyrics.locked ? "qrc:/image/lock_close.png" : "qrc:/image/lock_open.png"
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
                font.pixelSize: 13
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

    onLockedChanged: {
        lockTipTimer.restart();
    }
}
