import QtQuick 2.15
import "../BasicConfig"

// 列表行 hover 反馈：整行内容右移 6px（OutBack 回弹）+ 背后一条两端淡出的柔光带。
// 不铺常驻底色，行内原有的文字高亮/播放态逻辑不受影响。
Rectangle {
    id: root

    property bool hovered: false
    // 关掉则不响应 hover 视觉
    property bool interactive: true
    // hover 时内容右移距离（px）
    property real slideDistance: 6
    // 背光开关（某些行自带底色时可视情况关掉）
    property bool backlightEnabled: true

    readonly property bool _active: interactive && hovered

    color: "transparent"

    // 行内容整体右移（transform 只影响本行，不影响布局与其它行）
    transform: Translate {
        x: root._active ? root.slideDistance : 0
        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
    }

    // 背光带：两端淡出，避免出现"方块遮罩"的观感
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        radius: Math.min(height / 2, 18)
        visible: root.backlightEnabled
        opacity: root._active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: AppTheme.animNormal; easing.type: Easing.OutCubic } }

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.075) }
            GradientStop { position: 0.60; color: Qt.rgba(1, 1, 1, 0.05) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
