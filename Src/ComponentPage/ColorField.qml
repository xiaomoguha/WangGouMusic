import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import "../BasicConfig"

// 颜色选择组：标签 + 色板（跟随主题/预设/自定义取色）+ 当前颜色色块与十六进制输入
// colorValue 为空表示"跟随主题"；colorEdited(hex) 在用户选了有效色（或回到跟随主题传 ""）时触发
Item {
    id: root
    height: col.implicitHeight

    property string colorValue: ""
    property string label: "颜色"
    signal colorEdited(string hex)

    readonly property var presets: [
        "#FF6B6B", "#FF4081", "#FF9100", "#FFD600",
        "#00E676", "#18FFFF", "#4FC3F7", "#7C4DFF", "#FFFFFF"
    ]
    readonly property color displayColor: colorValue.length > 0 ? colorValue : AppTheme.accent
    readonly property bool followTheme: colorValue.length === 0
    readonly property bool isCustom: colorValue.length > 0 && root.presets.indexOf(colorValue) < 0

    function _pad(n) { return ("0" + Math.round(n).toString(16)).slice(-2).toUpperCase() }
    function _toHex(c) { return "#" + root._pad(c.r * 255) + root._pad(c.g * 255) + root._pad(c.b * 255) }
    readonly property string displayHex: root._toHex(root.displayColor)

    // 校验输入：支持 #RRGGBB / RRGGBB / #RGB / RGB，统一归一为 #RRGGBB；非法则回滚
    function applyHex() {
        var raw = hexInput.text.trim().replace(/^#/, "")
        if (/^[0-9A-Fa-f]{6}$/.test(raw)) {
            root.colorEdited("#" + raw.toUpperCase())
            return
        }
        if (/^[0-9A-Fa-f]{3}$/.test(raw)) {
            root.colorEdited("#" + (raw[0] + raw[0] + raw[1] + raw[1] + raw[2] + raw[2]).toUpperCase())
            return
        }
        hexInput.text = root.displayHex   // 非法，恢复当前值
    }

    ColorDialog {
        id: dlg
        title: "选择" + root.label
        onAccepted: root.colorEdited(dlg.selectedColor.toString())
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Text {
            text: root.label
            color: AppTheme.textSecondary
            font.pixelSize: AppTheme.fontSizeBody
        }

        Flow {
            width: parent.width
            spacing: 10

            // 跟随主题
            Rectangle {
                width: followLbl.implicitWidth + 22
                height: 26
                radius: 13
                border.width: 1
                border.color: root.followTheme ? AppTheme.accent
                                               : (followHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14))
                color: root.followTheme ? AppTheme.accent
                                        : (followHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                scale: followTap.pressed ? 0.95 : (followHover.hovered ? 1.04 : 1)
                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }
                Text {
                    id: followLbl
                    anchors.centerIn: parent
                    text: "跟随主题"
                    font.pixelSize: AppTheme.fontSizeSmall
                    color: root.followTheme ? "white" : (followHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                }
                HoverHandler { id: followHover }
                TapHandler { id: followTap; cursorShape: Qt.PointingHandCursor; onTapped: root.colorEdited("") }
            }

            // 预设色
            Repeater {
                model: root.presets
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool _on: root.colorValue === modelData
                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: _on ? 3 : 1
                    border.color: _on ? AppTheme.textPrimary
                                      : (swatchHover.hovered ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18))
                    // hover 放大、按下回缩，选中有白圈
                    scale: swatchTap.pressed ? 0.9 : (swatchHover.hovered ? 1.14 : 1)
                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }
                    HoverHandler { id: swatchHover }
                    TapHandler { id: swatchTap; cursorShape: Qt.PointingHandCursor; onTapped: root.colorEdited(modelData) }
                }
            }

            // 自定义（系统取色器，按钮恒为彩虹渐变，选中时外圈描边）
            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: "transparent"
                border.width: root.isCustom ? 3 : 1
                border.color: root.isCustom ? AppTheme.textPrimary
                                            : (customHover.hovered ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18))
                scale: customTap.pressed ? 0.9 : (customHover.hovered ? 1.14 : 1)
                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }
                HoverHandler { id: customHover }
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#FF6B6B" }
                        GradientStop { position: 0.33; color: "#FFD600" }
                        GradientStop { position: 0.66; color: "#00E676" }
                        GradientStop { position: 1.0; color: "#4FC3F7" }
                    }
                }
                TapHandler { id: customTap; cursorShape: Qt.PointingHandCursor; onTapped: dlg.open() }
            }
        }

        // 当前颜色色块 + 十六进制输入（可手输，失焦/回车校验）
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                id: swatch
                width: 30
                height: 30
                radius: 6
                // 输入框聚焦且内容为合法颜色时实时预览输入色，否则显示当前色
                color: {
                    if (hexInput.activeFocus) {
                        var raw = hexInput.text.trim().replace(/^#/, "")
                        if (/^[0-9A-Fa-f]{6}$/.test(raw)) return "#" + raw.toUpperCase()
                        if (/^[0-9A-Fa-f]{3}$/.test(raw)) {
                            var e = raw[0] + raw[0] + raw[1] + raw[1] + raw[2] + raw[2]
                            return "#" + e.toUpperCase()
                        }
                    }
                    return root.displayColor
                }
                border.width: 1
                border.color: swatchBigHover.hovered ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18)
                scale: swatchBigHover.hovered ? 1.08 : 1
                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                HoverHandler { id: swatchBigHover }
                TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: dlg.open() }
                Text {
                    visible: root.followTheme
                    anchors.centerIn: parent
                    text: "主"
                    font.pixelSize: AppTheme.fontSizeXs
                    font.bold: true
                    color: "white"
                }
            }

            TextField {
                id: hexInput
                width: parent.width - 38
                height: 30
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.textPrimary
                placeholderText: "#RRGGBB"
                selectByMouse: true
                Component.onCompleted: text = root.displayHex
                onEditingFinished: root.applyHex()
                background: Rectangle {
                    radius: 6
                    // 与设置页其它输入框同款：半透明底，聚焦提亮 + 强调色描边
                    color: hexInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: hexInput.activeFocus ? 1.5 : 1
                    border.color: hexInput.activeFocus ? AppTheme.borderFocus : Qt.rgba(1, 1, 1, 0.13)
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                }
                Connections {
                    target: root
                    function onDisplayHexChanged() { hexInput.text = root.displayHex }
                }
            }
        }
    }
}
