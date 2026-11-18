import QtQuick
import ".."
import "../../Src/BasicConfig"

// 歌单详情页（移动版，真实数据）：
// recommendation.fetchPlaylistTracks(global_collection_id) 拉取歌曲，
Item
{
    id: root

    // 由 push 传入：{ specialname, imgurl, intro, play_count, global_collection_id, tags, ... }
    property var playlist: null

    readonly property string gid: playlist ? (playlist.global_collection_id || "") : ""

    Component.onCompleted: {
        if (gid === "" || !recommendation)
            return
        if (!recommendation.loadCachedPlaylistTracks(gid))
            recommendation.fetchPlaylistTracks(gid)
    }

    // ===== 头部（返回 + 标题） =====
    MPageHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: qsTr("歌单")
        onBackClicked: MTheme.popPage()
    }

    ListView {
        id: trackList

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 0

        model: recommendation ? recommendation.playlistTracksModel : null

        onAtYEndChanged: {
            if (atYEnd && recommendation && recommendation.playlistHasMore
                    && !recommendation.playlistIsLoading)
                recommendation.fetchMorePlaylistTracks()
        }

        // ===== 头部：歌单卡 + 播放全部条 =====
        header: Item {
            width: trackList.width
            height: 172

            // 歌单卡
            Item {
                width: parent.width
                height: 124

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.rightMargin: MTheme.pageHPadding
                    spacing: 14

                    MCover {
                        width: 108
                        height: 108
                        radius: MTheme.cardRadius
                        anchors.verticalCenter: parent.verticalCenter
                        source: root.playlist ? root.playlist.imgurl : ""
                    }

                    Column {
                        width: parent.width - 108 - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: parent.width
                            text: root.playlist ? root.playlist.specialname : ""
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBodyLg
                            font.bold: true
                            color: MTheme.textPrimary
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 1.2
                        }

                        Row {
                            spacing: 4

                            MIcon {
                                width: 12
                                height: 12
                                anchors.verticalCenter: parent.verticalCenter
                                source: AppIcon.headphones
                                color: MTheme.textMuted
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.playlist ? BasicConfig.formatCount(root.playlist.play_count) : ""
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption
                                color: MTheme.textMuted
                            }
                        }

                        Text {
                            width: parent.width
                            visible: root.playlist && root.playlist.tags !== ""
                            text: root.playlist ? root.playlist.tags : ""
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: MTheme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // 播放全部条（通栏白底，网易云风）
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: MTheme.pageHPadding
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding
                anchors.top: parent.top
                anchors.topMargin: 124 + 6
                height: 38
                radius: 19
                color: MTheme.bgCard

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: MTheme.accent

                        MIcon {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            source: AppIcon.playFill
                            color: "#FFFFFF"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("播放全部")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: recommendation ? "(" + recommendation.playlistTotal + ")" : ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var m = recommendation ? recommendation.playlistTracksModel : null
                        if (m && m.count > 0)
                            playlistmanager.playSongbyhasg(m.get(0).songhash)
                    }
                }
            }
        }

        // 空态
        Text {
            anchors.centerIn: parent
            visible: !recommendation || recommendation.playlistTracksModel.count === 0
            text: recommendation && recommendation.playlistIsLoading ? qsTr("加载中…") : qsTr("暂无歌曲")
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontBody
            color: MTheme.textMuted
        }

        // 底部状态（加载中/加载更多）
        footer: Item {
            width: trackList.width
            height: 48
            visible: recommendation && recommendation.playlistTracksModel.count > 0
                     && (recommendation.playlistIsLoading || recommendation.playlistHasMore)

            Text {
                anchors.centerIn: parent
                text: recommendation && recommendation.playlistIsLoading ? qsTr("加载中…")
                    : qsTr("上滑加载更多")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontCaption
                color: MTheme.textMuted
            }
        }

        delegate: Item {
            id: trackRow

            required property int index
            required property string title
            required property string songhash
            required property string singername
            required property string union_cover
            required property string album_name

            // 进房后行尾换成点播按钮
            readonly property bool inRoom: websocket && websocket.connectionState !== 0

            width: trackList.width
            height: 60

            readonly property bool playing: playlistmanager ? playlistmanager.currentSonghash === songhash : false

            Row {
                anchors.fill: parent
                anchors.leftMargin: MTheme.pageHPadding
                anchors.rightMargin: MTheme.pageHPadding
                spacing: 10

                Text {
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: trackRow.index + 1
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    font.bold: true
                    color: trackRow.playing ? MTheme.accent : MTheme.textPlaceholder
                }

                MCover {
                    width: 44
                    height: 44
                    radius: MTheme.coverRadius
                    anchors.verticalCenter: parent.verticalCenter
                    source: trackRow.union_cover || ""
                }

                Column {
                    width: parent.width - 24 - 44 - (trackRow.inRoom ? 18 : 44) - parent.spacing * 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: trackRow.title
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: trackRow.playing
                        color: trackRow.playing ? MTheme.accent : MTheme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: trackRow.singername
                              + (trackRow.album_name !== "" ? " - " + trackRow.album_name : "")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: 44
                    height: 46
                    anchors.verticalCenter: parent.verticalCenter

                    MEqBars {
                        anchors.centerIn: parent
                        visible: trackRow.playing
                    }
                }

                MTogetherButton {
                    anchors.verticalCenter: parent.verticalCenter
                    songname: trackRow.title
                    songhash: trackRow.songhash
                    singername: trackRow.singername
                    albumname: trackRow.album_name
                    coverurl: trackRow.union_cover || ""
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: playlistmanager.playSongbyhasg(trackRow.songhash)
            }
        }
    }
}
