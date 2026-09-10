import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 发光文字：文字本体 + 同色柔光。
// 容器四周留出 glowRadius 空白给光晕扩散（否则被图层边界裁掉）；效果作用在整个容器上
// （Glow 的输出包含文字本体，不会重影）。
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

    // 是否占满父宽（标题需要 elide 时用；文字两侧留出光晕 padding）
    property bool fillWidth: false

    // 四周预留光晕扩散空间
    readonly property real _pad: glowEnabled ? glowRadius : 0
    implicitWidth: label.implicitWidth + _pad * 2
    implicitHeight: label.implicitHeight + _pad * 2
    width: fillWidth ? parent.width : implicitWidth
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
        width: root.fillWidth ? Math.max(0, parent.width - root._pad * 2) : implicitWidth
        font.family: AppTheme.fontFamily
    }
}
