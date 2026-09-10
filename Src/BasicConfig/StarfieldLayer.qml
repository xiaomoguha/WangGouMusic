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
    // 指针在本面板局部坐标里的位置；离开窗口/失焦时视为不在场
    readonly property real curX: cursorTracker.pos.x - root.panelLeftX
    readonly property real curY: cursorTracker.pos.y - root.panelTopY
    readonly property bool curNear: cursorTracker.active
    // 联动半径：指针周围多大范围的星会被点亮、轻轻推开
    property real reactRadius: 140
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
            readonly property real base: 0.62 + root.rand(index, 6.0) * 0.38
            readonly property real size: 1.2 + root.rand(index, 3.0) * 2.2
            readonly property real breath: 0.90 + 0.10 * Math.sin(root.t * (0.30 + root.rand(index, 4.0)) + index)

            // 与指针联动：靠近时变亮 + 被轻轻推开（像被磁力拂过）
            readonly property real bx: sx * root.width
            readonly property real by: sy * root.height
            readonly property real dx: bx - root.curX
            readonly property real dy: by - root.curY
            readonly property real dist: Math.sqrt(dx * dx + dy * dy)
            readonly property real near: root.curNear ? Math.max(0, 1 - dist / root.reactRadius) : 0
            readonly property real push: near * near * 14

            x: bx + (dist > 0.01 ? dx / dist * push : 0)
            y: by + (dist > 0.01 ? dy / dist * push : 0)
            width: size
            height: size
            radius: size / 2
            color: near > 0.5 ? "#E8F1FF" : (index % 9 === 0 ? "#CFE3FF" : "#FFFFFF")
            opacity: Math.min(1, base * env * breath * (1 + near * 1.2))
        }
    }

    // ===== 少量亮星（柔光，撑层次；同样走生命周期）=====
    Repeater {
        model: Math.max(3, Math.round(root.starCount / 10))

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
            opacity: 0.92 * env

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

    // ===== 流星：每次出现都重新随机（时机 / 轨迹 / 长度），避免"固定间隔三个一起冒出来" =====
    Repeater {
        model: root.meteorCount

        delegate: Item {
            id: meteor

            property real angleDeg: 30
            property real dur: 3000
            property real startX: 0
            property real startY: -80
            property real travelX: 0
            property real travelY: 0

            height: 3.8
            width: 200
            rotation: angleDeg
            opacity: 0
            x: startX
            y: startY

            // 重新掷一次：方向、起点、飞多远、飞多久、多长
            function reroll() {
                angleDeg = 24 + Math.random() * 18
                dur = 2600 + Math.random() * 2400
                startX = Math.random() * root.width * 1.2 - root.width * 0.35
                startY = -40 - Math.random() * 90
                var rad = angleDeg * Math.PI / 180
                var dist = Math.max(root.width, root.height) * (0.75 + Math.random() * 0.5)
                travelX = dist * Math.cos(rad)
                travelY = dist * Math.sin(rad)
                width = 190 + Math.random() * 190
                x = startX
                y = startY
                flightAnim.restart()
            }

            Timer {
                // 首次间隔随机；每次触发后再随机下一次间隔（Timer 改 interval 会按新值重排）
                interval: 1500 + Math.random() * 10000
                repeat: true
                running: !BasicConfig.uiIdle
                onTriggered: {
                    interval = 1800 + Math.random() * 12000
                    meteor.reroll()
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.70; color: Qt.rgba(1, 1, 1, 0.50) }
                    GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 1.0) }
                }
            }

            // 头部：更粗更亮的实心核 + 一圈柔光（尾迹的收束点）
            Item {
                width: 17
                height: 17
                x: parent.width - width / 2 + 2
                anchors.verticalCenter: parent.verticalCenter

                RadialGradient {
                    anchors.fill: parent
                    horizontalRadius: width / 2
                    verticalRadius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 1.0) }
                        GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.45) }
                        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }
            }

            ParallelAnimation {
                id: flightAnim
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
