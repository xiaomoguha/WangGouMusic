import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    objectName: "togethermusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    Text {
        id: liebiaotext
        text: qsTr("房间" + websocket ? websocket.Roomid : "" + "播放列表")
        font.pixelSize: 24
        font.family: "黑体"
        color: "white"
        font.weight: Font.Bold
        anchors.left: parent.left
        anchors.leftMargin: 0.05 * root.width
        anchors.topMargin: 25
        anchors.top: parent.top
    }
    Text {
        text: "共" + (playlistmanager ? playlistmanager.playlistcount : 0) + "首"
        font.pixelSize: 13
        font.family: "黑体"
        color: "#6d6d71"
        anchors.left: liebiaotext.right
        anchors.leftMargin: 10
        anchors.bottom: liebiaotext.bottom
    }
    Row {
        id: playallrow
        anchors.left: liebiaotext.left
        anchors.top: liebiaotext.bottom
        anchors.topMargin: 25
        spacing: 12
        Rectangle {
            id: playallbtn
            width: 110
            height: 35
            radius: 17
            color: "#FF6B6B"
            Row {
                anchors.centerIn: parent
                spacing: 5
                Image {
                    id: playallico
                    source: "qrc:/image/play.png"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: playallico
                        color: "#FFFFFF"
                    }
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
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    parent.color = "#FF5252";
                }
                onExited: {
                    parent.color = "#FF6B6B";
                }
            }
        }
        // 刷新按钮
        Rectangle {
            id: refreshBtn
            width: 34
            height: 34
            radius: 17
            color: refreshMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

            Image {
                id: refreshIcon
                anchors.centerIn: parent
                source: "qrc:/image/shuaxin.png"
                width: 18
                height: 18
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: refreshIcon
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: refreshMouseArea
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
    }
    // 搜索框
    Rectangle {
        id: searchContainer
        anchors.verticalCenter: playallrow.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0.05 * root.width
        width: 200
        height: 34
        radius: 17
        color: "#2A2A35"
        border.width: 1
        border.color: "#3A3A45"

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Image {
                id: searchico
                source: "qrc:/image/search_line.png"
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: searchico
                    color: "#888888"
                }
            }

            TextField {
                width: parent.width - searchico.width - parent.spacing
                height: parent.height
                placeholderText: "搜索播放列表"
                color: "#FFFFFF"
                palette.placeholderText: "#666666"
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 13
                font.family: "黑体"
                background: Rectangle {
                    color: "transparent"
                }
            }
        }
    }
    Flickable {
        id: playlistflick
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
                model: playlistmanager ? playlistmanager.togetherplaylist : 0
                delegate: Rectangle {
                    width: playlistcolumn.width
                    height: playlistrow.height + 25
                    radius: 5
                    color: playlistmanager ? (playlistmanager.currentIndex === index ? "#212127" : "transparent") : "transparent"
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            parent.color = "#212127";
                            playlistadditemsrow.visible = true;
                        }
                        onExited: {
                            if (playlistmanager.currentIndex !== index) {
                                parent.color = "transparent";
                            }
                            playlistadditemsrow.visible = false;
                        }
                    }
                    Row {
                        id: playlistrow
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15
                        Text {
                            width: 25
                            text: index + 1 <= 9 ? "0" + String(index + 1) : index + 1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16
                            color: "#a1a1a3"
                            visible: playlistmanager ? (playlistmanager.currentIndex === index ? false : true) : true
                        }
                        AnimatedImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 25
                            height: 25
                            source: "qrc:/image/isplaying.gif"
                            playing: true  // 确保动画自动播放
                            visible: playlistmanager ? (playlistmanager.currentIndex === index) : false
                        }

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            //fillMode: Image.PreserveAspectFit
                            source: modelData.union_cover
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                text: modelData.title
                                font.pixelSize: 13
                                color: playlistmanager ? (playlistmanager.currentIndex === index ? "#ff3a3a" : "white") : "white"
                                elide: Text.ElideRight
                                width: 0.19 * root.width
                                wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                elide: Text.ElideRight
                                width: 0.19 * root.width
                                wrapMode: Text.NoWrap
                                font.pixelSize: 11
                                color: playlistmanager ? (playlistmanager.currentIndex === index ? "#ff3a3a" : "white") : "white"
                            }
                        }
                    }
                    Row {
                        id: playlistadditemsrow
                        visible: false
                        anchors.left: playlistrow.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // 播放按钮
                        Rectangle {
                            id: playlistplayNowBtn
                            width: 30
                            height: 30
                            radius: 15
                            color: playNowMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

                            Image {
                                id: playlistplayNowImage
                                anchors.centerIn: parent
                                source: "qrc:/image/playnow.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: playlistplayNowImage
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: playNowMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    playlistmanager.playSongbyindex(index);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // 收藏按钮
                        Rectangle {
                            id: playlistaddloveBtn
                            width: 30
                            height: 30
                            radius: 15
                            color: addloveMouseArea.containsMouse ? "#30FFFFFF" : "transparent"

                            Image {
                                id: playlistaddloveImage
                                anchors.centerIn: parent
                                source: "qrc:/image/addlove.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: playlistaddloveImage
                                    color: addloveMouseArea.containsMouse ? "#FF6B6B" : "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: addloveMouseArea
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
                    }
                    Text {
                        id: playlistalbumText
                        x: 0.4 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: 0.28 * root.width
                        wrapMode: Text.NoWrap
                        text: modelData.album_name
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: "white"
                    }
                    Text {
                        id: playlistsonglenText
                        anchors.right: parent.right
                        anchors.rightMargin: 0.05 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: "white"
                    }
                }
            }
        }
    }
}
