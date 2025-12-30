import QtQuick 2.15
import Qt5Compat.GraphicalEffects
Row{
    //最小化
    Image {
        id: minbutton
        width: 18
        height: 18
        fillMode: Image.PreserveAspectFit // 等比例缩放，保持完整
        source: "qrc:/image/minus_line.png"
        layer.effect: ColorOverlay{
            source:minbutton
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onClicked: root.showMinimized()
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
    //最大化
    Image {
        id: maxbottom
        width: 18
        height: 18
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/fullscreen_line.png"
        layer.effect: ColorOverlay{
            source:maxbottom
            color:"white"
        }
        MouseArea{
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (root.visibility === Window.Maximized)
                {
                    root.showNormal()
                    parent.source = "qrc:/image/fullscreen_line.png"
                    leftrect.radius = 20
                    rightrect.radius = 20
                    bottomrect.radius = 20
                }
                else
                {
                    root.showMaximized()
                    parent.source = "qrc:/image/fullscreen-exit_line.png"
                    leftrect.radius = 0
                    rightrect.radius = 0
                    bottomrect.radius = 0
                }
            }
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
            }
        }
    //关闭
    Image {
        id: closebottom
        width: 18
        height: 18
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/close-circle_line.png"
        layer.effect: ColorOverlay{
            source:closebottom
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onClicked: root.close()
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
}
