import QtQuick 2.15
import QtQuick.Controls
Page{
    background: Item {
        anchors.fill: parent
    }
    Item{
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: qsTr("歌词页（未完成制作)")
            color:"white"
            font.pixelSize: 20
            font.family: "黑体"
        }
    }
}
