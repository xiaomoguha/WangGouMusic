import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Row {
    spacing: 8

    // 最小化按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: minMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: minbutton
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: AppIcon.minimize
            sourceSize: Qt.size(128, 128)
            mipmap: true
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: minbutton
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.iconDefault
            }
        }

        MouseArea {
            id: minMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showMinimized()
        }

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animFast
            }
        }
    }

    // 最大化按钮
    Rectangle {
        id: maxBtn
        width: 28
        height: 28
        radius: 14
        color: maxMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: maxbottom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: root.visibility === Window.Maximized ? AppIcon.restore : AppIcon.maximize
            sourceSize: Qt.size(128, 128)
            mipmap: true
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: maxbottom
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.iconDefault
            }
        }

        MouseArea {
            id: maxMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.visibility === Window.Maximized) {
                    root.showNormal();
                    leftrect.radius = 20;
                    rightrect.radius = 20;
                    bottomrect.radius = 20;
                } else {
                    root.showMaximized();
                    leftrect.radius = 0;
                    rightrect.radius = 0;
                    bottomrect.radius = 0;
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animFast
            }
        }
    }

    // 关闭按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: closeMouseArea.containsMouse ? AppTheme.accentHover : "transparent"

        Image {
            id: closebottom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: AppIcon.close
            sourceSize: Qt.size(128, 128)
            mipmap: true
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: closebottom
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.iconDefault
            }
        }

        MouseArea {
            id: closeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
        }

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animFast
            }
        }
    }
}
