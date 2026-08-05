import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 检查更新弹窗：版本徽章 + 逐条更新内容 + 下载进度 + 操作按钮。
// 全部走 AppTheme token，深浅主题通用。
ThemedPopup {
    id: updateDialog

    width: 420
    height: 470

    // 外部需要绑定 appUpdater 对象
    required property QtObject updater

    // 是否有新版本（由外部 open 时设置）
    property bool hasUpdate: true
    // 当前状态: idle | downloading | downloaded | error
    property string state_: "idle"
    property string errorMsg: ""

    // 更新说明拆行（服务端格式 "1. xxx" / "- xxx"，去掉序号/短横前缀）
    function noteLines() {
        var out = []
        if (!updater) return out
        var lines = updater.releaseNotes.split(/\r?\n/)
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l === "") continue
            l = l.replace(/^\s*\d+[.、]\s*/, "").replace(/^-\s+/, "")
            out.push(l)
        }
        return out
    }

    Column {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        // ========== 标题 ==========
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Image {
                id: titleIcon
                anchors.verticalCenter: parent.verticalCenter
                source: updateDialog.hasUpdate ? AppIcon.refresh : AppIcon.check
                sourceSize: Qt.size(64, 64)
                width: 18
                height: 18
                fillMode: Image.PreserveAspectFit
                mipmap: true
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: titleIcon
                    color: updateDialog.hasUpdate ? AppTheme.accent : AppTheme.successColor
                }
            }

            Text {
                text: updateDialog.hasUpdate ? "发现新版本" : "已是最新版本"
                color: AppTheme.textPrimary
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.bold: true
                font.family: AppTheme.fontFamily
            }
        }

        // ========== 版本徽章：v当前 → v新版 ==========
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: updateDialog.hasUpdate

            Rectangle {
                height: 28
                radius: 14
                color: AppTheme.bgCard
                border.color: AppTheme.borderDefault
                border.width: 1
                width: currentVerText.implicitWidth + 24

                Text {
                    id: currentVerText
                    anchors.centerIn: parent
                    text: updater ? "v" + updater.currentVersion : ""
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textSecondary
                }
            }

            Text {
                text: "→"
                color: AppTheme.accent
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 28
                radius: 14
                color: AppTheme.accent
                width: newVerText.implicitWidth + 24

                Text {
                    id: newVerText
                    anchors.centerIn: parent
                    text: updater ? "v" + updater.latestVersion : ""
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    font.family: AppTheme.fontFamily
                    color: "#ffffff"
                }
            }
        }

        // ========== 版本徽章：已是最新 ==========
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: !updateDialog.hasUpdate

            Rectangle {
                height: 28
                radius: 14
                color: AppTheme.bgCard
                border.color: AppTheme.borderDefault
                border.width: 1
                width: latestVerText.implicitWidth + 24

                Text {
                    id: latestVerText
                    anchors.centerIn: parent
                    text: updater ? "v" + updater.currentVersion : ""
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    font.family: AppTheme.fontFamily
                    color: AppTheme.successColor
                }
            }
        }

        // ========== 更新内容 ==========
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: 3
                height: 14
                radius: 1.5
                color: AppTheme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: updateDialog.hasUpdate ? "更新内容" : "本版本更新内容"
                color: AppTheme.textPrimary
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.bold: true
                font.family: AppTheme.fontFamily
            }
        }

        // 逐条列表（滚动区域）
        Rectangle {
            width: parent.width
            height: Math.min(notesCol.implicitHeight + 24, 200)
            radius: 10
            color: AppTheme.bgCard
            border.color: AppTheme.borderDefault
            border.width: 1

            Flickable {
                id: notesFlick
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                contentHeight: notesCol.implicitHeight

                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    background: null
                    contentItem: Rectangle {
                        radius: 2
                        color: AppTheme.scrollbarColor
                    }
                }

                Column {
                    id: notesCol
                    width: notesFlick.width
                    spacing: 10
                    anchors.margins: 0

                    Repeater {
                        model: updateDialog.noteLines()

                        Row {
                            width: notesCol.width
                            spacing: 10

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: AppTheme.accent
                                // 顶部对齐（topMargin 对准第一行文字中线），
                                // 多行条目时圆点不再漂到两行中间
                                anchors.top: parent.top
                                anchors.topMargin: 6
                            }

                            Text {
                                width: parent.width - 16
                                text: modelData
                                color: AppTheme.textSecondary
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                wrapMode: Text.Wrap
                                lineHeight: 1.5
                            }
                        }
                    }

                    // 无说明时的占位
                    Text {
                        visible: updateDialog.noteLines().length === 0
                        text: "暂无更新说明"
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // ========== 下载进度条（下载中时显示） ==========
        Column {
            width: parent.width
            spacing: 6
            visible: updateDialog.state_ === "downloading"

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: AppTheme.progressTrack

                Rectangle {
                    width: parent.width * (updater ? updater.downloadProgress : 0)
                    height: parent.height
                    radius: parent.radius
                    color: AppTheme.accent
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
                color: AppTheme.textMuted
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ========== 错误提示 ==========
        Text {
            visible: updateDialog.state_ === "error"
            text: updateDialog.errorMsg
            color: AppTheme.errorColor
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            wrapMode: Text.Wrap
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        Item { width: 1; height: 2 }

        // ========== 按钮区域 ==========
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // 取消/关闭按钮（仅有更新时显示）
            Rectangle {
                width: 104
                height: 36
                radius: 10
                visible: updateDialog.hasUpdate
                color: cancelMA.containsMouse ? AppTheme.bgCardHover : AppTheme.iconButtonHover
                Behavior on color {
                    ColorAnimation { duration: AppTheme.animFast }
                }

                Text {
                    anchors.centerIn: parent
                    text: updateDialog.state_ === "downloading" ? "取消" : "稍后再说"
                    color: AppTheme.textSecondary
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                }
                MouseArea {
                    id: cancelMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
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
                width: 132
                height: 36
                radius: 10
                color: {
                    if (!updateDialog.hasUpdate)
                        return actionMA.containsMouse ? AppTheme.bgCardHover : AppTheme.iconButtonHover;
                    if (updateDialog.state_ === "downloading")
                        return AppTheme.textMuted;
                    return actionMA.containsMouse ? AppTheme.accentHover : AppTheme.accent;
                }
                Behavior on color {
                    ColorAnimation { duration: AppTheme.animFast }
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
                    color: updateDialog.hasUpdate ? "#ffffff" : AppTheme.textSecondary
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: actionMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
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
