import QtQuick
import "."

// 加载动画：旋转圆弧。用法：MLoading { size: 26 } / MLoading { color: MTheme.accent }
Item
{
    id: root

    property color color: MTheme.textMuted
    property int size: 28

    width: size
    height: size

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = String(root.color)
            ctx.lineWidth = Math.max(2, root.width * 0.1)
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(root.width / 2, root.height / 2,
                    root.width / 2 - ctx.lineWidth, 0, Math.PI * 1.3)
            ctx.stroke()
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.visible
        }
    }

    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
