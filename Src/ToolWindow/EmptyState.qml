import QtQuick 2.15
import "../BasicConfig"

// 通用空状态/加载失败占位组件
// 用法：EmptyState { iconText: "♪"; title: "..."; subtitle: "..."; buttonText: "刷新"; onButtonClicked: ... }
Item {
    id: root

    // 图标符号（emoji 或字符），为空则不显示图标圆圈
    property string iconText: "♪"
    property bool showIcon: true
    // 主标题 / 副标题
    property string title: "暂无数据"
    property string subtitle: ""
    // 可选按钮文字，为空则不显示按钮
    property string buttonText: ""
    signal buttonClicked()

    Column {
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
            visible: root.showIcon
            width: 76
            height: 76
            radius: 38
            color: AppTheme.isDark ? AppTheme.accentDim : "#10FF8A80"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: root.iconText
                font.pixelSize: 34
                color: AppTheme.accent
            }
        }

        Text {
            text: root.title
            font.pixelSize: 15
            font.family: AppTheme.fontFamily
            color: AppTheme.textSecondary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            font.pixelSize: 12
            font.family: AppTheme.fontFamily
            color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: 280
        }

        Rectangle {
            id: actionBtn
            visible: root.buttonText !== ""
            width: btnText.implicitWidth + 36
            height: 34
            radius: 17
            color: btnHover.hovered ? AppTheme.accentHover : AppTheme.accent
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: btnText
                anchors.centerIn: parent
                text: root.buttonText
                font.pixelSize: 13
                font.family: AppTheme.fontFamily
                color: AppTheme.iconActive
            }

            HoverHandler { id: btnHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: root.buttonClicked()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
}
