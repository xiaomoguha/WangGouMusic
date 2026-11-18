import QtQuick
import "."

// 正在播放指示器：三根跳动的声波条（参考 QQ 音乐）。
Item
{
    id: root

    property color barColor: MTheme.accent

    width: 16
    height: 14

    Repeater {
        model: 3

        Rectangle {
            id: bar

            required property int index

            x: index * 6
            anchors.bottom: parent.bottom
            width: 3
            radius: 1.5
            color: root.barColor
            height: 14

            SequentialAnimation on height {
                loops: Animation.Infinite
                paused: !root.visible
                NumberAnimation { to: 5; duration: 360 + bar.index * 110; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 14; duration: 460 - bar.index * 80; easing.type: Easing.InOutQuad }
            }
        }
    }
}
