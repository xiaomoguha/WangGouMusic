pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls 2.15
import "../BasicConfig"

Popup {
    id: toast
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    property string mode: "loading"   // loading | error | success
    property string message: "加载中..."
    property int autoCloseMs: 3000

    // ── 尺寸自适应 ──
    width: 280
    height: mode === "loading" ? 150 : 120
    anchors.centerIn: Overlay.overlay

    // ── 进出动画 ──
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            property: "scale"
            from: 0.85
            to: 1.0
            duration: 200
            easing.type: Easing.OutBack
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            property: "scale"
            from: 1.0
            to: 0.85
            duration: 150
            easing.type: Easing.InCubic
        }
    }

    // ── 遮罩层 ──
    background: Rectangle {
        radius: 16
        color: AppTheme.bgOverlay
        // 顶部微光边框
        border.color: AppTheme.dialogBorder
        border.width: 1
        // 柔和阴影
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: AppTheme.dialogAccentBorder
            border.width: 1
        }
    }

    // ── 内容区 ──
    Column {
        anchors.centerIn: parent
        spacing: 12

        // ====== 状态图标区 ======
        Item {
            width: 280
            height: 44
            // 加载态 - 优雅的双环旋转
            Row {
                anchors.centerIn: parent
                spacing: 10
                visible: toast.mode === "loading"
                Item {
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    // 外环
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: "transparent"
                        border.width: 2.5
                        border.color: AppTheme.progressTrack
                        anchors.centerIn: parent
                    }
                    // 旋转弧
                    Rectangle {
                        id: spinnerArc
                        width: 32
                        height: 32
                        radius: 16
                        color: "transparent"
                        border.width: 2.5
                        border.color: AppTheme.accent
                        anchors.centerIn: parent
                        clip: true
                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                            running: toast.visible && toast.mode === "loading"
                        }
                        // 遮挡一半形成弧线效果
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            color: AppTheme.bgOverlay
                            anchors.right: parent.right
                            visible: true
                        }
                    }
                    // 中心亮点
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: AppTheme.accent
                        anchors.centerIn: parent
                        opacity: 0.6
                        SequentialAnimation on opacity {
                            running: toast.visible && toast.mode === "loading"
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 1
                                duration: 400
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 0.3
                                duration: 400
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            // 错误态 - 圆角感叹号图标
            Rectangle {
                visible: toast.mode === "error"
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                color: "#30FF4D4F"
                border.color: AppTheme.errorColor
                border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: AppTheme.errorColor
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            // 成功态 - 对勾图标
            Rectangle {
                visible: toast.mode === "success"
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: 18
                color: "#2500C853"
                border.color: AppTheme.successColor
                border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: AppTheme.successColor
                    font.pixelSize: 18
                    font.bold: true
                }
                // 成功态缩放弹跳
                scale: toast.mode === "success" ? 1 : 0
                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        // ====== 提示文字 ======
        Text {
            text: toast.message
            color: AppTheme.textSecondary
            font.pixelSize: 14
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 40
        }

        // ====== 错误态确定按钮 ======
        Rectangle {
            visible: toast.mode === "error"
            width: 90
            height: 32
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: confirmBtnHandler.hovered ? AppTheme.accentHover : AppTheme.accent
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Text {
                anchors.centerIn: parent
                text: "确定"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            HoverHandler {
                id: confirmBtnHandler
            }
            TapHandler {
                onTapped: toast.close()
            }
        }

        // ====== 进度条（加载态底部） ======
        Rectangle {
            visible: toast.mode === "loading"
            width: parent.width - 60
            height: 2
            radius: 1
            color: AppTheme.progressTrack
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                width: parent.width * 0.3
                height: parent.height
                radius: parent.radius
                color: AppTheme.accent
                // 左右来回移动
                SequentialAnimation on x {
                    running: toast.visible && toast.mode === "loading"
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: parent.width - width
                        duration: 1200
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        to: 0
                        duration: 1200
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        }
    }

    // ── 自动关闭定时器 ──
    Timer {
        id: autoCloseTimer
        interval: toast.autoCloseMs
        repeat: false
        running: toast.visible && (toast.mode === "error" || toast.mode === "success")
        onTriggered: toast.close()
    }

    // ── 公开方法 ──
    function showLoading(msg) {
        mode = "loading";
        message = msg || "加载中...";
        open();
    }

    function showError(msg, timeoutMs) {
        mode = "error";
        message = msg || "加载失败";
        autoCloseMs = timeoutMs || autoCloseMs;
        open();
    }

    function showSuccess(msg, timeoutMs) {
        mode = "success";
        message = msg || "操作成功";
        autoCloseMs = timeoutMs || autoCloseMs;
        open();
    }
}
