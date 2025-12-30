import QtQuick 2.15
import QtQuick.Controls
Item {
    objectName: "togethermusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    Text {
        id:liebiaotext
        text: qsTr("房间"+"1234"+"播放列表")
        font.pixelSize: 24
        font.family: "黑体"
        color: "white"
        font.weight: Font.Bold
        anchors.left: parent.left
        anchors.leftMargin: 0.05*root.width
        anchors.topMargin: 25
        anchors.top: parent.top
    }
    Text {
        text: "共"+(playlistmanager?playlistmanager.playlistcount:0)+"首"
        font.pixelSize: 13
        font.family: "黑体"
        color: "#6d6d71"
        anchors.left: liebiaotext.right
        anchors.leftMargin: 10
        anchors.bottom: liebiaotext.bottom
    }
    Row{
        id:playallrow
        anchors.left: liebiaotext.left
        anchors.top: liebiaotext.bottom
        anchors.topMargin: 25
        spacing: 12
        Rectangle{
            id:playallbtn
            width: 100
            height: 35
            radius: 8
            color: "#fc3d49"
            Row{
                anchors.centerIn: parent
                spacing: 3
                Image {
                    id: playallico
                    source: "qrc:/image/play.png"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17
                    height: 17
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    id: playalltext
                    text: qsTr("去添加歌曲")
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "黑体"
                    font.pixelSize: 14
                    color: "white"
                }
            }
            MouseArea{
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = "#e33742"
                }
                onExited: {
                    parent.color = "#fc3d49"
                }
            }
        }
        Rectangle{
            width: 34
            height: 34
            radius: 5
            color: "#212127"
            Image {
                width: 20
                height: 20
                anchors.centerIn: parent
                source: "qrc:/image/shuaxin.png"
                fillMode: Image.PreserveAspectFit
            }
            MouseArea{
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = "#2b2b31"
                }
                onExited: {
                    parent.color = "#212127"
                }
            }
        }
        Rectangle{
            width: 34
            height: 34
            radius: 5
            color: "#212127"
            Image {
                width: 20
                height: 20
                anchors.centerIn: parent
                source: "qrc:/image/more.png"
                fillMode: Image.PreserveAspectFit
            }
            MouseArea{
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = "#2b2b31"
                }
                onExited: {
                    parent.color = "#212127"
                }
            }
        }
    }
    Rectangle{
        anchors.verticalCenter: playallrow.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0.05*root.width
        width: 200
        height: 35
        radius: 15
        color: "#212127"
        Image {
            id: searchico
            source: "qrc:/image/search_line.png"
            width: 15
            height: 15
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
        }
        TextField {
            anchors.fill: parent
            leftPadding:29
            clip:true
            color: "#b5b5b7"
            font.pixelSize: 13
            placeholderText:"搜索播放列表"
            palette.placeholderText: "#cdcdcd"
            verticalAlignment: TextInput.AlignVCenter
            background: Rectangle{
                anchors.fill: parent
                color: "transparent"
            }
        }
    }
    Flickable{
        id:playlistflick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: playallrow.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: playlistcolumn.width
        contentHeight: playlistcolumn.height
        Column {
            id: playlistcolumn
            width: playlistflick.width
            spacing: 10
            Repeater {
                model: playlistmanager?playlistmanager.togetherplaylist:0
                delegate: Rectangle {
                    width: playlistcolumn.width
                    height: playlistrow.height + 25
                    radius: 5
                    color: playlistmanager?(playlistmanager.currentIndex === index?"#212127":"transparent"):"transparent"
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            parent.color = "#212127"
                            playlistadditemsrow.visible = true
                        }
                        onExited: {
                            if(playlistmanager.currentIndex !== index)
                            {
                                parent.color = "transparent"
                            }
                            playlistadditemsrow.visible = false
                        }
                    }
                    Row {
                        id:playlistrow
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15
                        Text {
                            width: 25
                            text: index + 1<=9?"0" + String(index+1):index +1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16; color: "#a1a1a3"
                            visible: playlistmanager?(playlistmanager.currentIndex === index?false:true):true
                        }
                        AnimatedImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 25
                            height: 25
                            source: "qrc:/image/isplaying.gif"
                            playing: true  // 确保动画自动播放
                            visible: playlistmanager ? (playlistmanager.currentIndex === index) : false
                        }

                        Image{
                            anchors.verticalCenter: parent.verticalCenter
                            width:40
                            height: 40
                            //fillMode: Image.PreserveAspectFit
                            source: modelData.union_cover
                        }
                        Column{
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                text: modelData.title
                                font.pixelSize: 13; color: playlistmanager ? (playlistmanager.currentIndex === index?"#ff3a3a":"white") : "white"
                                elide: Text.ElideRight
                                width: 0.19*root.width
                                wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                elide: Text.ElideRight
                                width: 0.19*root.width
                                wrapMode: Text.NoWrap
                                font.pixelSize: 11; color: playlistmanager ? (playlistmanager.currentIndex === index?"#ff3a3a":"white") : "white"
                            }
                        }
                    }
                    Row{
                        id:playlistadditemsrow
                        visible: false
                        anchors.left: playlistrow.right
                        anchors.leftMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Image{
                            id: playlistplayNowImage
                            anchors.verticalCenter: parent.verticalCenter
                            width: 23
                            height: 23
                            fillMode: Image.PreserveAspectFit
                            source: "qrc:/image/playnow.png"
                            MouseArea{
                                hoverEnabled: false
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    playlistmanager.playSongbyindex(index);
                                }
                            }
                        }
                        Image{
                            id: playlistaddloveImage
                            anchors.verticalCenter: parent.verticalCenter
                            width: 23
                            height: 23
                            fillMode: Image.PreserveAspectFit
                            source: "qrc:/image/addlove.png"
                            MouseArea{
                                hoverEnabled: false
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                    Text {
                        id: playlistalbumText
                        x:0.4*root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: 0.28*root.width
                        wrapMode: Text.NoWrap
                        text: modelData.album_name
                        font.pixelSize: 14
                        font.family: "黑体"
                        color:"white"
                    }
                    Text {
                        id: playlistsonglenText
                        anchors.right: parent.right
                        anchors.rightMargin: 0.05*root.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration
                        font.pixelSize: 14
                        font.family: "黑体"
                        color:"white"
                    }
                }
            }
        }
    }
}

