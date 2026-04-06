import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: updateDialog
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    width: 380
    height: contentColumn.implicitHeight + 60
    anchors.centerIn: Overlay.overlay

    // 外部需要绑定 appUpdater 对象
    required property QtObject updater

    // 是否有新版本（由外部 open 时设置）
    property bool hasUpdate: true
    // 当前状态: idle | downloading | downloaded | error
    property string state_: "idle"
    property string errorMsg: ""

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

    background: Rectangle {
        radius: 16
        color: "#1E1E2A"
        border.color: "#30FFFFFF"
        border.width: 1
    }

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // 标题
        Text {
            text: updateDialog.hasUpdate ? "发现新版本" : "已是最新版本"
            color: "#FFFFFF"
            font.pixelSize: 18
            font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 版本信息 —— 有更新时
        Row {
            visible: updateDialog.hasUpdate
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Text {
                text: updater ? updater.currentVersion : ""
                color: "#888899"
                font.pixelSize: 13
            }
            Text {
                text: "\u2192"
                color: "#FF6B6B"
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                text: updater ? updater.latestVersion : ""
                color: "#00C853"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // 版本信息 —— 已是最新时
        Column {
            visible: !updateDialog.hasUpdate
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Text {
                text: updater ? "v" + updater.currentVersion : ""
                color: "#00C853"
                font.pixelSize: 14
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "当前版本更新内容"
                color: "#888899"
                font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 更新说明
        Rectangle {
            width: parent.width
            height: Math.min(notesText.implicitHeight + 16, 120)
            radius: 8
            color: "#15FFFFFF"
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: notesText.implicitHeight
                clip: true

                Text {
                    id: notesText
                    width: parent.width
                    text: updater ? updater.releaseNotes : ""
                    color: "#B0B0CC"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    lineHeight: 1.4
                }
            }
        }

        // 下载进度条（下载中时显示）
        Column {
            width: parent.width
            spacing: 6
            visible: updateDialog.state_ === "downloading"

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: "#252535"

                Rectangle {
                    width: parent.width * (updater ? updater.downloadProgress : 0)
                    height: parent.height
                    radius: parent.radius
                    color: "#FF6B6B"
                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                text: updater ? Math.round(updater.downloadProgress * 100) + "%" : "0%"
                color: "#888899"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 错误提示
        Text {
            visible: updateDialog.state_ === "error"
            text: updateDialog.errorMsg
            color: "#FF4D4F"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        // 按钮区域
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // 取消/关闭按钮（仅有更新时显示）
            Rectangle {
                width: 100
                height: 36
                radius: 8
                visible: updateDialog.hasUpdate
                color: cancelHover.hovered ? "#30FFFFFF" : "#20FFFFFF"
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: updateDialog.state_ === "downloading" ? "取消" : "稍后再说"
                    color: "#B0B0CC"
                    font.pixelSize: 13
                }
                HoverHandler {
                    id: cancelHover
                }
                TapHandler {
                    onTapped: {
                        if (updateDialog.state_ === "downloading" && updater) {
                            updater.cancelDownload();
                        }
                        updateDialog.state_ = "idle";
                        updateDialog.close();
                    }
                }
            }

            // 主操作按钮
            Rectangle {
                width: 130
                height: 36
                radius: 8
                color: {
                    if (!updateDialog.hasUpdate)
                        return actionHover.hovered ? "#30FFFFFF" : "#20FFFFFF";
                    if (updateDialog.state_ === "downloading")
                        return "#555566";
                    return actionHover.hovered ? "#FF5252" : "#FF6B6B";
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (!updateDialog.hasUpdate)
                            return "知道了";
                        switch (updateDialog.state_) {
                        case "downloading":
                            return "下载中...";
                        case "downloaded":
                            return "立即安装";
                        case "error":
                            return "重试下载";
                        default:
                            return "立即更新";
                        }
                    }
                    color: updateDialog.hasUpdate ? "white" : "#B0B0CC"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                HoverHandler {
                    id: actionHover
                }
                TapHandler {
                    onTapped: {
                        if (!updateDialog.hasUpdate) {
                            updateDialog.close();
                            return;
                        }
                        if (!updater)
                            return;
                        if (updateDialog.state_ === "downloading")
                            return;

                        if (updateDialog.state_ === "downloaded") {
                            updater.installUpdate();
                        } else {
                            updateDialog.state_ = "downloading";
                            updater.downloadUpdate();
                        }
                    }
                }
            }
        }
    }

    // 监听 updater 信号
    Connections {
        target: updater

        function onDownloadFinished() {
            updateDialog.state_ = "downloaded";
        }

        function onDownloadFailed(error) {
            updateDialog.state_ = "error";
            updateDialog.errorMsg = error;
        }

        function onInstallStarted() {
            updateDialog.close();
        }
    }
}
