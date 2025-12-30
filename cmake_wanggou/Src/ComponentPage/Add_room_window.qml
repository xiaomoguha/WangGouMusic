import QtQuick 2.15
import QtQuick.Controls
import "../BasicConfig"
Item {
    width: parent.width   // 使用显式宽度和高度，而不是锚点
    height: parent.height
    Rectangle{
        anchors.horizontalCenter: parent.horizontalCenter
        y:0.15*parent.height
        width: 500
        height: 250
        radius: 20
        color: "#393943"
        Column{
            anchors.horizontalCenter: parent.horizontalCenter
            height:parent.height
            spacing: 20
            Item{
                width: 1
                height: 20
            }
            Text {
                text: qsTr("加入房间，一起嗨歌吧！")
                font.pixelSize: 20
                font.family: "黑体"
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            TextField{
                id:roomtextfield
                width: 350
                height: 50
                placeholderText:"输入要加入的房间号，若无该房间将新建一个房间"
                color: "white"
                palette.placeholderText: "gray"
                horizontalAlignment :TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                font.family: "黑体"
                leftPadding:15
                background: Rectangle{//外部矩形
                    anchors.fill: parent
                    radius:20
                    gradient: Gradient{
                        orientation: Gradient.Horizontal
                        GradientStop{color: "#21283d";position: 0}
                        GradientStop{color: "#382635";position: 1}
                    }
                    Rectangle{//内部矩形（套娃出边框渐变）
                        id:ineer
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        property real gradientStopPos: 1
                        gradient: Gradient{
                            orientation: Gradient.Horizontal
                            GradientStop{color: "#1a1d29";position: 0}
                            GradientStop{color: "#241c26";position: ineer.gradientStopPos}
                        }
                    }
                }
                Connections{
                    target:BasicConfig
                    function onBkanAreaClicked()
                    {
                        ineer.gradientStopPos = 1
                    }
                }
                onPressed:
                {
                    ineer.gradientStopPos = 0
                }
            }
            Rectangle{
                Connections {
                    target: websocket  // 指定监听哪个C++对象

                    function onUrlChanged(url_back) {
                        if(url_back.includes("roomid=" + roomtextfield.text))
                        {
                            console.log("url 更新成功！调用连接方法！");
                            websocket.connectToServer();
                        }
                    }
                }
                anchors.horizontalCenter: parent.horizontalCenter
                width:180
                height: 50
                color: "#dc3d49"
                radius: 13
                Text {
                    text: qsTr("开始一起听！")
                    font.pixelSize: 16
                    font.family: "黑体"
                    color: "white"
                    anchors.centerIn: parent
                }
                MouseArea{
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        parent.color = "#e33742"
                    }
                    onExited: {
                        parent.color = "#dc3d49"
                    }
                    onClicked: {
                        websocket.setUrl(roomtextfield.text);
                    }
                }
            }
        }
    }
}
