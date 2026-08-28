import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 分区标题旁的「换一批」圆形刷新按钮。
// busy=true（请求进行中）时图标持续旋转；点击瞬间也会立即开始转
// （避免请求慢时才触发动画的空窗），请求结束平滑转完当前圈收尾。
// 用普通动画 + from/to 绑定当前角度 → 重启时无缝续转，停止时保留当前值，不跳变。
Item {
    id: root
    signal clicked
    property bool busy: false
    width: 30
    height: 30

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: refreshHover.hovered ? AppTheme.iconButtonHover : "transparent"
    }

    Image {
        id: refreshIcon
        anchors.centerIn: parent
        source: AppIcon.refresh
        width: 14
        height: 14
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(128, 128)
        mipmap: true
        layer.enabled: true
        layer.effect: ColorOverlay {
            source: refreshIcon
            color: AppTheme.iconDefault
        }

        // 请求期间持续旋转（每次启动从当前角度续转一圈）
        NumberAnimation on rotation {
            id: spinAnim
            from: refreshIcon.rotation
            to: refreshIcon.rotation + 360
            duration: 700
            loops: Animation.Infinite
            running: (root.busy || root._clickPending) && !BasicConfig.uiIdle
        }

        // 请求结束：从当前角度平滑转完当前圈停稳（不闪、不倒转）
        NumberAnimation on rotation {
            id: settleAnim
            from: 0
            to: 360
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // 点击后先转起来（请求开始前不空窗）；请求真正开始时撤销占位
    property bool _clickPending: false
    onBusyChanged: {
        if (root.busy) {
            root._clickPending = false
        } else {
            settleAnim.stop()
            settleAnim.from = refreshIcon.rotation % 360
            settleAnim.to   = settleAnim.from + 360
            settleAnim.start()
        }
    }

    HoverHandler { id: refreshHover }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: {
            root._clickPending = true
            if (root.busy)
                root._clickPending = false
            else
                settleAnim.stop()
            root.clicked()
        }
    }
}
