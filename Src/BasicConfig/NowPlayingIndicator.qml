import QtQuick 2.15

// 现代「正在播放」指示器：3 根跳动的均衡器竖条。
// 纯 QML（矢量、任意 DPI 锐利、跟随主题色），替代旧的 isplaying.gif。
// 可见且正在播放时跳动；不可见或暂停时停止（静止在当前位置），省 CPU 且状态真实。
// 跳动用 50ms Timer 驱动而非动画：Qt Quick 里任何一处变化都会整窗重渲染，
// 这个小组件常驻底栏/歌曲行，若用 60Hz 动画会把整窗钉在 60fps（重页面 CPU 翻倍）。
// 20fps 已足够：跳动周期 340ms+，每周期 7-11 帧视觉连续
Item {
    id: root
    property color barColor: AppTheme.accentPlaying
    property bool playing: true   // 播放状态：false 时声波静止
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

    Timer {
        id: tick
        interval: 50   // ~20fps：再低会有可见顿挫
        repeat: true
        running: root.visible && root.playing && !BasicConfig.uiIdle
        property real t: 0
        // 与旧动画一致：每根条前半周期 3→H、后半周期 H→3（InOutQuad），
        // 周期不同自然错峰；分段缓动保证周期衔接处连续（不跳变）
        function ease(u) {
            return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2
        }
        onTriggered: {
            t += interval
            for (var i = 0; i < root._barCount; i++) {
                var half = 340 + i * 110
                var phase = t % (2 * half)
                var e = phase < half ? ease(phase / half)
                                     : 1 - ease((phase - half) / half)
                bars.itemAt(i).height = 3 + (root.height - 3) * e
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
            anchors.bottom: parent.bottom
            x: index * (root.barWidth + root.barGap)
            // 播放中由 Timer 直赋（Behavior 关掉，否则内部动画又回到 60Hz）；
            // 仅暂停下落时启用平滑过渡
            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
