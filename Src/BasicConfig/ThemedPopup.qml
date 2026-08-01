import QtQuick 2.15
import QtQuick.Controls 2.15

// 统一弹窗外壳：modal/focus/居中/进出动画/背景/遮罩一次定义，内容由调用方提供。
// 取代 NoteWindow / UpdateDialog / LoginPage 里重复的 Popup 外壳样板。
Popup {
    id: root
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay

    // 是否绘制半透明遮罩（NoteWindow 无遮罩，保持原样）
    property bool dimBackground: true
    // 背景是否加描边微光（NoteWindow 用）
    property bool accentBorder: false
    property int dialogRadius: 16

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 200; easing.type: Easing.OutBack }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: AppTheme.animFast; easing.type: Easing.InCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: AppTheme.animFast; easing.type: Easing.InCubic }
    }

    Overlay.modal: Rectangle {
        color: root.dimBackground ? AppTheme.dialogOverlay : "transparent"
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }
    }

    background: Rectangle {
        radius: root.dialogRadius
        color: AppTheme.bgOverlay
        border.color: AppTheme.dialogBorder
        border.width: 1

        // 描边微光（NoteWindow 原样）
        Rectangle {
            visible: root.accentBorder
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: AppTheme.dialogAccentBorder
            border.width: 1
        }
    }
}
