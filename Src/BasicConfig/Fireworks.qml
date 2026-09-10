import QtQuick 2.15
import "../BasicConfig"

// 点击烟花：在鼠标按下的位置爆开一圈彩色粒子（随机色相、初速 + 重力 + 阻尼 + 渐熄）。
// 粒子用固定大小的池子承载（避免每帧重建 delegate），物理在 JS 里按帧积分；没有粒子时定时器自动停。
// 本层只画粒子、不接收任何鼠标事件（点击照常透传到界面）。
Item {
    id: root

    // 粒子池大小
    property int poolSize: 140
    // 每次爆开的粒子数（参考实现为 46~70）
    property int minBurst: 40
    property int maxBurst: 22

    property var parts: []
    // 每帧自增：驱动 delegate 绑定刷新。用它替代"每帧重建数组"，
    // 否则 140 个粒子节点的绑定会连带数组分配一起爆掉（上一版卡顿的根因）。
    property int frame: 0

    Connections {
        target: cursorTracker
        function onPressed(x, y) {
            root.burst(x, y)
        }
    }

    function burst(cx, cy) {
        var arr = root.parts
        var n = root.minBurst + Math.floor(Math.random() * root.maxBurst)
        var baseHue = Math.random() * 360
        for (var i = 0; i < n && arr.length < root.poolSize; ++i) {
            var ang = Math.random() * Math.PI * 2
            var spd = 1.6 + Math.random() * 5.4
            var hue = (((baseHue + (Math.random() * 70 - 35)) % 360) + 360) % 360
            arr.push({
                "x": cx,
                "y": cy,
                "vx": Math.cos(ang) * spd,
                "vy": Math.sin(ang) * spd,
                "life": 1,
                "decay": 0.010 + Math.random() * 0.016,
                "r": 1.3 + Math.random() * 2.2,
                // 颜色在生成时算好：每帧算 hsla 也是卡顿来源之一
                "color": Qt.hsla(hue / 360, 0.85, 0.64, 1)
            })
        }
        root.frame++
    }

    Timer {
        interval: 16
        repeat: true
        running: root.parts.length > 0

        onTriggered: {
            var arr = root.parts
            var w = 0
            for (var i = 0; i < arr.length; ++i) {
                var p = arr[i]
                p.vy += 0.055        // 重力
                p.vx *= 0.985        // 空气阻尼
                p.vy *= 0.985
                p.x += p.vx
                p.y += p.vy
                p.life -= p.decay
                if (p.life > 0)
                    arr[w++] = p     // 原地压缩，零分配
            }
            arr.length = w
            root.frame++             // 通知 delegate 刷新
        }
    }

    Repeater {
        model: root.poolSize

        delegate: Rectangle {
            required property int index
            readonly property var pt: {
                var _ = root.frame    // 依赖 frame：每帧刷新（不重建数组）
                return index < root.parts.length ? root.parts[index] : null
            }

            visible: pt !== null
            width: pt ? pt.r * 2 : 0
            height: width
            radius: width / 2
            x: pt ? pt.x - width / 2 : 0
            y: pt ? pt.y - height / 2 : 0
            color: pt ? pt.color : "transparent"
            opacity: pt ? Math.max(0, pt.life) : 0
        }
    }
}
