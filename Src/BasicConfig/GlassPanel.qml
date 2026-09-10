import QtQuick 2.15
import "../BasicConfig"

// 静态毛玻璃面板：半透明填充 + 顶部受光高光 + 极细描边。
// 与 GlassCard 的区别：不带 hover 动效，用于弹层 / 设置卡片这类常驻表面。
Rectangle {
    id: root

    // 面板底色（默认暗色半透明玻璃）
    property color glassTopColor: Qt.rgba(1, 1, 1, 0.055)
    property color glassBottomColor: Qt.rgba(1, 1, 1, 0.022)
    property color glassBorderColor: Qt.rgba(1, 1, 1, 0.12)

    radius: AppTheme.radiusLarge
    color: root.glassBottomColor
    border.width: 1
    border.color: root.glassBorderColor

    // 顶部受光：一条自上而下淡出的白边
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.glassTopColor }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }
}
