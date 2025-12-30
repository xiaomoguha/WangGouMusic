import QtQuick 2.15
import Qt5Compat.GraphicalEffects
Row {
    Image {
        width:18
        height: 18
        id: userbuttom
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/user_line.png"
        layer.effect: ColorOverlay{
            source:userbuttom
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
    Text {
        text: "未登录"
        color: "#cdcdcd"
        height: 18
        verticalAlignment: Text.AlignVCenter
        leftPadding: -10
        font {
            family: "黑体"
            pixelSize: 16
        }
    }
    Image {
        width:18
        height: 18
        id: mailbuttom
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/mail_line.png"
        layer.effect: ColorOverlay{
            source:mailbuttom
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
    Image {
        width:18
        height: 18
        id: settingbuttom
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/setting_line.png"
        layer.effect: ColorOverlay{
            source:settingbuttom
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
    Image {
        width:18
        height: 18
        id: moonbuttom
        fillMode: Image.PreserveAspectFit
        source: "qrc:/image/moon_line.png"
        layer.effect: ColorOverlay{
            source:moonbuttom
            color:"white"
        }
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onEntered: {
                parent.layer.enabled = true
            }
            onExited: {
                parent.layer.enabled = false
            }
        }
    }
    Rectangle{
        width: 2
        height: 18
        id:split_line
        color:"#535C6B"
        MouseArea{
            hoverEnabled: true
            anchors.fill: parent
            onEntered: {
                parent.color = "white"
            }
            onExited: {
                parent.color = "#535C6B"
            }
        }
    }
}
