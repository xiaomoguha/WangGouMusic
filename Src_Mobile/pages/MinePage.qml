import QtQuick
import ".."
import "../../Src/BasicConfig"

// 我的 Tab —— 仿网易云音乐手机版"我的"页（浅色）：
// 紫色渐变头图(头像/昵称/VIP徽章/统计) → 半透明快捷按钮行 →
// 白色圆角面板(音乐/播客/笔记 Tab + 近期/创建/收藏/专辑 + 歌单列表行)。
// 真实数据：userManager.nickname、playlistCollection.favoriteHashes（红心数）。
Item
{
    id: root

    property int tabIndex: 2

    readonly property string displayName:
        userManager && userManager.isLoggedIn && userManager.nickname !== ""
        ? userManager.nickname : qsTr("网狗用户")

    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: headerBlock.height + sheet.height
        boundsBehavior: Flickable.StopAtBounds

        // ===== 头部渐变区 =====
        Item {
            id: headerBlock

            width: parent.width
            height: 342

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#8F7FBE" }
                    GradientStop { position: 0.55; color: "#A495CE" }
                    GradientStop { position: 1.0; color: "#B9A8DC" }
                }
            }

            // ---- 顶栏（占位留白：原汉堡/添加状态/图标均为死功能，已按需求移除） ----
            Item {
                id: headBar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                height: MTheme.touchMin - 4
            }

            // ---- 头像 ----
            Rectangle {
                id: avatarWrap

                width: 86
                height: 86
                radius: 43
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: headBar.bottom
                anchors.topMargin: 10
                color: "#FFFFFF"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: width / 2
                    color: MTheme.bgInput
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "qrc:/image/wyyicon.png"
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    MIcon {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        source: AppIcon.user
                        color: MTheme.textPlaceholder
                    }
                }
            }

            // ---- 昵称 ----
            Item {
                anchors.top: avatarWrap.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                height: 26

                Text {
                    anchors.centerIn: parent
                    text: root.displayName
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontTitle + 1
                    font.bold: true
                    color: "#FFFFFF"
                }
            }

            // ---- 统计行（真实数据：红心收藏 / 当前列表） ----
            Row {
                anchors.top: parent.top
                anchors.topMargin: 232
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 34

                readonly property int favCount: playlistCollection ? playlistCollection.favoriteHashes.length : 0
                readonly property int listCount: playlistmanager ? playlistmanager.playlistTotalCount : 0

                Repeater {
                    model: [
                        { num: (parent ? parent.favCount : 0), unit: qsTr("收藏歌曲") },
                        { num: (parent ? parent.listCount : 0), unit: qsTr("当前列表") }
                    ]

                    delegate: Row {
                        id: statItem

                        required property int index
                        required property var modelData

                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: statItem.modelData.num
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBodyLg
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: statItem.modelData.unit
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption + 1
                            color: "#D9FFFFFF"
                        }
                    }
                }
            }

            // ---- 云贝通知条（网易云同款位，纯展示） ----
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 300
                anchors.left: parent.left
                anchors.leftMargin: MTheme.pageHPadding
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding
                height: 32
                radius: 16
                color: "#26705A8C"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MIcon {
                        width: 13
                        height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppIcon.sparkle
                        color: "#FFD880"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("移动版适配进行中，桌面端数据完整同步")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: "#E5FFFFFF"
                    }
                }
            }
        }

        // ===== 白色面板 =====
        Rectangle {
            id: sheet

            y: headerBlock.height
            width: parent.width
            height: sheetColumn.height
            radius: 16
            color: MTheme.bgCard

            Column {
                id: sheetColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                // ---- 歌单列表行 ----
                Repeater {
                    model: [
                        {
                            tile: "#EAF0FE", tileIcon: AppIcon.queue, tileColor: "#4A7DDA",
                            title: qsTr("当前播放"),
                            sub: qsTr("共 %1 首").arg(playlistmanager ? playlistmanager.playlistcount : 0),
                            queue: true
                        },
                        {
                            tile: "#FDEBEB", tileIcon: AppIcon.heartFill, tileColor: MTheme.accent,
                            title: qsTr("我喜欢的音乐"),
                            sub: "",
                            fav: true
                        },
                        { tile: "#FFF3E8", tileIcon: AppIcon.clock,   tileColor: "#F5A34D",
                          title: qsTr("最近播放"), sub: qsTr("听歌历史"), recent: true }
                    ]

                    delegate: Item {
                        id: listRow

                        required property int index
                        required property var modelData

                        width: sheetColumn.width
                        height: 66

                        readonly property int favCount:
                            playlistCollection ? playlistCollection.favoriteHashes.length : 0

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: MTheme.pageHPadding
                            anchors.rightMargin: MTheme.pageHPadding
                            spacing: 12

                            // 彩色小方块（替代封面）
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: listRow.modelData.tile

                                MIcon {
                                    anchors.centerIn: parent
                                    width: 19
                                    height: 19
                                    source: listRow.modelData.tileIcon
                                    color: listRow.modelData.tileColor
                                }
                            }

                            Column {
                                width: parent.width - 44 - 20 - parent.spacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: listRow.modelData.title
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontBodyLg
                                    font.bold: true
                                    color: MTheme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: listRow.modelData.queue
                                          ? qsTr("共 %1 首 · 点歌名即切歌").arg(playlistmanager ? playlistmanager.playlistcount : 0)
                                          : listRow.modelData.fav
                                            ? (listRow.favCount > 0
                                               ? qsTr("歌单 · %1 首").arg(listRow.favCount)
                                               : qsTr("红心歌曲将显示在这里"))
                                            : listRow.modelData.sub
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption
                                    color: MTheme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            // （右侧预留：后续接"顺序播放收藏"入口）

                        }

                        // 底部分隔线（末行不画）
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: MTheme.pageHPadding + 56
                            anchors.right: parent.right
                            anchors.rightMargin: MTheme.pageHPadding
                            height: 1
                            color: MTheme.separator
                            visible: listRow.index < 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (listRow.modelData.queue)
                                    MTheme.pushPage("qrc:/Src_Mobile/pages/PlayingQueuePage.qml")
                                else
                                    MTheme.toast(qsTr("该列表页待开发"))
                            }
                        }
                    }
                }

                Item { width: 1; height: 12 }
            }
        }
    }
}
