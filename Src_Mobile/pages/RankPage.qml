import QtQuick
import ".."
import "../../Src/BasicConfig"

// 排行榜页（移动版，真实数据）：
// rankList.fetchRanks() → 榜单宫格；点击 → fetchRankSongs(rankid) → 榜单歌曲列表。
// 两级视图：0 = 榜单宫格，1 = 歌曲列表（内部返回）。
Item
{
    id: root

    property int viewMode: 0

    // 由音乐馆"排行榜"卡片直达：指定榜单 id，跳过宫格直接进歌曲列表
    property string startRankid: ""

    Component.onCompleted: {
        if (rankList && rankList.ranks.length === 0)
            rankList.fetchRanks()
        if (startRankid !== "") {
            rankList.fetchRankSongs(startRankid)
            root.viewMode = 1
        }
    }

    // ===== 头部 =====
    MPageHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: root.viewMode === 0 ? qsTr("排行榜")
             : (rankList ? rankList.rankName : qsTr("榜单"))
        onBackClicked: {
            if (root.viewMode === 1)
                root.viewMode = 0
            else
                MTheme.popPage()
        }
    }

    // ---- 视图0：榜单宫格 ----
    GridView {
        id: rankGrid

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        clip: true
        visible: root.viewMode === 0

        cellWidth: width / 2
        cellHeight: (cellWidth - 20) * 0.62 + 34

        model: rankList ? rankList.ranks : []

        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: rankGrid.count === 0

            MLoading { size: 30; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("加载中…")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textMuted
            }
        }

        delegate: Item {
            id: rankCard

            required property int index
            required property var modelData

            width: rankGrid.cellWidth
            height: rankGrid.cellHeight

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // 封面卡（封面 + 左下角榜名压字）
                Item {
                    width: parent.width
                    height: parent.width - 20

                    MCover {
                        anchors.fill: parent
                        radius: MTheme.coverRadius
                        source: rankCard.modelData.imgurl || ""
                    }

                    // 底部压暗 + 榜名
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 40
                        radius: MTheme.coverRadius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#00000000" }
                            GradientStop { position: 1.0; color: "#B3000000" }
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: parent.width - 20
                        text: rankCard.modelData.rankname || ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: true
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    rankList.fetchRankSongs(rankCard.modelData.rankid || "")
                    root.viewMode = 1
                }
            }
        }
    }

    // ---- 视图1：榜单歌曲 ----
    ListView {
        id: songList

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        visible: root.viewMode === 1

        model: rankList ? rankList.songs : []

        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: root.viewMode === 1 && rankList && rankList.songs.length === 0

            MLoading {
                size: 30
                anchors.horizontalCenter: parent.horizontalCenter
                visible: rankList && rankList.isLoading
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !rankList || !rankList.isLoading
                text: qsTr("暂无歌曲")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textMuted
            }
        }

        delegate: Item {
            id: rankSongRow

            required property int index
            required property var modelData

            width: songList.width
            height: 62

            readonly property bool playing: playlistmanager.currentSonghash === modelData.songhash

            // 进房后行尾出现点播按钮
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
                    text: rankSongRow.index + 1
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBodyLg
                    font.bold: true
                    color: rankSongRow.index < 3 ? MTheme.accent : MTheme.textPlaceholder
                }

                Rectangle {
                    width: 46
                    height: 46
                    radius: MTheme.coverRadius
                    anchors.verticalCenter: parent.verticalCenter
                    color: MTheme.bgInput
                    clip: true

                    RetryImage {
                        anchors.fill: parent
                        visible: rankSongRow.modelData.union_cover !== undefined
                                 && rankSongRow.modelData.union_cover !== ""
                        coverSource: rankSongRow.modelData.union_cover || ""
                        fillMode: Image.PreserveAspectCrop
                    }
                    MIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        visible: rankSongRow.modelData.union_cover === undefined
                                 || rankSongRow.modelData.union_cover === ""
                        source: AppIcon.musicNotes
                        color: MTheme.textMuted
                    }
                }

                Column {
                    width: parent.width - 24 - 46 - (rankSongRow.inRoom ? 18 : 0)
                           - parent.spacing * (rankSongRow.inRoom ? 3 : 2)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: rankSongRow.modelData.songname || rankSongRow.modelData.title || ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: rankSongRow.playing
                        color: rankSongRow.playing ? MTheme.accent : MTheme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: rankSongRow.modelData.singername || ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                        elide: Text.ElideRight
                    }
                }
            }


                MTogetherButton {
                    anchors.verticalCenter: parent.verticalCenter
                    songname: rankSongRow.modelData.songname || rankSongRow.modelData.title || ""
                    songhash: rankSongRow.modelData.songhash || ""
                    singername: rankSongRow.modelData.singername || ""
                    albumname: rankSongRow.modelData.album_name || ""
                    duration: rankSongRow.modelData.duration || ""
                    coverurl: rankSongRow.modelData.union_cover || ""
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: playlistmanager.playSongbyhasg(rankSongRow.modelData.songhash)
                }
            }
    }
}
