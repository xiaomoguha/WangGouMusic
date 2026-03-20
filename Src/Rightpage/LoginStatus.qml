import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Row {
    spacing: 10

    // 用户按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: userMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: userbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/user_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: userbuttom
                color: "#FFFFFF"
            }
        }

        MouseArea {
            id: userMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Text {
        text: "未登录"
        color: "#cdcdcd"
        height: 28
        verticalAlignment: Text.AlignVCenter
        font {
            family: "黑体"
            pixelSize: 14
        }
    }

    // 消息按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: mailMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: mailbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/mail_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: mailbuttom
                color: "#FFFFFF"
            }
        }

        MouseArea {
            id: mailMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // 设置按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: settingMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: settingbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/setting_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: settingbuttom
                color: "#FFFFFF"
            }
        }

        MouseArea {
            id: settingMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // 主题按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: moonMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: moonbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/moon_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: moonbuttom
                color: "#FFFFFF"
            }
        }

        MouseArea {
            id: moonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Rectangle {
        width: 1
        height: 18
        color: "#535C6B"
    }
}
