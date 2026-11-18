import QtQuick 2.15
import QtQuick.Effects

// 单色 SVG 图标 + 主题着色。
Item
{
    id: root

    property string source: ""
    property color color: "#FFFFFF"

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        // SVG 按显示尺寸栅格化，任意 DPI 下锐利
        sourceSize: Qt.size(Math.max(1, Math.ceil(width)), Math.max(1, Math.ceil(height)))
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.color
    }
}
