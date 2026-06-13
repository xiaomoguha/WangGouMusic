import QtQuick 2.15

/// 左侧导航栏矢量图标：用 Canvas 绘制，支持 selected(实心) / 未选中(线框) 两种样式。
/// iconType: discover(精选) | together(一起听) | playlist(我的歌单) | list(播放列表) | recent(最近播放)
Canvas {
    id: root

    property string iconType: "discover"
    property bool selected: false
    property color iconColor: "#FFFFFF"
    property real strokeWidth: 1.6

    implicitWidth: 20
    implicitHeight: 20

    onIconTypeChanged: requestPaint()
    onSelectedChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        ctx.fillStyle = iconColor
        ctx.strokeStyle = iconColor
        ctx.lineWidth = strokeWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"

        switch (iconType) {
            case "discover": drawStar(ctx); break
            case "together": drawTogether(ctx); break
            case "playlist": drawHeart(ctx); break
            case "list": drawList(ctx); break
            case "recent": drawClock(ctx); break
        }
    }

    // 五角星
    function drawStar(ctx) {
        var cx = width / 2, cy = height / 2
        var R = Math.min(width, height) * 0.46
        var r = R * 0.42
        var spikes = 5
        ctx.beginPath()
        for (var i = 0; i < spikes * 2; i++) {
            var rad = (i % 2 === 0) ? R : r
            var ang = -Math.PI / 2 + i * Math.PI / spikes
            var x = cx + rad * Math.cos(ang)
            var y = cy + rad * Math.sin(ang)
            if (i === 0) { ctx.moveTo(x, y) } else { ctx.lineTo(x, y) }
        }
        ctx.closePath()
        if (selected) { ctx.fill() } else { ctx.stroke() }
    }

    // 耳机（一起听）：头梁弧 + 两个耳罩
    function drawTogether(ctx) {
        var w = width, h = height
        var cupW = w * 0.2
        var cupH = h * 0.4
        var cupY = h * 0.4
        var leftX = w * 0.12
        var rightX = w * 0.68
        var radius = cupW * 0.4

        function rr(x, y, rw, rh, r) {
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + rw - r, y)
            ctx.quadraticCurveTo(x + rw, y, x + rw, y + r)
            ctx.lineTo(x + rw, y + rh - r)
            ctx.quadraticCurveTo(x + rw, y + rh, x + rw - r, y + rh)
            ctx.lineTo(x + r, y + rh)
            ctx.quadraticCurveTo(x, y + rh, x, y + rh - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }

        // 头梁
        ctx.lineWidth = selected ? strokeWidth + 1.0 : strokeWidth
        ctx.beginPath()
        ctx.moveTo(leftX + cupW / 2, cupY)
        ctx.quadraticCurveTo(w / 2, h * 0.16, rightX + cupW / 2, cupY)
        ctx.stroke()

        // 两个耳罩
        ctx.lineWidth = strokeWidth
        rr(leftX, cupY, cupW, cupH, radius)
        if (selected) { ctx.fill() } else { ctx.stroke() }
        rr(rightX, cupY, cupW, cupH, radius)
        if (selected) { ctx.fill() } else { ctx.stroke() }
    }

    // 心形
    function drawHeart(ctx) {
        var cx = width / 2
        ctx.beginPath()
        ctx.moveTo(cx, height * 0.82)
        ctx.bezierCurveTo(width * 0.08, height * 0.5, width * 0.22, height * 0.18, cx, height * 0.4)
        ctx.bezierCurveTo(width * 0.78, height * 0.18, width * 0.92, height * 0.5, cx, height * 0.82)
        ctx.closePath()
        if (selected) { ctx.fill() } else { ctx.stroke() }
    }

    // 列表：圆点 + 横条
    function drawList(ctx) {
        var ys = [height * 0.28, height * 0.52, height * 0.76]
        for (var i = 0; i < ys.length; i++) {
            var y = ys[i]
            ctx.beginPath()
            ctx.arc(width * 0.2, y, width * 0.07, 0, Math.PI * 2)
            ctx.fill()
            if (selected) {
                ctx.fillRect(width * 0.36, y - width * 0.08, width * 0.5, width * 0.16)
            } else {
                ctx.beginPath()
                ctx.moveTo(width * 0.36, y)
                ctx.lineTo(width * 0.86, y)
                ctx.stroke()
            }
        }
    }

    // 时钟：圆 + 指针（选中实心圆，指针挖空显出背景）
    function drawClock(ctx) {
        var cx = width / 2, cy = height / 2
        var R = Math.min(width, height) * 0.42
        if (selected) {
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, Math.PI * 2)
            ctx.fill()
            ctx.save()
            ctx.globalCompositeOperation = "destination-out"
            ctx.lineWidth = strokeWidth + 0.6
            ctx.beginPath()
            ctx.moveTo(cx, cy); ctx.lineTo(cx, cy - R * 0.55)
            ctx.moveTo(cx, cy); ctx.lineTo(cx + R * 0.5, cy + R * 0.08)
            ctx.stroke()
            ctx.restore()
        } else {
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(cx, cy); ctx.lineTo(cx, cy - R * 0.5)
            ctx.moveTo(cx, cy); ctx.lineTo(cx + R * 0.45, cy)
            ctx.stroke()
        }
    }
}
