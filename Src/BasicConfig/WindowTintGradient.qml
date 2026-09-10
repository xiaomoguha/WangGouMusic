import QtQuick 2.15
import "../BasicConfig"

// 面板底：三层合成，保证「整窗一张连续、会动的底」且文字始终画在不透明层之上
// （沿用原设计原则：不靠半透明覆盖层压在内容上，避免 macOS 低分辨率合成糊字）。
//   ① 底色      —— baseColor，不透明
//   ② 极光切片  —— 按窗口全局坐标绘制的流体色团（各面板拼成整窗一张，见 AuroraLayer）
//   ③ 封面主色  —— 歌单封面主色按全局纵向位置以「透明度渐变」混入
//                  （等价于原 mixTint 的混合结果，但保留下层极光可透出）
Rectangle {
    id: root
    anchors.fill: parent

    // 本面板无渐变时应显示的基础底色（AppTheme token，color 类型）
    property color baseColor: "#000000"
    // 本面板左上角在窗口内的全局坐标（用于极光切片对齐）
    property real panelLeftX: 0
    property real panelTopY: 0

    // 渐变在整窗 50% 高度处完全淡出
    readonly property real fadeY: Math.max(1, BasicConfig.windowHeight * 0.5)
    // 面板顶部的混入强度：窗口顶 0.5 → 淡出线处 0
    readonly property real topAlpha: Math.max(0, 0.5 * (1 - root.panelTopY / root.fadeY))
    // 面板内「完全还原为底色」的位置（淡出线以下整段都是底色）
    readonly property real basePos: Math.max(0, Math.min(1, (root.fadeY - root.panelTopY) / root.height))
    // 封面主色（空值按透明处理，避免取分量报错）
    readonly property color coverTint: BasicConfig.playlistCoverColor === "" ? "transparent" : BasicConfig.playlistCoverColor

    // ① 底色
    color: root.baseColor

    // ② 极光切片
    AuroraLayer {
        anchors.fill: parent
        panelLeftX: root.panelLeftX
        panelTopY: root.panelTopY
    }

    // ③ 封面主色渐变
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.coverTint.r, root.coverTint.g, root.coverTint.b, root.topAlpha)
                Behavior on color { ColorAnimation { duration: AppTheme.animThemeTransition } }
            }
            GradientStop {
                position: root.basePos
                color: Qt.rgba(root.coverTint.r, root.coverTint.g, root.coverTint.b, 0)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root.coverTint.r, root.coverTint.g, root.coverTint.b, 0)
            }
        }
    }
}
