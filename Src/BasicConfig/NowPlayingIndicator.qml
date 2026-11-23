import QtQuick 2.15

// 现代「正在播放」指示器：3 根跳动的均衡器竖条。
Item {
    id: root
    property color barColor: AppTheme.accentPlaying
    property bool playing: true   // 播放状态：false 时声波静止
    property bool active: !BasicConfig.uiIdle  // 动画开关：底栏封面可单独按窗口可见性控制
    property int barWidth: 3
    property int barGap: 3
    readonly property int _barCount: 3
    width: _barCount * barWidth + (_barCount - 1) * barGap // = 15
    height: 18

    // 暂停/不可见：静止高度（中间高两边低），避免停住时像消失
    function settleStatic() {
        for (var i = 0; i < root._barCount; i++) {
            var it = bars.itemAt(i)
            if (it) it.height = [10, 16, 12][i]
        }
    }
    onPlayingChanged: if (!playing) settleStatic()
    onVisibleChanged: if (!visible) settleStatic()
    onActiveChanged: if (!active) settleStatic()

    Timer {
        id: tick
        interval: 50   // ~20fps：再低会有可见顿挫
        repeat: true
        running: root.visible && root.playing && root.active
        property real t: 0
        // 与旧动画一致：每根条前半周期 3→H、后半周期 H→3（InOutQuad），
        // 周期不同自然错峰；分段缓动保证周期衔接处连续（不跳变）
        function ease(u) {
            return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2
        }
        onTriggered: {
            t += interval
            for (var i = 0; i < root._barCount; i++) {
                var bar = bars.itemAt(i)
                if (!bar) continue
                var half = 340 + i * 110
                var phase = t % (2 * half)
                var e = phase < half ? ease(phase / half)
                                     : 1 - ease((phase - half) / half)
                bar.height = 3 + (root.height - 3) * e
            }
        }
    }

    Repeater {
        id: bars
        model: root._barCount
        delegate: Rectangle {
            id: bar
            width: root.barWidth
            radius: root.barWidth / 2
            color: root.barColor
            anchors.bottom: root.bottom
            x: index * (root.barWidth + root.barGap)
            // 播放中由 Timer 直赋（Behavior 关掉，否则内部动画又回到 60Hz）；
            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
