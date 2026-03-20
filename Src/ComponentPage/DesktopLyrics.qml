import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: desktopLyrics
    objectName: "desktopLyrics"
    width: 600
    height: 100
    visible: true
    color: "transparent"

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool

    // 初始化位置
    x: (Screen.desktopAvailableWidth - width) / 2
    y: Screen.desktopAvailableHeight - height - 40 // 40是状态栏高度的估计值

    Component.onCompleted: {
        // 更精确地定位到状态栏上方
        positionAboveTaskbar();
    }

    // 精确计算状态栏位置的方法
    function positionAboveTaskbar() {
        // 计算屏幕中心水平位置
        var screenCenterX = Screen.desktopAvailableWidth / 2 - width / 2;

        // 计算状态栏上方的垂直位置
        // 使用Screen.height获取屏幕总高度，Screen.desktopAvailableHeight获取可用高度
        var taskbarHeight = Screen.height - Screen.desktopAvailableHeight;

        // 设置窗口位置
        x = screenCenterX;
        y = Screen.desktopAvailableHeight - height;
    }

    property point _dragPos: Qt.point(0, 0)

    property color textColor: "white"
    property int fontSize: 20
    property real panelOpacity: 0.9
    property bool locked: false

    // 拖动
    MouseArea {
        id: mousearea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: function (mouse) {
            if (!locked) {
                _dragPos = Qt.point(mouse.x, mouse.y);
                cursorShape = Qt.ClosedHandCursor;
            }
        }
        onReleased: {
            cursorShape = Qt.ArrowCursor;
        }

        onPositionChanged: function (mouse) {
            if ((!locked) && (mouse.buttons & Qt.LeftButton)) {
                // 使用Screen.height获取屏幕总高度，Screen.desktopAvailableHeight获取可用高度
                var taskbarHeight = Screen.height - Screen.desktopAvailableHeight;
                var newX = desktopLyrics.x + (mouse.x - _dragPos.x);
                var newY = desktopLyrics.y + (mouse.y - _dragPos.y);

                // 获取屏幕边界
                var screen = Screen;
                var screenLeft = screen.virtualX;
                var screenTop = screen.virtualY;
                var screenRight = screenLeft + screen.width;
                var screenBottom = screenTop + screen.height;

                // 允许窗口大部分超出屏幕，只保留最小可见区域（50px）
                var minVisible = 50;

                // 边界检查 - 允许移动到边缘
                if (newX > screenRight - minVisible) {
                    newX = screenRight - minVisible;
                } else if (newX + desktopLyrics.width - minVisible < screenLeft) {
                    newX = screenLeft - desktopLyrics.width + minVisible;
                }

                if (newY > screenBottom - taskbarHeight - minVisible) {
                    newY = screenBottom - taskbarHeight - minVisible;
                } else if (newY + desktopLyrics.height - minVisible < screenTop) {
                    newY = screenTop - desktopLyrics.height + minVisible;
                }

                // 应用新位置
                desktopLyrics.x = newX;
                desktopLyrics.y = newY;
            }
        }
        // 鼠标进入区域时触发
        onEntered: {
            background.opacity = panelOpacity;  // 显示背景
        }

        // 鼠标离开区域时触发
        onExited: {
            background.opacity = 0;  // 隐藏背景（完全透明）
        }
    }

    // 歌词容器 - 包含背景和歌词
    Item {
        id: lyricContainer
        anchors.centerIn: parent
        // 容器大小根据歌词实际渲染尺寸计算
        width: lyricText.contentWidth + 40
        height: lyricText.contentHeight + 30

        // 背景板 - 填充容器
        Rectangle {
            id: background
            anchors.fill: parent
            radius: 14
            color: "#66000000"
            border.color: "#88FFFFFF"
            border.width: 1
            opacity: 0
            // 添加平滑过渡效果
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        // 当前行歌词
        Text {
            id: lyricText
            anchors.centerIn: parent
            text: getLyricText()
            font.pixelSize: fontSize
            font.bold: true
            color: textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            // 限制最大宽度，超出会换行
            width: Math.min(implicitWidth, 800)
            style: Text.Outline
            styleColor: "black"

            function getLyricText() {
                try {
                    return playlistmanager ? playlistmanager.currlyric : "网狗音乐";
                } catch (e) {
                    return "网狗音乐";
                }
            }
        }
    }

    // 控制按钮栏
    Row {
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        // 字体增大按钮
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: fontUpMouseArea.containsMouse ? "#40FFFFFF" : "transparent"
            visible: (!desktopLyrics.locked) && (mousearea.containsMouse)

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

            MouseArea {
                id: fontUpMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (desktopLyrics.fontSize < 40) {
                        desktopLyrics.fontSize += 1;
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 字体减小按钮
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: fontDownMouseArea.containsMouse ? "#40FFFFFF" : "transparent"
            visible: (!desktopLyrics.locked) && (mousearea.containsMouse)

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

            MouseArea {
                id: fontDownMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (desktopLyrics.fontSize > 10) {
                        desktopLyrics.fontSize -= 1;
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // 锁定按钮
        Rectangle {
            id: lockBtn
            width: 28
            height: 28
            radius: 14
            color: lockMouseArea.containsMouse ? "#40FFFFFF" : "transparent"

            Image {
                id: lockImage
                anchors.centerIn: parent
                source: desktopLyrics.locked ? "qrc:/image/lock_close.png" : "qrc:/image/lock_open.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: lockImage
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: lockMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
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
}
