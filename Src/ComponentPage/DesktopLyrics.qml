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
        positionAboveTaskbar()
    }

    // 精确计算状态栏位置的方法
    function positionAboveTaskbar() {
        // 计算屏幕中心水平位置
        var screenCenterX = Screen.desktopAvailableWidth / 2 - width / 2

        // 计算状态栏上方的垂直位置
        // 使用Screen.height获取屏幕总高度，Screen.desktopAvailableHeight获取可用高度
        var taskbarHeight = Screen.height - Screen.desktopAvailableHeight

        // 设置窗口位置
        x = screenCenterX
        y = Screen.desktopAvailableHeight - height
    }

    property point _dragPos: Qt.point(0,0)

    property color textColor: "white"
    property int fontSize: 28
    property real panelOpacity: 0.9
    property bool locked: false

    // 拖动
    MouseArea {
        id:mousearea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: function(mouse) {
            if(!locked)
            {
                _dragPos = Qt.point(mouse.x, mouse.y)
                cursorShape = Qt.ClosedHandCursor
            }
        }
        onReleased: {
            cursorShape = Qt.ArrowCursor
        }

        onPositionChanged: function(mouse) {
            if((!locked)&&(mouse.buttons & Qt.LeftButton))
            {
                // 使用Screen.height获取屏幕总高度，Screen.desktopAvailableHeight获取可用高度
                var taskbarHeight = Screen.height - Screen.desktopAvailableHeight
                var newX = desktopLyrics.x + (mouse.x - _dragPos.x)
                var newY = desktopLyrics.y + (mouse.y - _dragPos.y)

                // 获取屏幕边界
                var screen = Screen
                var screenLeft = screen.virtualX
                var screenTop = screen.virtualY
                var screenRight = screenLeft + screen.width
                var screenBottom = screenTop + screen.height

                // 边界检查
                if (newX < screenLeft) {
                    newX = screenLeft
                } else if (newX + desktopLyrics.width > screenRight) {
                    newX = screenRight - desktopLyrics.width
                }

                if (newY < screenTop) {
                    newY = screenTop
                } else if (newY + desktopLyrics.height > screenBottom - taskbarHeight) {
                    newY = screenBottom - desktopLyrics.height - taskbarHeight
                }

                // 应用新位置
                desktopLyrics.x = newX
                desktopLyrics.y = newY
            }
        }
        // 鼠标进入区域时触发
        onEntered: {
            background.opacity = panelOpacity  // 显示背景
        }

        // 鼠标离开区域时触发
        onExited: {
            background.opacity = 0  // 隐藏背景（完全透明）
        }
    }

    // 背景板
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
            NumberAnimation { duration: 200 }  // 200毫秒的淡入淡出效果
        }
    }
    Row{
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        Image {
            width: 18
            height: 18
            source: "qrc:/image/font_up.png"
            visible: (!desktopLyrics.locked)&&(mousearea.containsMouse)
            MouseArea
            {
                anchors.fill: parent
                onClicked: {
                    if(desktopLyrics.fontSize < 40)
                    {
                        desktopLyrics.fontSize += 1;
                    }
                }
            }
        }
        Image {
            width: 18
            height: 18
            source: "qrc:/image/font_down.png"
            visible: (!desktopLyrics.locked)&&(mousearea.containsMouse)
            MouseArea
            {
                anchors.fill: parent
                onClicked: {
                    if(desktopLyrics.fontSize > 10)
                    {
                        desktopLyrics.fontSize -= 1;
                    }
                }
            }
        }
        Image {
            width: 18
            height: 18
            source: "qrc:/image/lock_open.png"
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    if(desktopLyrics.locked)
                    {
                        desktopLyrics.locked = !(desktopLyrics.locked);
                        parent.source = "qrc:/image/lock_open.png";
                    }
                    else
                    {
                        desktopLyrics.locked = !(desktopLyrics.locked);
                        parent.source = "qrc:/image/lock_close.png";
                    }
                }
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
        width: parent.width - 20
        style: Text.Outline // 设置样式为描边
        styleColor: "black" // 设置描边的颜色
        function getLyricText() {
            try {
                return playlistmanager ? playlistmanager.currlyric : "网狗音乐"
            } catch (e)
            {
                return "网狗音乐"
            }
        }
    }
}
