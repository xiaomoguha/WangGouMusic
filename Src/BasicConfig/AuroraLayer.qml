import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 全局极光层：色团按窗口全局坐标定位，各面板传入自身偏移(panelLeftX/panelTopY)只渲染自己那块，
// 三块拼成整窗一张连续流体底；相位取 BasicConfig.auroraPhase（共享，避免各动各的接缝感）。
Item {
    id: root
    clip: true

    // 本层所在面板左上角在窗口内的坐标
    property real panelLeftX: 0
    property real panelTopY: 0
    property real intensity: 1.0

    readonly property real globalW: Math.max(1, BasicConfig.windowWidth)
    readonly property real globalH: Math.max(1, BasicConfig.windowHeight)
    readonly property real blobSize: Math.max(globalW, globalH) * 1.30
    readonly property real phase: BasicConfig.auroraPhase

    // 一个色团：圆心 = 比例坐标 + 相位驱动的椭圆漫游
    component AuroraBlob: RadialGradient {
        id: blob
        property color tint: "#000000"
        property real fx: 0.2          // 圆心基准位置（窗口比例）
        property real fy: 0.2
        property real wanderX: 0.06    // 漫游幅度（窗口比例）
        property real wanderY: 0.05
        property real speed: 1.0       // 漫游速度倍率
        property real phaseOff: 0      // 相位偏移，错开各团节奏
        property real sizeScale: 1.0
        property real peakAlpha: 0.6

        width: root.blobSize * sizeScale
        height: width
        horizontalRadius: width / 2
        verticalRadius: height / 2

        readonly property real cx: root.globalW * (fx + wanderX * Math.sin(root.phase * 6.28318530718 * speed + phaseOff))
        readonly property real cy: root.globalH * (fy + wanderY * Math.cos(root.phase * 6.28318530718 * speed * 1.23 + phaseOff))

        x: cx - root.panelLeftX - width / 2
        y: cy - root.panelTopY - height / 2

        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.peakAlpha * root.intensity) }
            GradientStop { position: 0.50; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.peakAlpha * 0.38 * root.intensity) }
            GradientStop { position: 1.00; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0) }
        }
    }

    // ===== 四个色团（紫 / 青 / 玫红 / 绿松），各自独立轨道 =====
    AuroraBlob {
        tint: "#3D2A6E"
        fx: 0.20; fy: 0.16; wanderX: 0.10; wanderY: 0.07; speed: 1.00; phaseOff: 0.0; sizeScale: 1.00; peakAlpha: 0.66
    }
    AuroraBlob {
        tint: "#12455C"
        fx: 0.82; fy: 0.44; wanderX: 0.08; wanderY: 0.08; speed: 0.78; phaseOff: 1.7; sizeScale: 0.92; peakAlpha: 0.60
    }
    AuroraBlob {
        tint: "#5C1F3E"
        fx: 0.30; fy: 0.86; wanderX: 0.09; wanderY: 0.06; speed: 1.15; phaseOff: 3.1; sizeScale: 0.80; peakAlpha: 0.52
    }
    AuroraBlob {
        tint: "#2A5C4E"
        fx: 0.74; fy: 0.80; wanderX: 0.07; wanderY: 0.07; speed: 0.92; phaseOff: 4.6; sizeScale: 0.68; peakAlpha: 0.46
    }

    // ===== 中心偏上柔光：内容区的"舞台感"（全局坐标）=====
    RadialGradient {
        width: root.globalW * 0.9
        height: width
        horizontalRadius: width / 2
        verticalRadius: height / 2
        x: root.globalW * 0.5 - root.panelLeftX - width / 2
        y: root.globalH * 0.38 - root.panelTopY - height / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.075) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    // ===== 暗角：四周压暗（全局坐标，按窗口半径计算）=====
    RadialGradient {
        width: Math.max(root.globalW, root.globalH) * 1.44
        height: width
        horizontalRadius: width / 2
        verticalRadius: height / 2
        x: root.globalW * 0.5 - root.panelLeftX - width / 2
        y: root.globalH * 0.5 - root.panelTopY - height / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.58; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.34) }
        }
    }
}
