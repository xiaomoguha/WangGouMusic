import QtQuick 2.15

// 现代「正在播放」指示器：3 根跳动的均衡器竖条。
// 纯 QML（矢量、任意 DPI 锐利、跟随主题色），替代旧的 isplaying.gif。
// 可见且正在播放时跳动；不可见或暂停时停止（静止在当前位置），省 CPU 且状态真实。
Item {
    id: root
    property color barColor: AppTheme.accentPlaying
    property bool playing: true   // 播放状态：false 时声波静止
    property int barWidth: 3
    property int barGap: 3
    readonly property int _barCount: 3
    width: _barCount * barWidth + (_barCount - 1) * barGap // = 15
    height: 18

    Repeater {
        model: root._barCount
        delegate: Rectangle {
            id: bar
            width: root.barWidth
            radius: root.barWidth / 2
            color: root.barColor
            anchors.bottom: parent.bottom
            x: index * (root.barWidth + root.barGap)
            // 每根条不同周期 → 自然错峰，像真实频谱
            SequentialAnimation on height {
                running: root.visible && root.playing
                loops: Animation.Infinite
                NumberAnimation { from: 3; to: root.height; duration: 340 + index * 110; easing.type: Easing.InOutQuad }
                NumberAnimation { from: root.height; to: 3; duration: 340 + index * 110; easing.type: Easing.InOutQuad }
            }

            // 暂停/不可见：平滑落到静止高度（中间高两边低）。
            // 若直接停住动画，条可能停在最低点看起来像消失——静止态保持可见完整形态。
            // 动画停止后动画驱动结束，这里显式赋值静止高度（Behavior 负责平滑过渡）。
            property bool paused: !root.playing || !root.visible
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            onPausedChanged: {
                if (paused)
                    height = [10, 16, 12][index]
            }
        }
    }
}
