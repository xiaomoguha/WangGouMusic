import QtQuick
import "."
import "../Src/BasicConfig"

// 推入页通用头部（网易云浅色风）：返回箭头 + 居中标题。
Item
{
    id: root

    property string title: ""
    signal backClicked

    width: parent ? parent.width : 0
    height: 48

    // 返回
    Item {
        width: MTheme.touchMin
        height: MTheme.touchMin
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        MIcon {
            anchors.centerIn: parent
            width: 20
            height: 20
            source: AppIcon.back
            color: MTheme.textPrimary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.backClicked()
        }
    }

    // 标题（居中，超长截断）
    Text {
        anchors.centerIn: parent
        width: parent.width - 120
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        font.family: MTheme.fontFamily
        font.pixelSize: MTheme.fontTitle
        font.bold: true
        color: MTheme.textPrimary
        elide: Text.ElideRight
    }
}
