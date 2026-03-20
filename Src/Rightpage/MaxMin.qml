import QtQuick 2.15
import Qt5Compat.GraphicalEffects

Row {
    spacing: 8

    // 最小化按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: minMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: minbutton
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/minus_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: minbutton
                color: "#FFFFFF"
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
                duration: 150
            }
        }
    }

    // 最大化按钮
    Rectangle {
        id: maxBtn
        width: 28
        height: 28
        radius: 14
        color: maxMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

        Image {
            id: maxbottom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: root.visibility === Window.Maximized ? "qrc:/image/fullscreen-exit_line.png" : "qrc:/image/fullscreen_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: maxbottom
                color: "#FFFFFF"
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
                duration: 150
            }
        }
    }

    // 关闭按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: closeMouseArea.containsMouse ? "#FF5252" : "transparent"

        Image {
            id: closebottom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/close-circle_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: closebottom
                color: "#FFFFFF"
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
                duration: 150
            }
        }
    }
}
