import QtQuick 2.15
import "../BasicConfig"

// 面板底：纯底色 + 星空层（原来的"封面主色渐变混入"已移除）。
// 文字始终画在不透明层之上，不用半透明覆盖层压内容（避免 macOS 低分辨率合成糊字）。
Rectangle {
    id: root
    anchors.fill: parent

    // 本面板的基础底色（AppTheme token，color 类型）
    property color baseColor: "#000000"
    // 本面板左上角在窗口内的全局坐标（用于星空切片对齐）
    property real panelLeftX: 0
    property real panelTopY: 0

    color: root.baseColor

    StarfieldLayer {
        anchors.fill: parent
        panelLeftX: root.panelLeftX
        panelTopY: root.panelTopY
    }
}
