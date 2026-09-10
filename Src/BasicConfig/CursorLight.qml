import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 鼠标光标光源：比指针略大的亮斑 + 环绕微粒 + 沿真实路径的流线拖尾。
// 拖尾三要素：位置滞后 70ms（跟手不硬贴）、trailEnergy 由速度驱动（映射迟钝、停下自动收尾）、
// 尾迹沿真实路径采样（≥3px 一点）所以会跟着轨迹拐弯；粒子挂更滞后的锚点被"甩"在后面。
Item {
    id: root

    property bool enabled: true
    property real lightDiameter: 86
    property int moteCount: 14
    // 尾迹采样点数（决定尾巴最长有多长）
    property int trailPoints: 12
    // 尾迹强度倍率（0 = 关闭拖尾）
    property real trailGain: 1.25

    // 指针位置来自 C++ 系统级追踪（cursorTracker）。
    // 注意：本层铺满窗口且位于最上层，**不能**挂 HoverHandler——那会独占 hover 事件，
    // 把下层卡片/导航的 hover 动效全部挡掉（实测到的问题）。
    readonly property bool active: enabled && cursorTracker.active
    readonly property point ppos: cursorTracker.pos

    // ===== 运动状态 =====
    property real speed: 0          // 平滑速度（px/帧）
    property real heading: 0        // 运动朝向（度），停下时保持不变
    property real trailEnergy: 0    // 拖尾能量 0~1（上升快、回落慢）
    property var history: []        // 沿路径的采样点（尾迹用）

    property real _lastX: 0
    property real _lastY: 0
    property real _velX: 0
    property real _velY: 0

    Timer {
        interval: 16
        repeat: true
        running: root.active && !BasicConfig.uiIdle

        onTriggered: {
            var px = root.ppos.x
            var py = root.ppos.y

            var dx = px - root._lastX
            var dy = py - root._lastY
            root._lastX = px
            root._lastY = py

            // 平滑速度（指数滤波，避免抖动）
            root._velX = root._velX * 0.70 + dx * 0.30
            root._velY = root._velY * 0.70 + dy * 0.30
            root.speed = Math.sqrt(root._velX * root._velX + root._velY * root._velY)
            if (root.speed > 1.0)
                root.heading = Math.atan2(root._velY, root._velX) * 180 / Math.PI

            // 拖尾能量：跟速度挂钩但映射迟钝（speed/16 封顶），上升快回落慢
            var target = Math.min(1, root.speed / 16) * root.trailGain
            root.trailEnergy = (target > root.trailEnergy)
                ? root.trailEnergy + (target - root.trailEnergy) * 0.55
                : root.trailEnergy * 0.90

            // 路径采样：位移 ≥3px 才记一个点（点距均匀 → 尾迹是顺滑流线而非一串珠子）
            var h = root.history
            if (h.length === 0) {
                h = [{ "x": px, "y": py }]
            } else {
                var head = h[0]
                var mdx = px - head.x
                var mdy = py - head.y
                if (mdx * mdx + mdy * mdy >= 9) {
                    h = h.slice(0, root.trailPoints - 1)
                    h.unshift({ "x": px, "y": py })
                } else if (h.length > 1) {
                    h = h.slice(0)
                    h[0] = { "x": px, "y": py }
                }
            }
            root.history = h
        }

        onRunningChanged: {
            if (!running) {
                root._velX = 0
                root._velY = 0
                root.speed = 0
                root.trailEnergy = 0
                root.history = []
            }
        }
    }

    // ===== ① 光斑本体 =====
    Item {
        id: origin
        width: 1
        height: 1
        visible: opacity > 0.01
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        x: root.ppos.x
        y: root.ppos.y
        Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }

        rotation: root.heading
        Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        // 核心：沿运动方向轻微拉伸（收敛版，只做"被带着走"的暗示）
        RadialGradient {
            id: coreGlow
            width: root.lightDiameter
            height: width
            horizontalRadius: width / 2
            verticalRadius: height / 2
            x: -width / 2 - width * 0.05 * root.trailEnergy
            y: -height / 2
            transform: Scale {
                origin.x: coreGlow.width / 2
                origin.y: coreGlow.height / 2
                xScale: 1 + 0.30 * root.trailEnergy
                yScale: 1 - 0.10 * root.trailEnergy
            }
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.62) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    // ===== ② 尾迹：沿真实路径的渐隐光点链（会跟着轨迹拐弯）=====
    Repeater {
        model: root.trailPoints

        delegate: RadialGradient {
            readonly property var pt: (index < root.history.length) ? root.history[index] : null
            readonly property real t: index / Math.max(1, root.trailPoints - 1)
            // 柔和的渐变光点：互相叠加后是连续流光，而不是一串硬边珠子
            readonly property real peak: 0.48 * Math.pow(1 - t, 1.5) * root.trailEnergy

            width: root.lightDiameter * (0.60 - 0.46 * t)
            height: width
            horizontalRadius: width / 2
            verticalRadius: height / 2
            visible: pt !== null && root.trailEnergy > 0.04
            x: (pt ? pt.x : 0) - width / 2
            y: (pt ? pt.y : 0) - height / 2

            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, peak) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, peak * 0.35) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    // ===== ③ 粒子：挂在更滞后的锚点上，随拖尾能量轻轻散开 =====
    Item {
        id: moteAnchor
        width: 1
        height: 1
        visible: opacity > 0.01
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        x: origin.x
        y: origin.y
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        property real phase: 0
        NumberAnimation on phase {
            from: 0
            to: 6.283185307179586
            duration: 6400
            loops: Animation.Infinite
            running: root.active && !BasicConfig.uiIdle
        }

        readonly property real backX: -Math.cos(root.heading * Math.PI / 180)
        readonly property real backY: -Math.sin(root.heading * Math.PI / 180)

        Repeater {
            model: root.moteCount

            delegate: Item {
                id: mote

                readonly property real orbit: root.lightDiameter * 0.42 + (index % 5) * (root.lightDiameter * 0.16)
                readonly property real speedFactor: 0.5 + (index % 3) * 0.32
                readonly property real phaseOff: index * 1.9
                readonly property real twinkle: Math.abs(Math.sin(moteAnchor.phase * (0.7 + (index % 4) * 0.33) + index * 1.3))
                // 被拖拽的散开量（比之前轻得多，只是"被带着走"的感觉）
                readonly property real dragOut: root.trailEnergy * (6 + (index % 5) * 5)

                width: 2 + (index % 3)
                height: width

                x: (root.lightDiameter / 2) + orbit * Math.cos(moteAnchor.phase * speedFactor + phaseOff) - width / 2
                   + moteAnchor.backX * dragOut
                y: (root.lightDiameter / 2) + orbit * Math.sin(moteAnchor.phase * speedFactor + phaseOff) * 0.85 - height / 2
                   + moteAnchor.backY * dragOut

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: (index % 4 === 0) ? AppTheme.accent : "#FFFFFF"
                    opacity: 0.10 + 0.55 * mote.twinkle
                }
            }
        }
    }
}
