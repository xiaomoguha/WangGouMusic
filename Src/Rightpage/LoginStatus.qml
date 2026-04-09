import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Row {
    spacing: 10

    // 用户按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: userMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

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
                color: AppTheme.iconDefault
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
        color: AppTheme.textSecondary
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
        color: mailMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

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
                color: AppTheme.iconDefault
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
        color: settingMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

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
                color: AppTheme.iconDefault
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

    // 主题按钮（月亮/太阳切换）
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: moonMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: moonbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: AppTheme.isDark ? "qrc:/image/moon_line.png" : "qrc:/image/sun_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: moonbuttom
                color: AppTheme.iconDefault
            }
        }

        MouseArea {
            id: moonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AppTheme.toggleTheme()
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
