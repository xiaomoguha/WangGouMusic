import QtQuick 2.15
import QtQuick.Controls 2.15
import "../BasicConfig"
Item {
    id: searchResultRoot
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "SearchresultPage"
    property alias currentIndex: stackView.currentIndex
    property string keyword: BasicConfig.searchKeyword
    Row {
        id: tishirow
        anchors.left: parent.left
        anchors.leftMargin: 0.03 * parent.width
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 20
        spacing: 10
        Text {
            id: searchkeywods
            text: keyword
            font.pixelSize: 23
            font.family: "黑体"
            color: "white"
            font.bold: true
        }
        Text {
            anchors.bottom: searchkeywods.bottom
            id: tishitext
            text: "的相关搜索如下，找到"+(complexsearch?complexsearch.total:0)+"首单曲"
            font.pixelSize: 14
            font.family: "黑体"
            color: "#717176"
            font.bold: true
        }
    }
    Row {
        id: sosjieguorow
        anchors.left: parent.left
        anchors.leftMargin: 0.03 * parent.width
        anchors.right: parent.right
        anchors.top: tishirow.bottom
        anchors.topMargin: 25
        spacing: 10
        Repeater {
            model: ["综合", "单曲", "专辑", "歌词"]
            Item {
                width: 50
                height: 20

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        font.pixelSize: 18
                        font.family: "黑体"
                        color: index === stackView.currentIndex ? "white" : "#717176"
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: index === stackView.currentIndex
                        width: 40
                        height: 2
                        color: index === stackView.currentIndex ? "#e74f50" : "white"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        stackView.currentIndex = index
                    }
                }
            }
        }
    }
    SwipeView {
        id: stackView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: sosjieguorow.bottom
        anchors.topMargin: 15
        anchors.bottom: parent.bottom
        currentIndex: 0
        // 页面组件
        ComplexPage {}
        Danqv {}
        AlbumPage {}
        LyricPage {}
    }
}
