import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 卡片 hover 反馈（无常驻底板、无玻璃壳）：
//   hover 时整卡被"提起"——上浮 8px + 放大 1.06（都带 OutBack 回弹），
//   同时在卡片背后垫一团无边界柔光把这块"点亮"（深色底上投影不可见，柔光才有效）。
//   内容层（封面 / 歌名 / 歌手）保持原样，不铺任何面板。
Rectangle {
    id: root

    property bool hovered: false
    // 关闭后不响应 hover 视觉（纯装饰容器用）
    property bool interactive: true
    // hover 时放大倍数
    property real hoverScale: 1.06
    // hover 时上浮距离（px）
    property real liftDistance: 8

    readonly property bool _active: interactive && hovered

    color: "transparent"
    radius: AppTheme.radiusLarge

    // 提起：先上浮、再回弹一点（OutBack），像被手指拈起来
    transform: Translate {
        y: root._active ? -root.liftDistance : 0
        Behavior on y {
            NumberAnimation {
                duration: 230
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.25
        }
    }
    scale: root._active ? root.hoverScale : 1.0

    // 背光：一团没有边界的柔光，hover 时把卡片这块"点亮"（深色主题下比投影有效得多）
    RadialGradient {
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height) * 2.0
        height: width
        horizontalRadius: width / 2
        verticalRadius: height / 2
        opacity: root._active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: AppTheme.animNormal; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, AppTheme.isDark ? 0.11 : 0.18) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, AppTheme.isDark ? 0.045 : 0.07) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

}
