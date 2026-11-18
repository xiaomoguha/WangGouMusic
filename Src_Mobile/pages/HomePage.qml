import QtQuick 2.15
import ".."
import "../../Src/BasicConfig"

// 首页 Tab —— 布局仿网易云音乐手机版：
// 顶栏(logo+图标) → 搜索胶囊 → 四宫格圆形入口 → 推荐歌单横滑 → 热门歌曲列表。
Item
{
    id: root

    property int tabIndex: 0

    Component.onCompleted: {
        if (recommendation && recommendation.topSongsQml.length === 0)
            recommendation.fetchTopSongs()
        if (recommendation && recommendation.topPlaylistsQml.length === 0)
            recommendation.fetchTopPlaylists()
    }

    // ===== 顶栏 =====
    Item {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48

        Row {
            anchors.left: parent.left
            anchors.leftMargin: MTheme.pageHPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: MTheme.bgCard
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: "qrc:/image/wyyicon.png"
                    fillMode: Image.PreserveAspectFit
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("网狗音乐")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontTitle
                font.bold: true
                color: MTheme.textPrimary
            }
        }

        // 右侧功能图标（听歌识曲 / 播放列表）——网易云顶栏同款布局
        Row {
            anchors.right: parent.right
            anchors.rightMargin: MTheme.pageHPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Item {
                width: MTheme.touchMin - 6
                height: MTheme.touchMin - 6
                MIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: AppIcon.microphone
                    color: MTheme.textSecondary
                }
            }
            Item {
                width: MTheme.touchMin - 6
                height: MTheme.touchMin - 6
                MIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: AppIcon.queue
                    color: MTheme.textSecondary
                }
            }
        }
    }

    // ===== 内容滚动区 =====
    Flickable {
        id: contentFlick

        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: contentColumn.height + 16

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            // ---- 搜索胶囊 ----
            Rectangle {
                width: parent.width - MTheme.pageHPadding * 2
                height: 38
                radius: 19
                anchors.horizontalCenter: parent.horizontalCenter
                color: MTheme.bgInput

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MIcon {
                        width: 15
                        height: 15
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppIcon.search
                        color: MTheme.textPlaceholder
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("搜索歌曲、歌手")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textPlaceholder
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/SearchPage.qml")
                }
            }

            // ---- 四宫格圆形入口（网易云首页同款） ----
            Item {
                width: parent.width
                height: 86

                Row {
                    anchors.centerIn: parent
                    width: parent.width - MTheme.pageHPadding * 2
                    spacing: 0

                    Repeater {
                        model: [
                            { icon: AppIcon.fire,  label: qsTr("排行榜"), act: "rank" },
                            { icon: AppIcon.search, label: qsTr("搜索"),  act: "search" }
                        ]

                        delegate: Item {
                            id: gridEntry

                            required property int index
                            required property var modelData

                            width: parent.width / 2
                            height: 86

                            readonly property var gradients: [
                                ["#FF7A7A", "#EC4141"],
                                ["#FF9068", "#D93A3A"]
                            ]

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                spacing: 6

                                Rectangle {
                                    width: 46
                                    height: 46
                                    radius: 23
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: gridEntry.gradients[gridEntry.index][0] }
                                        GradientStop { position: 1; color: gridEntry.gradients[gridEntry.index][1] }
                                    }

                                    MIcon {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        source: gridEntry.modelData.icon
                                        color: "#FFFFFF"
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: gridEntry.modelData.label
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption
                                    color: MTheme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (gridEntry.modelData.act === "rank")
                                        MTheme.pushPage("qrc:/Src_Mobile/pages/RankPage.qml")
                                    else if (gridEntry.modelData.act === "search")
                                        MTheme.pushPage("qrc:/Src_Mobile/pages/SearchPage.qml")
                                }
                            }
                        }
                    }
                }
            }

            // ---- 推荐歌单（横滑卡片 + 播放量角标，网易云同款） ----
            Item {
                width: parent.width
                height: 170

                Text {
                    id: plTitle

                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    text: qsTr("推荐歌单")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontTitle
                    font.bold: true
                    color: MTheme.textPrimary
                }

                ListView {
                    id: plRow

                    anchors.top: plTitle.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    spacing: 10
                    leftMargin: MTheme.pageHPadding
                    rightMargin: MTheme.pageHPadding
                    orientation: ListView.Horizontal

                    model: recommendation.topPlaylistsQml

                    delegate: Item {
                        id: plCard

                        required property int index
                        required property var modelData

                        width: 116
                        height: plRow.height

                        Column {
                            anchors.fill: parent
                            spacing: 6

                            Item {
                                width: 116
                                height: 116

                                Rectangle {
                                    anchors.fill: parent
                                    radius: MTheme.cardRadius
                                    color: MTheme.bgCard
                                    clip: true

                                    RetryImage {
                                        anchors.fill: parent
                                        coverSource: plCard.modelData.imgurl
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }

                                // 播放量角标（网易云标志元素）
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 5
                                    width: playRow.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: "#66000000"

                                    Row {
                                        id: playRow

                                        anchors.centerIn: parent
                                        spacing: 3

                                        MIcon {
                                            width: 9
                                            height: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: AppIcon.play
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: BasicConfig.formatCount(plCard.modelData.play_count)
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontCaption - 2
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }

                            // 歌单名两行
                            Text {
                                width: 116
                                text: plCard.modelData.specialname
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption + 1
                                color: MTheme.textSecondary
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/PlaylistDetailPage.qml",
                                                        { playlist: plCard.modelData })
                        }
                    }
                }
            }

            // ---- 热门歌曲 ----
            Item {
                width: parent.width
                height: 46

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 6

                    MIcon {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppIcon.fire
                        color: MTheme.hotRank
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("热门歌曲")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontTitle
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                }
            }

            // 歌曲列表（内嵌高度 = 行数×行高，放在 Flickable 的 Column 里）
            Item {
                width: parent.width
                height: songRepeater.count > 0 ? songRepeater.count * 62 : 80

                // 加载中占位
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 26
                    visible: songRepeater.count === 0
                    text: qsTr("加载中…")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textMuted
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    Repeater {
                        id: songRepeater

                        model: recommendation.topSongsQml

                        delegate: Item {
                            id: rowDelegate

                            required property int index
                            required property var modelData

                            width: songRepeater.parent.width
                            height: 62

                            readonly property bool playing: playlistmanager.currentSonghash === modelData.songhash

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: MTheme.pageHPadding / 2
                                anchors.rightMargin: MTheme.pageHPadding / 2
                                radius: MTheme.coverRadius
                                color: MTheme.accent
                                opacity: parent.playing ? 0.10 : 0
                                Behavior on opacity { NumberAnimation { duration: MTheme.animFast } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: MTheme.pageHPadding
                                anchors.rightMargin: MTheme.pageHPadding
                                spacing: 10

                                Text {
                                    width: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: rowDelegate.index + 1
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontBodyLg
                                    font.bold: true
                                    color: rowDelegate.index < 3 ? MTheme.hotRank : MTheme.textPlaceholder
                                }

                                Rectangle {
                                    width: 46
                                    height: 46
                                    radius: MTheme.coverRadius
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: MTheme.bgCard
                                    clip: true

                                    RetryImage {
                                        anchors.fill: parent
                                        visible: rowDelegate.modelData.union_cover !== ""
                                        coverSource: rowDelegate.modelData.union_cover
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                    MIcon {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        visible: rowDelegate.modelData.union_cover === ""
                                        source: AppIcon.musicNotes
                                        color: MTheme.textMuted
                                    }
                                }

                                Column {
                                    width: parent.width - 22 - 46 - parent.spacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: rowDelegate.modelData.songname
                                        font.family: MTheme.fontFamily
                                        font.pixelSize: MTheme.fontBody
                                        font.bold: rowDelegate.playing
                                        color: rowDelegate.playing ? MTheme.accent : MTheme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: rowDelegate.modelData.singername
                                          + (rowDelegate.modelData.album_name !== "" ? " - " + rowDelegate.modelData.album_name : "")
                                        font.family: MTheme.fontFamily
                                        font.pixelSize: MTheme.fontCaption
                                        color: MTheme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: playlistmanager.playSongbyhasg(rowDelegate.modelData.songhash)
                            }
                        }
                    }
                }
            }
        }
    }
}
