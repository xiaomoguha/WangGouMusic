import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

//上层状态栏
Item {
    property bool canGoBack: false
    signal goBack()

    // 后退按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: backMA.containsMouse ? AppTheme.bgCard : "transparent"
        visible: canGoBack
        opacity: canGoBack ? 1 : 0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Image {
            id: backIcon
            anchors.centerIn: parent
            source: "qrc:/image/left_line.png"
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: backIcon
                color: AppTheme.textPrimary
            }
        }

        MouseArea {
            id: backMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: goBack()
        }
    }

    //搜索、后退、语音按钮
    Search {
        anchors.left: parent.left
        anchors.leftMargin: canGoBack ? 48 : 0.03 * root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        Behavior on anchors.leftMargin { NumberAnimation { duration: 150 } }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 0.02 * root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15
        //登录信息
        LoginStatus {
            spacing: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        //最大化最小化
        MaxMin {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
