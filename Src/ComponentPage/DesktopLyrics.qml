import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects

Window {
    id: desktopLyrics
    objectName: "desktopLyrics"
    width: 700
    height: 140
    visible: true
    color: "transparent"

    // 根据锁定状态设置窗口标志
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool

    // 初始化位置
    x: (Screen.desktopAvailableWidth - width) / 2
    y: Screen.desktopAvailableHeight - height - 50

    Component.onCompleted: {
        positionAboveTaskbar();
    }

    function positionAboveTaskbar() {
        var screenCenterX = Screen.desktopAvailableWidth / 2 - width / 2;
        var taskbarHeight = Screen.height - Screen.desktopAvailableHeight;
        x = screenCenterX;
        y = Screen.desktopAvailableHeight - height;
    }

    property point _dragPos: Qt.point(0, 0)
    property color textColor: "white"
    property int fontSize: 22
    property real panelOpacity: 0.85
    property bool locked: false
    property real scale: 1.0
    property bool showControls: false

    // 延迟隐藏定时器
    Timer {
        id: hideControlsTimer
        interval: 300
        onTriggered: {
            if (!controlPanelHover.hovered) {
                showControls = false;
            }
        }
    }

    // 主容器
    Item {
        id: mainContainer
        anchors.fill: parent

        // 歌词背景 - 固定在窗口中心
        Rectangle {
            id: background
            anchors.centerIn: parent
            width: lyricRow.width + 60
            height: 50 * desktopLyrics.scale
            radius: 25
            color: "#CC000000"
            border.color: "#33FFFFFF"
            border.width: 1
            opacity: showControls || !locked ? panelOpacity : 0.7

            // 发光效果
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 4
                radius: 16
                samples: 32
                color: "#40000000"
                spread: 0.2
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // 歌词文本
            Row {
                id: lyricRow
                anchors.centerIn: parent
                spacing: 20

                // 左侧音乐图标
                Rectangle {
                    width: 36 * desktopLyrics.scale
                    height: 36 * desktopLyrics.scale
                    radius: 18 * desktopLyrics.scale
                    color: "#FF6B6B"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        font.pixelSize: 18 * desktopLyrics.scale
                        color: "white"
                        font.bold: true
                    }
                }

                // 歌词内容
                Text {
                    id: lyricText
                    text: getLyricText()
                    font.pixelSize: fontSize * desktopLyrics.scale
                    font.bold: true
                    color: textColor
                    anchors.verticalCenter: parent.verticalCenter
                    style: Text.Outline
                    styleColor: "#40000000"
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 500)

                    function getLyricText() {
                        try {
                            return playlistmanager ? playlistmanager.currlyric : "网狗音乐 - 等待播放";
                        } catch (e) {
                            return "网狗音乐";
                        }
                    }
                }
            }
        }

        // 控制面板（鼠标悬停时显示）- 固定在歌词上方
        Row {
            id: controlPanel
            anchors.bottom: background.top
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            opacity: showControls ? 1 : 0
            z: 100  // 确保在 MouseArea 上面

            // 悬停检测 - 保持按钮可见
            HoverHandler {
                id: controlPanelHover
                onHoveredChanged: {
                    if (hovered) {
                        hideControlsTimer.stop();
                        showControls = true;
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
                width: 32
                height: 32
                radius: 16
                color: zoomOutHandler.hovered ? "#40FFFFFF" : "#20FFFFFF"
                visible: !locked

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.pixelSize: 18
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
                        }
                    }
                }
            }

            // 缩放显示（未锁定时显示）
            Rectangle {
                width: 50
                height: 32
                radius: 16
                color: "#20FFFFFF"
                visible: !locked

                Text {
                    anchors.centerIn: parent
                    text: Math.round(desktopLyrics.scale * 100) + "%"
                    font.pixelSize: 12
                    color: "white"
                    font.bold: true
                }
            }

            // 放大按钮（未锁定时显示）
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: zoomInHandler.hovered ? "#40FFFFFF" : "#20FFFFFF"
                visible: !locked

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 18
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
                        }
                    }
                }
            }

            // 分隔线（未锁定时显示）
            Rectangle {
                width: 1
                height: 20
                color: "#40FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                visible: !locked
            }

            // 字体减小（未锁定时显示）
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: fontDownHandler.hovered ? "#40FFFFFF" : "#20FFFFFF"
                visible: !locked

                Image {
                    id: fontDownIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/font_down.png"
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: fontDownIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: fontDownHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.fontSize > 12) {
                            desktopLyrics.fontSize -= 2;
                        }
                    }
                }
            }

            // 字体增大（未锁定时显示）
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: fontUpHandler.hovered ? "#40FFFFFF" : "#20FFFFFF"
                visible: !locked

                Image {
                    id: fontUpIcon
                    anchors.centerIn: parent
                    source: "qrc:/image/font_up.png"
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: fontUpIcon
                        color: "#FFFFFF"
                    }
                }

                HoverHandler {
                    id: fontUpHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        if (desktopLyrics.fontSize < 36) {
                            desktopLyrics.fontSize += 2;
                        }
                    }
                }
            }

            // 分隔线（未锁定时显示）
            Rectangle {
                width: 1
                height: 20
                color: "#40FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                visible: !locked
            }

            // 锁定/解锁按钮（始终显示）
            Rectangle {
                width: locked ? unlockText.width + 24 : 32
                height: 32
                radius: 16
                color: desktopLyrics.locked ? "#FF6B6B" : (lockHandler.hovered ? "#40FFFFFF" : "#20FFFFFF")

                Row {
                    id: lockRow
                    anchors.centerIn: parent
                    spacing: 4

                    Image {
                        id: lockIcon
                        source: desktopLyrics.locked ? "qrc:/image/lock_close.png" : "qrc:/image/lock_open.png"
                        width: 14
                        height: 14
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: lockIcon
                            color: "#FFFFFF"
                        }
                    }

                    Text {
                        id: unlockText
                        text: "解锁"
                        font.pixelSize: 12
                        color: "white"
                        visible: desktopLyrics.locked
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: lockHandler
                }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        desktopLyrics.locked = !desktopLyrics.locked;
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
                    showControls = true;
                } else {
                    hideControlsTimer.restart();
                }
            }
        }

        // 拖动区域（未锁定时）
        MouseArea {
            id: dragMouseArea
            anchors.fill: parent
            enabled: !locked
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true

            onPressed: function (mouse) {
                _dragPos = Qt.point(mouse.x, mouse.y);
                cursorShape = Qt.ClosedHandCursor;
            }
            onReleased: {
                cursorShape = Qt.ArrowCursor;
            }
            onPositionChanged: function (mouse) {
                if ((mouse.buttons & Qt.LeftButton) && !locked) {
                    var newX = desktopLyrics.x + (mouse.x - _dragPos.x);
                    var newY = desktopLyrics.y + (mouse.y - _dragPos.y);

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
                source: locked ? "qrc:/image/lock_close.png" : "qrc:/image/lock_open.png"
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
                text: locked ? "已锁定 - 悬停显示解锁按钮" : "已解锁 - 可拖动调整"
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
