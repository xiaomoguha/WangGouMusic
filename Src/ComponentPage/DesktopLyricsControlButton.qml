import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 桌面歌词控制按钮：按 scaleFactor 缩放的圆形按钮，支持文字(−/+/横/竖)或图标。
// 取代横版/竖版控制面板里重复的 Rectangle{ Text/Image + HoverHandler + TapHandler } 模板。
// 仅负责展示与点击；缩放/状态/行为由调用方(DesktopLyrics.qml)通过属性与 clicked() 驱动。
Item {
    id: root

    property real scaleFactor: 1.0
    property string label: ""        // 文字内容（与 iconSource 二选一）
    property string iconSource: ""   // 图标资源
    property int pixelSize: AppTheme.fontSizeTitle
    property color normalColor: "#CC333333"
    property color hoverColor: "#EE555555"
    property color textColor: "#FFFFFF"
    property bool animateColor: false   // 播放/锁定/解锁按钮原带 Behavior 渐变；缩放/旋转按钮即时

    readonly property bool hovered: hoverHandler.hovered

    signal clicked()

    width: 28 * root.scaleFactor
    height: 28 * root.scaleFactor

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.hovered ? root.hoverColor : root.normalColor
        Behavior on color {
            enabled: root.animateColor
            ColorAnimation { duration: AppTheme.animFast }
        }

        Text {
            visible: root.label !== ""
            anchors.centerIn: parent
            text: root.label
            font.pixelSize: root.pixelSize * root.scaleFactor
            font.bold: true
            color: root.textColor
        }

        Image {
            id: icon
            visible: root.iconSource !== ""
            anchors.centerIn: parent
            source: root.iconSource
            sourceSize: Qt.size(128, 128)
            mipmap: true
            width: 12 * root.scaleFactor
            height: 12 * root.scaleFactor
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay { source: icon; color: root.textColor }
        }
    }

    HoverHandler { id: hoverHandler }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.clicked()
    }
}
