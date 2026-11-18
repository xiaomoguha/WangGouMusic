import QtQuick
import ".."
import "../../Src/BasicConfig"

// 每日推荐页（移动版，真实数据 dailyRecommend）：
// 头部日期 + 封面卡 + 歌曲列表；点击播放，支持播放全部。
Item
{
    id: root

    Component.onCompleted: {
        if (dailyRecommend && dailyRecommend.songs.length === 0)
            dailyRecommend.fetch()
    }

    // ===== 头部 =====
    MPageHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: qsTr("每日推荐")
        onBackClicked: MTheme.popPage()
    }

    ListView {
        id: songList

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 0

        model: dailyRecommend ? dailyRecommend.songs : []

        // ===== 头部卡：日期 + 封面 + 播放全部 =====
        header: Item {
            width: songList.width
            height: 150

            Rectangle {
                id: heroCard

                anchors.fill: parent
                anchors.margins: MTheme.pageHPadding
                anchors.bottomMargin: 6
                radius: MTheme.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#B94141" }
                    GradientStop { position: 1.0; color: "#8F2D3C" }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        width: 86
                        height: 86
                        radius: MTheme.coverRadius
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#33FFFFFF"
                        clip: true

                        MCover {
                            anchors.fill: parent
                            radius: MTheme.coverRadius
                            source: dailyRecommend.coverUrl
                        }
                    }

                    Column {
                        width: parent.width - 86 - 96 - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            width: parent.width
                            text: dailyRecommend.date !== "" ? dailyRecommend.date : qsTr("每日推荐")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontTitle - 1
                            font.bold: true
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: qsTr("根据你的音乐口味生成 · %1 首").arg(dailyRecommend.songs.length)
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: "#CCFFFFFF"
                            elide: Text.ElideRight
                        }

                        // 播放全部
                        Rectangle {
                            width: playAllText.implicitWidth + 40
                            height: 30
                            radius: 15
                            color: "#FFFFFF"

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                MIcon {
                                    width: 13
                                    height: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: AppIcon.playFill
                                    color: MTheme.accent
                                }
                                Text {
                                    id: playAllText

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("播放全部")
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption + 1
                                    font.bold: true
                                    color: MTheme.accent
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var songs = dailyRecommend ? dailyRecommend.songs : []
                                    if (songs.length > 0)
                                        playlistmanager.playSongbyhasg(songs[0].songhash)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 空态/加载
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: !dailyRecommend || dailyRecommend.songs.length === 0

            MLoading {
                size: 30
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dailyRecommend && dailyRecommend.isLoading
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dailyRecommend && dailyRecommend.isLoading ? qsTr("加载中…") : qsTr("今日推荐尚未生成")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textMuted
            }
        }

        delegate: Item {
            id: dailyRow

            required property int index
            required property var modelData

            width: songList.width
            height: 60

            readonly property bool playing: playlistmanager.currentSonghash === modelData.songhash

            // 进房后行尾换成点播按钮
            readonly property bool inRoom: websocket && websocket.connectionState !== 0

            Row {
                anchors.fill: parent
                anchors.leftMargin: MTheme.pageHPadding
                anchors.rightMargin: MTheme.pageHPadding
                spacing: 10

                Text {
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: dailyRow.index + 1
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    font.bold: true
                    color: dailyRow.playing ? MTheme.accent : MTheme.textPlaceholder
                }

                MCover {
                    width: 46
                    height: 46
                    radius: MTheme.coverRadius
                    anchors.verticalCenter: parent.verticalCenter
                    source: dailyRow.modelData.union_cover
                }

                Column {
                    width: parent.width - 24 - 46 - (dailyRow.inRoom ? 18 : 52) - parent.spacing * 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: dailyRow.modelData.songname
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: dailyRow.playing
                        color: dailyRow.playing ? MTheme.accent : MTheme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: dailyRow.modelData.singername
                              + (dailyRow.modelData.album_name !== "" ? " - " + dailyRow.modelData.album_name : "")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: 52
                    height: 46
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        visible: !dailyRow.playing && !dailyRow.inRoom
                        text: dailyRow.modelData.duration !== "" ? dailyRow.modelData.duration : ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                    }

                    MEqBars {
                        anchors.centerIn: parent
                        visible: dailyRow.playing && !dailyRow.inRoom
                    }
                }

                MTogetherButton {
                    anchors.verticalCenter: parent.verticalCenter
                    songname: dailyRow.modelData.songname
                    songhash: dailyRow.modelData.songhash
                    singername: dailyRow.modelData.singername
                    albumname: dailyRow.modelData.album_name
                    duration: dailyRow.modelData.duration || ""
                    coverurl: dailyRow.modelData.union_cover || ""
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: playlistmanager.playSongbyhasg(dailyRow.modelData.songhash)
            }
        }
    }
}
