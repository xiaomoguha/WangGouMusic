import QtQuick 2.15
import "../BasicConfig"

// 点击烟花：线条绽放（每朵由若干"会弯的拖尾"组成）。
//
// 真实感的三个要点：
//   ① 每条拖尾沿抛物线取若干采样点连成折线 → 是"弯的"，不是一根会翻面的硬杠；
//   ② 每条线初速/寿命都不同 → 炸开是不规则的壳，错开消隐；
//   ③ 空气阻尼 + 重力（y 轴向下为正）：先减速，再被重力接管，末端垂落。
Item {
    id: root

    property int lineCount: 26
    property real speed: 260        // 初速上限（px/s，每条线在 55%~140% 之间）
    property real gravity: 760      // 重力（px/s²）
    property real drag: 2.4         // 空气阻尼（1/s）
    property real duration: 1.35    // 一次绽放总时长（秒）
    property int tailSegments: 5    // 每条拖尾的采样段数（越多越顺滑）

    property real phase: 0
    property real cx: 0
    property real cy: 0

    visible: phase > 0.001 && phase < 0.999

    function rand(i, salt) {
        var v = Math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
        return v - Math.floor(v)
    }

    Repeater {
        model: root.lineCount

        delegate: Item {
            id: line

            readonly property real ang: (index + root.rand(index, 3.0) * 0.75) / root.lineCount * Math.PI * 2
            readonly property real v0: root.speed * (0.55 + root.rand(index, 1.0) * 0.85)
            readonly property real lifeSec: 0.72 + root.rand(index, 7.0) * 0.55
            readonly property real k: root.drag
            readonly property real g: root.gravity
            readonly property real v0x: Math.cos(ang) * v0
            readonly property real v0y: Math.sin(ang) * v0

            readonly property real t: root.phase * root.duration
            readonly property real p: Math.min(1, t / lifeSec)
            readonly property real fade: Math.min(1, (1 - p) * 1.8)

            // 线性阻尼解析解（y 向下为正）：v(t) = (v0 - g/k)e^{-kt} + g/k
            function posX(tt) {
                var d = Math.exp(-k * tt)
                return root.cx + v0x * (1 - d) / k
            }
            function posY(tt) {
                var d = Math.exp(-k * tt)
                return root.cy + (g / k) * tt + (v0y - g / k) * (1 - d) / k
            }

            Repeater {
                model: root.tailSegments

                delegate: Rectangle {
                    required property int index    // 0 = 头部

                    readonly property real dt: 0.045
                    readonly property real t0: Math.max(0, line.t - index * dt)
                    readonly property real t1: Math.max(0, line.t - (index + 1) * dt)
                    readonly property real x0: line.posX(t0)
                    readonly property real y0: line.posY(t0)
                    readonly property real x1: line.posX(t1)
                    readonly property real y1: line.posY(t1)
                    readonly property real ddx: x0 - x1
                    readonly property real ddy: y0 - y1

                    // 沿拖尾逐段变细变淡（头部最实）
                    readonly property real tailFade: 1 - index / root.tailSegments

                    width: Math.max(0.8, 2.0 - index * 0.28)
                    height: Math.max(1.5, Math.sqrt(ddx * ddx + ddy * ddy) + 1.2)   // 稍微重叠 → 连成曲线
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.92 * line.fade * tailFade)
                    x: (x0 + x1) / 2 - width / 2
                    y: (y0 + y1) / 2 - height / 2
                    rotation: Math.atan2(ddy, ddx) * 180 / Math.PI + 90
                }
            }
        }
    }

    NumberAnimation {
        id: burstAnim
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.duration * 1000
        easing.type: Easing.Linear
    }

    Connections {
        target: cursorTracker
        function onPressed(x, y) {
            root.cx = x
            root.cy = y
            burstAnim.restart()
        }
    }
}
