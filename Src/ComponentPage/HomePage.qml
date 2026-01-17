import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    width: parent.width
    height: parent.height

    /* ===================== 区块配置数据 ===================== */
    property var sectionModel: [
        { title: "嫚姐专属接口，请立马V我50", range: 6, model: recommendation.manitemsqml },
        { title: "精选好歌随心听", range: 0, model: recommendation.SelectedGoodSongsitemsqml },
        { title: "经典怀旧金曲", range: 1, model: recommendation.Classicnostalgicgoldenoldiesitemsqml },
        { title: "热门好歌精选", range: 2, model: recommendation.SelectedPopularHitsitemsqml },
        { title: "小众宝藏佳作", range: 3, model: recommendation.Rareandexquisitemasterpiecesitemsqml },
        { title: "潮流尝鲜", range: 4, model: recommendation.Keepingupwiththelatesttrendsitemsqml },
        { title: "VIP歌曲专属推荐", range: 5, model: recommendation.ExclusiverecommendationforVIPsongsitemsqml }
    ]

    /* ===================== 歌曲 delegate ===================== */
    Component {
        id: songDelegate

        Item {
            width: GridView.view.cellWidth
            height: 60

            readonly property bool isPlaying:
                playlistmanager && playlistmanager.currentSonghash === modelData.songhash

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: (mouse.containsMouse || isPlaying) ? "#27272e" : "transparent"

                Image {
                    id: cover
                    source: modelData.union_cover
                    width: height
                    height: parent.height - 10
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.left: cover.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: cover.verticalCenter
                    spacing: 4

                    Text {
                        text: modelData.songname
                        width: 0.12 * root.width
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: isPlaying ? "#e74f50" : "white"
                    }

                    Text {
                        text: modelData.singername
                        width: 0.12 * root.width
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: isPlaying ? "#e74f50" : "white"
                    }
                }
                Row{
                    id:manrow
                    visible: false
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Image{
                        anchors.verticalCenter: parent.verticalCenter
                        width: 23
                        height: 23
                        source: "qrc:/image/playnow.png"
                        MouseArea{
                            hoverEnabled: false
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if(playlistmanager.nowplaylistrange === 6)
                                {
                                    playlistmanager.playSongbyindex(index);
                                }
                                else
                                {
                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                }
                                manrow.visible = false
                            }
                        }
                    }
                    Image{
                        anchors.verticalCenter: parent.verticalCenter
                        scale: 0.8
                        width: 23
                        height: 23
                        source: "qrc:/image/addplaylist.png"
                        MouseArea{
                            hoverEnabled: false
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                //添加到列表
                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                            }
                        }
                    }
                    Image{
                        id: addloveImage
                        anchors.verticalCenter: parent.verticalCenter
                        width: 23
                        height: 23
                        source: "qrc:/image/addlove.png"
                        MouseArea{
                            hoverEnabled: false
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                AnimatedImage {
                    source: "qrc:/image/isplaying.gif"
                    width: 25
                    height: 25
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: isPlaying
                    playing: true
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onEntered: {
                        if(!isPlaying)
                            manrow.visible = true
                    }
                    onExited: {
                        manrow.visible = false
                    }
                }
            }
        }
    }

    /* ===================== 推荐区块 delegate ===================== */
    Component {
        id: recommendSectionDelegate

        Item {
            width: parent.width
            height: column.implicitHeight

            property string title: modelData.title
            property int playRange: modelData.range
            property var songModel: modelData.model

            Column{
                id:column
                spacing: 10
                width: parent.width

                Item{
                    width: parent.width
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 0.05*parent.width
                    anchors.rightMargin: 0.053*parent.width
                    height: 50

                    Text{
                        id:titletext
                        text: title
                        font.family: "黑体"
                        font.pixelSize: 18
                        color: "white"
                    }
                    Rectangle{
                        width: 22
                        height: width
                        radius: height/2
                        anchors.left: titletext.right
                        anchors.leftMargin: 5
                        anchors.verticalCenter: titletext.verticalCenter
                        color: "#7d7d7d"
                        Image {
                            anchors.fill: parent
                            scale: 0.6
                            source: "qrc:/image/play.png"
                        }
                    }
                    Rectangle{
                        width: 34
                        height: 34
                        radius: 5
                        color: "#212127"
                        anchors.right: parent.right
                        anchors.verticalCenter: titletext.verticalCenter
                        Image {
                            width: 20
                            height: 20
                            anchors.centerIn: parent
                            source: "qrc:/image/shuaxin.png"
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
                            onClicked: {
                                recommendation.getdatabygetdatarange(playRange);
                            }
                        }
                    }
                }
                GridView {
                    width: parent.width
                    height: contentHeight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 0.05*parent.width
                    anchors.rightMargin: 0.053*parent.width
                    cellWidth: width / 3 - 10
                    cellHeight: 60
                    interactive: false
                    model: songModel
                    property int range: playRange
                    delegate: songDelegate
                }
                }
            }
        }

    /* ===================== 滚动容器 ===================== */
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: contentColumn.height

        ScrollBar.vertical: ScrollBar{
            anchors.right: parent.right
            anchors.rightMargin: 5
            width: 10
            contentItem: Rectangle{
                visible: parent.active
                width: 10
                radius: 4
                color: "#42424b"
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 30
            Item{
                width: 1
                height: 1
            }

            Repeater {
                model: sectionModel
                delegate: recommendSectionDelegate
            }
        }
    }
}
