import QtQuick 2.15
import Qt5Compat.GraphicalEffects

// 右键菜单单项：图标 + 文字 + hover 高亮
Item {
    id: root
    property string text: ""
    property string iconSource: ""
    property bool danger: false
    signal clicked()

    width: parent ? parent.width : 0
    height: 34

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: hover.hovered ? (root.danger ? "#33FF6B6B" : AppTheme.bgNavHover) : "transparent"
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Image {
                width: 14
                height: 14
                source: root.iconSource
                sourceSize: Qt.size(56, 56)
                fillMode: Image.PreserveAspectFit
                smooth: true
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: root.danger ? AppTheme.errorColor
                                       : (hover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                }
            }

            Text {
                text: root.text
                color: root.danger ? AppTheme.errorColor
                                   : (hover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.clicked()
    }
}
