import QtQuick 2.15
import QtQuick.Particles 2.15
import "../BasicConfig"

// 点击烟花：在鼠标按下位置爆开一圈彩色粒子。
// 用 Qt 内置粒子系统（GPU 粒子）：比手写 JS 粒子池稳、也更流畅——上一版手写池在 QML
// 绑定上踩了坑（原地修改对象不触发绑定重算，粒子会叠成一个点）。
Item {
    id: root

    // 每次爆开的粒子数
    property int burstCount: 56
    // 粒子基准尺寸
    property real particleSize: 9

    ParticleSystem { id: sys }

    Emitter {
        id: emitter
        system: sys
        emitRate: 0                  // 平时不发射，只在点击时 burst
        lifeSpan: 950
        lifeSpanVariation: 350
        size: root.particleSize
        sizeVariation: root.particleSize * 0.6
        endSize: 0                   // 末尾缩到消失，像火星熄灭
        velocity: AngleDirection {
            angle: 0
            angleVariation: 360      // 整圈爆开
            magnitude: 175
            magnitudeVariation: 130
        }
        acceleration: PointDirection { y: 115 }   // 重力
    }

    // 用 ItemParticle + 自绘 delegate：Qt6 的 ImageParticle 不给 source 时画不出东西，
    // delegate 方案不依赖任何图片资源，颜色也在每颗粒子上随机
    ItemParticle {
        system: sys
        delegate: Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: Qt.hsla(Math.random(), 0.88, 0.62, 1)
        }
    }

    Connections {
        target: cursorTracker
        function onPressed(x, y) {
            emitter.x = x
            emitter.y = y
            emitter.burst(root.burstCount)
        }
    }
}
