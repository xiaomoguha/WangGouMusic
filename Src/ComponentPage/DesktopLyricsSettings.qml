import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import "../BasicConfig"

// 桌面歌词设置窗口（独立 OS 模态窗口，由 main.qml 实例化并设 transientParent）
// 用 Qt.WindowModal：系统级阻塞父窗口输入，彻底避免点击/滚轮穿透到主页内容
Window {
    id: settingsWindow
    width: 360
    height: 520
    flags: Qt.FramelessWindowHint | Qt.Dialog
    modality: Qt.WindowModal
    color: "transparent"
    // transientParent 由 main.qml 实例化时指定为主窗口

    signal closeRequested()

    // 切换横/竖向：写配置 + 让桌面歌词窗口按新方向重新定位
    function _setOrientation(vertical) {
        if (!lyricsConfig) return
        lyricsConfig.isVertical = vertical
        lyricsConfig.saveConfig()
        if (desktopLyricsWindow) {
            desktopLyricsWindow._suppressCentering = true
            Qt.callLater(function () {
                desktopLyricsWindow.restorePosition()
                desktopLyricsWindow.enableCentering()
            })
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: settingsWindow.hide()
    }

    // 面板
    Rectangle {
        id: settingsPanel
        anchors.fill: parent
        radius: 16
        color: AppTheme.bgOverlay
        border.color: AppTheme.dialogBorder
        border.width: 1

        // 兜底拦截面板非滚动区的滚轮，避免影响下层（窗口虽模态，仍吸收滚轮）
        MouseArea {
            anchors.fill: parent
            onWheel: function(wheel) { wheel.accepted = true }
        }

        // 右上角关闭按钮
        Rectangle {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            width: 28
            height: 28
            radius: 14
            color: closeHover.hovered ? AppTheme.iconButtonHover : "transparent"
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
            HoverHandler { id: closeHover }
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: AppTheme.textSecondary
                font.pixelSize: AppTheme.fontSizeBody
            }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: settingsWindow.hide()
            }
        }

        // 标题（固定）
        Text {
            id: titleText
            anchors.top: parent.top
            anchors.topMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            text: "桌面歌词"
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeTitleLg
            font.weight: Font.Bold
        }

        // 滚动设置区
        Flickable {
            id: flick
            anchors.top: titleText.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: doneBtn.top
            anchors.bottomMargin: 8
            clip: true
            contentWidth: width
            contentHeight: settingsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: settingsCol
                width: flick.width - 48
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                // 开启桌面歌词
                Item {
                    width: parent.width
                    height: 30

                    Text {
                        text: "开启桌面歌词"
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 46
                        height: 26
                        radius: 13
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: (lyricsConfig && lyricsConfig.enabled) ? AppTheme.accent : AppTheme.scrollbarColor
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                        Rectangle {
                            x: (lyricsConfig && lyricsConfig.enabled) ? parent.width - width - 3 : 3
                            y: 3
                            width: 20
                            height: 20
                            radius: 10
                            color: "white"
                            Behavior on x { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (!lyricsConfig) return
                                lyricsConfig.enabled = !lyricsConfig.enabled
                                lyricsConfig.saveConfig()
                            }
                        }
                    }
                }

                // 方向：横向 / 竖向
                Item {
                    width: parent.width
                    height: 30

                    Text {
                        text: "方向"
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 50
                            height: 26
                            radius: 13
                            color: (lyricsConfig && !lyricsConfig.isVertical) ? AppTheme.accent : "transparent"
                            border.width: 1
                            border.color: (lyricsConfig && !lyricsConfig.isVertical) ? AppTheme.accent : AppTheme.borderDefault
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Text {
                                anchors.centerIn: parent
                                text: "横向"
                                font.pixelSize: AppTheme.fontSizeSmall
                                color: (lyricsConfig && !lyricsConfig.isVertical) ? "white" : AppTheme.textSecondary
                            }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: settingsWindow._setOrientation(false)
                            }
                        }

                        Rectangle {
                            width: 50
                            height: 26
                            radius: 13
                            color: (lyricsConfig && lyricsConfig.isVertical) ? AppTheme.accent : "transparent"
                            border.width: 1
                            border.color: (lyricsConfig && lyricsConfig.isVertical) ? AppTheme.accent : AppTheme.borderDefault
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Text {
                                anchors.centerIn: parent
                                text: "竖向"
                                font.pixelSize: AppTheme.fontSizeSmall
                                color: (lyricsConfig && lyricsConfig.isVertical) ? "white" : AppTheme.textSecondary
                            }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: settingsWindow._setOrientation(true)
                            }
                        }
                    }
                }

                // 跳跃歌词开关（关=普通刷过；仅横向歌词支持）
                Item {
                    width: parent.width
                    height: 42

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "跳跃歌词"
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBodyLg
                        }
                        Text {
                            text: "（仅横向歌词支持）关闭则普通刷过"
                            color: AppTheme.textMuted
                            font.pixelSize: AppTheme.fontSizeCaption
                        }
                    }

                    Rectangle {
                        width: 46
                        height: 26
                        radius: 13
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: (lyricsConfig && lyricsConfig.jumpEnabled) ? AppTheme.accent : AppTheme.scrollbarColor
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                        Rectangle {
                            x: (lyricsConfig && lyricsConfig.jumpEnabled) ? parent.width - width - 3 : 3
                            y: 3
                            width: 20
                            height: 20
                            radius: 10
                            color: "white"
                            Behavior on x { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (!lyricsConfig) return
                                lyricsConfig.jumpEnabled = !lyricsConfig.jumpEnabled
                                lyricsConfig.saveConfig()
                            }
                        }
                    }
                }

                // 分隔线
                Rectangle {
                    width: parent.width
                    height: 1
                    color: AppTheme.borderSubtle
                }

                // 歌词颜色
                ColorField {
                    width: parent.width
                    label: "歌词颜色"
                    colorValue: lyricsConfig ? lyricsConfig.lyricsColor : ""
                    onColorEdited: function(hex) {
                        if (!lyricsConfig) return
                        lyricsConfig.lyricsColor = hex
                        lyricsConfig.saveConfig()
                    }
                }

                // 跳跃歌词颜色（星星 + 拖尾）
                ColorField {
                    width: parent.width
                    label: "跳跃歌词颜色"
                    colorValue: lyricsConfig ? lyricsConfig.starColor : ""
                    onColorEdited: function(hex) {
                        if (!lyricsConfig) return
                        lyricsConfig.starColor = hex
                        lyricsConfig.saveConfig()
                    }
                }

                // 大小
                Column {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            text: "大小"
                            color: AppTheme.textSecondary
                            font.pixelSize: AppTheme.fontSizeBody
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: lyricsConfig ? Math.round(lyricsConfig.scale * 100) + "%" : "100%"
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBody
                            font.bold: true
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Slider {
                        id: sizeSlider
                        width: parent.width
                        from: 0.6
                        to: 1.5
                        stepSize: 0.05
                        Binding on value { value: lyricsConfig ? lyricsConfig.scale : 1.0; restoreMode: Binding.RestoreBindingOrValue }
                        onMoved: {
                            if (!lyricsConfig) return
                            lyricsConfig.scale = value
                            lyricsConfig.saveConfig()
                        }
                    }
                }
            }
        }

        // 完成按钮（底部固定）
        Rectangle {
            id: doneBtn
            width: 120
            height: 36
            radius: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            color: doneMA.containsMouse ? AppTheme.accentHover : AppTheme.accent
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

            Text {
                anchors.centerIn: parent
                text: "完成"
                color: "white"
                font.pixelSize: AppTheme.fontSizeBody
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: doneMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsWindow.hide()
            }
        }
    }
}
