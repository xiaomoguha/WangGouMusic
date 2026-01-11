import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: toast
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    property string mode: "loading"   // loading | error
    property string message: "加载中..."
    property int autoCloseMs: 3000   // 错误态自动关闭时间（毫秒）

    width: 300
    height: 150
    anchors.centerIn: Overlay.overlay

    background: Rectangle {
        radius: 12
        color: "#2b2b2b"
        opacity: 0.9
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        // ====== 加载动画 ======
        Item {
            width: 300
            height: 150
            visible: toast.mode === "loading"
            Rectangle {
                id: spinner
                width: 32
                height: 32
                radius: 16
                border.width: 3
                border.color: "#00c8ff"
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 0.3*parent.height

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#00c8ff"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: toast.visible && toast.mode === "loading"
                }
            }
            Text {
                text: toast.message
                anchors.top: spinner.bottom
                anchors.topMargin: 15
                anchors.horizontalCenter: parent.horizontalCenter
                color: "white"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
            }
        }


        // ====== 失败态：图标 + 文本同行 ======
        Row {
            spacing: 8
            visible: toast.mode === "error"
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#ff4d4f"

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "white"
                    font.pixelSize: 14
                }
            }

            Text {
                text: toast.message
                color: "white"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
                width: 160
            }
        }
        //成功
        Row {
            spacing: 8
            visible: toast.mode === "success"
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#00bb00"
                Text {
                    anchors.centerIn: parent
                    text: "✅"
                    color: "white"
                    font.pixelSize: 14
                }
            }

            Text {
                text: toast.message
                color: "white"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
                width: 160
            }
        }

        Button {
            text: "确定"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: toast.mode === "error"
            onClicked: toast.close()
        }

        Timer {
            id: errorAutoCloseTimer
            interval: toast.autoCloseMs
            repeat: false
            running: toast.visible && toast.mode === "error" || toast.mode === "success"
            onTriggered: toast.close()
        }
    }

    function showLoading(msg) {
        mode = "loading"
        message = msg || "加载中..."
        open()
    }

    function showError(msg, timeoutMs) {
        mode = "error"
        message = msg || "加载失败"
        autoCloseMs = timeoutMs || autoCloseMs
        open()
    }

    function showSuccess(msg, timeoutMs) {
        mode = "success"
        message = msg || "加载失败"
        autoCloseMs = timeoutMs || autoCloseMs
        open()
    }
}
