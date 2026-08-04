import QtQuick 2.15
import "../BasicConfig"

// 全窗口统一顶部渐变的一个面板切片：把歌单封面主色按**全局纵向位置**
// 混入本面板底色，产出纯不透明渐变。三个面板（左栏/内容区/底部栏）
// 各放一个，用同一套全局坐标算法，合起来就是整窗一条连续渐变。
//
// 为什么不直接用半透明覆盖层压在最上层：macOS 下半透明 item 覆盖文字
// 会触发低分辨率合成，内容发糊。混入底色后每个像素都是最终不透明色，
// 内容仍画在最上层，天然清晰。
Rectangle {
    id: root
    anchors.fill: parent

    // 本面板无渐变时应显示的基础底色（AppTheme token，color 类型）
    property color baseColor: "#000000"
    // 本面板顶部在窗口内的全局 Y 坐标（0 = 窗口顶）
    property real panelTopY: 0

    // 渐变在整窗 50% 高度处完全淡出
    readonly property real fadeY: Math.max(1, BasicConfig.windowHeight * 0.5)
    // 面板顶部的混入强度：窗口顶 0.5 → 淡出线处 0
    readonly property real topAlpha: Math.max(0, 0.5 * (1 - root.panelTopY / root.fadeY))
    // 面板内「完全还原为底色」的位置（淡出线以下整段都是底色）
    readonly property real basePos: Math.max(0, Math.min(1, (root.fadeY - root.panelTopY) / root.height))

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop {
            position: 0.0
            color: BasicConfig.mixTint(BasicConfig.playlistCoverColor, root.baseColor, root.topAlpha)
            Behavior on color { ColorAnimation { duration: AppTheme.animThemeTransition } }
        }
        GradientStop {
            position: root.basePos
            color: BasicConfig.mixTint(BasicConfig.playlistCoverColor, root.baseColor, 0.0)
            Behavior on color { ColorAnimation { duration: AppTheme.animThemeTransition } }
        }
        GradientStop {
            position: 1.0
            color: BasicConfig.mixTint(BasicConfig.playlistCoverColor, root.baseColor, 0.0)
            Behavior on color { ColorAnimation { duration: AppTheme.animThemeTransition } }
        }
    }
}
