import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// Folia 风格发光文字：文字本体 + 同色柔光（Glow）。
// 关键点：容器四周留出 glowRadius 的空白，光晕才有扩散空间、不会被图层边界裁掉；
// 效果作用在整个容器上（Glow 的输出包含文字本体，因此不会出现重影）。
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias elide: label.elide
    property alias horizontalAlignment: label.horizontalAlignment
    property alias verticalAlignment: label.verticalAlignment
    property alias wrapMode: label.wrapMode
    property alias maximumLineCount: label.maximumLineCount
    property alias lineHeight: label.lineHeight
    property alias style: label.style
    property alias styleColor: label.styleColor

    // 光晕参数
    property color glowColor: Qt.rgba(color.r, color.g, color.b, 0.55)
    property real glowRadius: 12
    property int glowSamples: 25
    property real glowSpread: 0.10
    property bool glowEnabled: true

    // 四周预留光晕扩散空间
    readonly property real _pad: glowEnabled ? glowRadius : 0
    implicitWidth: label.implicitWidth + _pad * 2
    implicitHeight: label.implicitHeight + _pad * 2
    width: implicitWidth
    height: implicitHeight

    layer.enabled: root.glowEnabled
    layer.effect: Glow {
        radius: root.glowRadius
        samples: root.glowSamples
        spread: root.glowSpread
        color: root.glowColor
        transparentBorder: true
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: AppTheme.fontFamily
    }
}
