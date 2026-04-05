pragma ComponentBehavior: Bound
import QtQuick 2.15

Item {
    id: root
    visible: false
    opacity: 0
    width: 200
    height: 50

    // ── 自动消失定时器 ──
    Timer {
        id: hideTimer
        interval: 1000
        repeat: false
        onTriggered: hideAnimation.restart()
    }

    // ── 淡出动画 ──
    NumberAnimation {
        id: hideAnimation
        target: root
        property: "opacity"
        from: 1
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
        onStopped: {
            root.visible = false;
        }
    }

    // ── 淡入动画 ──
    NumberAnimation {
        id: showAnimation
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
        onStopped: {
            hideTimer.restart();
        }
    }

    // ── 背景遮罩 ──
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1E1E2A"
        border.color: "#30FFFFFF"
        border.width: 1
    }

    // ── 提示内容 ──
    Row {
        anchors.centerIn: parent
        spacing: 10

        // 图标
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: "#2500C853"
            border.color: "#00C853"
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "#00C853"
                font.pixelSize: 14
                font.bold: true
            }
        }

        // 文字
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root._message || "已添加至播放列表"
            color: "#D0D0DD"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

    // ── 显示方法 ──
    property string _message: "已添加至播放列表"

    function show(msg) {
        _message = msg || "已添加至播放列表";
        // 停止所有动画
        hideAnimation.stop();
        hideTimer.stop();
        // 显示并播放动画
        root.opacity = 0;
        root.visible = true;
        showAnimation.restart();
    }
}
