import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 星空背景层：黑底 + 稀疏星点 + 偶尔划过的流星。
// 星点有自己的"生命"：在一个 30~100 秒的周期里缓慢亮起再暗掉，暗掉时已在别处点起新的一颗
// （位置由生命周期序号哈希决定，切换发生在亮度≈0 的瞬间，肉眼察觉不到）。
// 所有随机量都是 index 哈希出的确定值——窗口缩放/面板重排不会让星点乱跳。
// 时间基准 BasicConfig.bgTime（秒，单调递增，失焦即停）。
Item {
    id: root
    clip: true

    property real panelLeftX: 0
    property real panelTopY: 0

    readonly property real t: BasicConfig.bgTime
    // 星点密度：整体偏稀疏（流星才是主角）
    readonly property int starCount: Math.max(6, Math.round(width * height / 12000))
    // 流星条数：小面板也保证 1 条，最多 2 条
    readonly property int meteorCount: Math.max(1, Math.min(2, Math.round(width * height / 260000)))

    function rand(i, salt) {
        var v = Math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
        return v - Math.floor(v)
    }

    // ===== 星点：缓慢明灭 + 熄灭后换位置重生 =====
    Repeater {
        model: root.starCount

        delegate: Rectangle {
            readonly property real lifeSec: 30 + root.rand(index, 9.0) * 70
            readonly property real lifeRaw: root.t / lifeSec + root.rand(index, 10.0)
            readonly property real lifePos: lifeRaw - Math.floor(lifeRaw)
            readonly property real gen: Math.floor(lifeRaw)
            // 各用 28% 周期渐变亮起/暗下，中间平稳——速度极慢，不留意察觉不到
            readonly property real env: Math.max(0, Math.min(1, Math.min(lifePos / 0.28, (1 - lifePos) / 0.28)))
            readonly property real sx: root.rand(index + gen * 977, 1.0)
            readonly property real sy: root.rand(index + gen * 977, 2.0)
            readonly property real base: 0.45 + root.rand(index, 6.0) * 0.45
            readonly property real size: 1.0 + root.rand(index, 3.0) * 2.0
            readonly property real breath: 0.90 + 0.10 * Math.sin(root.t * (0.30 + root.rand(index, 4.0)) + index)

            x: sx * root.width
            y: sy * root.height
            width: size
            height: size
            radius: size / 2
            color: index % 9 === 0 ? "#CFE3FF" : "#FFFFFF"
            opacity: base * env * breath
        }
    }

    // ===== 少量亮星（柔光，撑层次；同样走生命周期）=====
    Repeater {
        model: Math.max(2, Math.round(root.starCount / 12))

        delegate: Item {
            readonly property real lifeSec: 50 + root.rand(index, 59.0) * 90
            readonly property real lifeRaw: root.t / lifeSec + root.rand(index, 60.0)
            readonly property real lifePos: lifeRaw - Math.floor(lifeRaw)
            readonly property real gen: Math.floor(lifeRaw)
            readonly property real env: Math.max(0, Math.min(1, Math.min(lifePos / 0.30, (1 - lifePos) / 0.30)))
            readonly property real size: 3.5 + root.rand(index, 33.0) * 2.5

            width: size * 4
            height: width
            x: root.rand(index + gen * 613, 31.0) * root.width - width / 2
            y: root.rand(index + gen * 613, 32.0) * root.height - height / 2
            opacity: 0.75 * env

            RadialGradient {
                anchors.fill: parent
                horizontalRadius: width / 2
                verticalRadius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.80) }
                    GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }

    // ===== 流星：斜向缓慢划过，方向严格沿拖尾角度 =====
    Repeater {
        model: root.meteorCount

        delegate: Item {
            id: meteor

            // 拖尾角度：既决定条形朝向，也决定飞行方向（否则会出现"竖着掉"）
            readonly property real angleDeg: 26 + root.rand(index, 48.0) * 16
            readonly property real angleRad: angleDeg * Math.PI / 180
            readonly property real dur: 3200 + root.rand(index, 41.0) * 2000
            readonly property real pause: 4000 + root.rand(index, 42.0) * 9000
            // 起点在面板上方、横向铺开；沿角度方向飞一段刚好穿过可视区
            readonly property real startX: root.rand(index, 43.0) * root.width * 1.2 - root.width * 0.35
            readonly property real startY: -40 - root.rand(index, 44.0) * 90
            readonly property real travelDist: Math.max(root.width, root.height) * (0.75 + root.rand(index, 45.0) * 0.45)
            readonly property real travelX: travelDist * Math.cos(angleRad)
            readonly property real travelY: travelDist * Math.sin(angleRad)

            width: 110 + root.rand(index, 47.0) * 130
            height: 2.5
            rotation: angleDeg
            x: startX
            y: startY
            opacity: 0

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.70; color: Qt.rgba(1, 1, 1, 0.38) }
                    GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.95) }
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite
                running: !BasicConfig.uiIdle

                PauseAnimation { duration: meteor.pause }
                ParallelAnimation {
                    NumberAnimation {
                        target: meteor; property: "x"
                        from: meteor.startX; to: meteor.startX + meteor.travelX
                        duration: meteor.dur; easing.type: Easing.Linear
                    }
                    NumberAnimation {
                        target: meteor; property: "y"
                        from: meteor.startY; to: meteor.startY + meteor.travelY
                        duration: meteor.dur; easing.type: Easing.Linear
                    }
                    SequentialAnimation {
                        NumberAnimation { target: meteor; property: "opacity"; from: 0; to: 1; duration: meteor.dur * 0.15 }
                        NumberAnimation { target: meteor; property: "opacity"; to: 0; duration: meteor.dur * 0.85 }
                    }
                }
            }
        }
    }

    // ===== 微弱星云：给黑底一点深度 =====
    RadialGradient {
        width: root.width * 1.6
        height: width
        horizontalRadius: width / 2
        verticalRadius: height / 2
        x: root.width * 0.5 - width / 2
        y: root.height * 0.35 - height / 2
        opacity: 0.55
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(0.35, 0.42, 0.75, 0.09) }
            GradientStop { position: 0.55; color: Qt.rgba(0.30, 0.32, 0.55, 0.05) }
            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0) }
        }
    }
}
