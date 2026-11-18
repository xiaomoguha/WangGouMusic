import QtQuick
import "../../Src/BasicConfig"
import "."

// 当前播放队列：正在播的歌单（PlaylistManager.playlist，SongListModel）。
// 入口：迷你播放条列表按钮 / 播放页列表按钮 / 我的页「当前播放」行。
// 点行切歌（playSongbyindex），✕ 从队列移除（removeSong）。
Item
{
    id: root

    MPageHeader {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: qsTr("当前播放")
        onBackClicked: MTheme.popPage()
    }

    // 统计行
    Item {
        id: countBar

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Text {
            anchors.left: parent.left
            anchors.leftMargin: MTheme.pageHPadding
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("共 %1 首").arg(playlistmanager ? playlistmanager.playlistcount : 0)
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontCaption + 1
            color: MTheme.textSecondary
        }
    }

    ListView {
        id: queueList

        anchors.top: countBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 0

        model: playlistmanager ? playlistmanager.playlist : null

        Text {
            anchors.centerIn: parent
            visible: !playlistmanager || playlistmanager.playlistcount === 0
            text: qsTr("播放列表是空的，去挑几首吧")
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontBody
            color: MTheme.textMuted
        }

        delegate: Item {
            id: qRow

            required property int index
            required property string title
            required property string songhash
            required property string singername
            required property string union_cover
            required property string album_name
            required property string duration

            readonly property bool current:
                playlistmanager ? playlistmanager.currentSonghash === songhash : false

            width: queueList.width
            height: 58

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: MTheme.pageHPadding / 2
                anchors.rightMargin: MTheme.pageHPadding / 2
                radius: MTheme.coverRadius
                color: qRowMa.pressed ? MTheme.bgInput : "transparent"
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: MTheme.pageHPadding
                anchors.rightMargin: MTheme.pageHPadding
                spacing: 10

                // 当前播放显示声波，否则显示序号
                Item {
                    width: 22
                    height: 42
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        visible: !qRow.current
                        text: qRow.index + 1
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption + 1
                        font.bold: true
                        color: MTheme.textPlaceholder
                    }
                    MEqBars {
                        anchors.centerIn: parent
                        visible: qRow.current
                    }
                }

                MCover {
                    width: 42
                    height: 42
                    radius: MTheme.coverRadius
                    anchors.verticalCenter: parent.verticalCenter
                    source: qRow.union_cover || ""
                }

                Column {
                    width: parent.width - 22 - 42 - 52 - 20 - parent.spacing * 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: qRow.title || ""
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: qRow.current
                        color: qRow.current ? MTheme.accent : MTheme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: (qRow.singername || "")
                              + (qRow.album_name !== "" ? " - " + qRow.album_name : "")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                        elide: Text.ElideRight
                    }
                }

                Text {
                    width: 52
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: qRow.duration || ""
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption
                    color: MTheme.textMuted
                }

                // 移出队列
                Item {
                    width: 20
                    height: 42
                    anchors.verticalCenter: parent.verticalCenter

                    MIcon {
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        source: AppIcon.close
                        color: qRowXMa.pressed ? MTheme.textPrimary : MTheme.textMuted
                    }
                    MouseArea {
                        id: qRowXMa

                        anchors.fill: parent
                        onClicked: playlistmanager.removeSong(qRow.index)
                    }
                }
            }

            MouseArea {
                id: qRowMa

                anchors.fill: parent
                onClicked: playlistmanager.playSongbyindex(qRow.index)
            }
        }
    }
}
