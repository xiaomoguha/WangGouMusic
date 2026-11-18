import QtQuick
import ".."
import "../../Src/BasicConfig"

// 一起听页（移动版，真实功能，复用 C++ WebSocketClient）：
// 未加入：房间列表（服务端 GET /rooms）+ 房间号加入/创建（房间不存在自动创建）。
Item
{
    id: root

    property int tabIndex: 1

    // connectionState: 0 = 未连接（枚举 Disconnected）
    readonly property bool inRoom: websocket && websocket.connectionState !== 0

    // 聊天时间：服务器/本地回显都是 epoch 秒，格式化成 hh:mm
    function fmtTime(t) {
        if (!t)
            return ""
        return Qt.formatDateTime(new Date(t * 1000), "hh:mm")
    }

    // 房间点播列表展开态（歌曲卡右侧箭头切换）
    property bool listExpanded: false

    Component.onCompleted: {
        if (websocket && !root.inRoom)
            websocket.fetchRoomList()
    }

    function joinRoom(roomid)
    {
        var id = (roomid || "").trim()
        if (id.length === 0 || !userManager || !websocket)
            return
        if (root.inRoom)
            return
        websocket.setUrl(id, userManager.userid)
        websocket.connectToServer()
    }

    // ===== 未加入态 =====
    Column {
        anchors.fill: parent
        visible: !root.inRoom

        // 标题栏
        Item {
            width: parent.width
            height: 52

            Text {
                anchors.left: parent.left
                anchors.leftMargin: MTheme.pageHPadding
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("一起听")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontTitle
                font.bold: true
                color: MTheme.textPrimary
            }

            // 刷新房间列表
            Item {
                width: MTheme.touchMin - 8
                height: MTheme.touchMin - 8
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding
                anchors.verticalCenter: parent.verticalCenter

                MIcon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: AppIcon.refresh
                    color: MTheme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: websocket.fetchRoomList()
                }
            }
        }

        // 房间号输入行
        Rectangle {
            width: parent.width - MTheme.pageHPadding * 2
            height: 38
            radius: 19
            anchors.horizontalCenter: parent.horizontalCenter
            color: MTheme.bgInput

            TextInput {
                id: roomIdInput

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 76
                anchors.verticalCenter: parent.verticalCenter
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textPrimary
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                Text {
                    visible: roomIdInput.text === "" && !roomIdInput.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("输入房间号，不存在将自动创建")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textPlaceholder
                }
                onAccepted: root.joinRoom(roomIdInput.text)
            }

            Rectangle {
                width: 62
                height: 28
                radius: 14
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                color: MTheme.accent

                Text {
                    anchors.centerIn: parent
                    text: qsTr("加入")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption + 1
                    font.bold: true
                    color: "#FFFFFF"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.joinRoom(roomIdInput.text)
                }
            }
        }

        // 房间列表标题
        Text {
            anchors.left: parent.left
            anchors.leftMargin: MTheme.pageHPadding
            anchors.topMargin: 14
            text: qsTr("当前房间")
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontBodyLg
            font.bold: true
            color: MTheme.textPrimary
        }

        // 房间列表
        ListView {
            id: roomList

            width: parent.width
            height: parent.height - 52 - 50 - 30
            anchors.topMargin: 6
            clip: true
            spacing: 8
            topMargin: 6
            leftMargin: MTheme.pageHPadding
            rightMargin: MTheme.pageHPadding

            model: websocket ? websocket.roomList : []

            Text {
                anchors.centerIn: parent
                visible: !websocket || websocket.roomList.length === 0
                text: qsTr("暂无活跃房间\n输入房间号创建一个吧")
                horizontalAlignment: Text.AlignHCenter
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textMuted
                lineHeight: 1.4
            }

            delegate: Rectangle {
                id: roomCard

                required property int index
                required property var modelData

                width: roomList.width - MTheme.pageHPadding * 2
                height: 64
                radius: MTheme.cardRadius
                color: MTheme.bgCard

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    // 房间图标
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: MTheme.accentSubtle

                        MIcon {
                            anchors.centerIn: parent
                            width: 19
                            height: 19
                            source: AppIcon.headphonesFill
                            color: MTheme.accent
                        }
                    }

                    Column {
                        width: parent.width - 40 - 56 - 46 - parent.spacing * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: qsTr("房间 ") + roomCard.modelData.room_id
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBody
                            font.bold: true
                            color: MTheme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: roomCard.modelData.current_song
                                  ? (roomCard.modelData.current_song + " - " + roomCard.modelData.singername)
                                  : qsTr("空闲中")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: MTheme.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    // 在线人数
                    Rectangle {
                        width: countText.implicitWidth + 14
                        height: 22
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: MTheme.accentSubtle

                        Text {
                            id: countText

                            anchors.centerIn: parent
                            text: roomCard.modelData.member_count + qsTr("人")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption - 1
                            color: MTheme.accent
                        }
                    }

                    // 加入按钮
                    Rectangle {
                        width: 52
                        height: 30
                        radius: 15
                        anchors.verticalCenter: parent.verticalCenter
                        color: MTheme.accent

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("加入")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption + 1
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.joinRoom(roomCard.modelData.room_id)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.joinRoom(roomCard.modelData.room_id)
                }
            }
        }
    }

    // ===== 已加入态（房间内） =====
    Column {
        anchors.fill: parent
        visible: root.inRoom

        // 房间头
        Item {
            width: parent.width
            height: 52

            Column {
                anchors.left: parent.left
                anchors.leftMargin: MTheme.pageHPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: qsTr("房间 ") + (websocket ? websocket.Roomid : "")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontTitle
                    font.bold: true
                    color: MTheme.textPrimary
                }
                Text {
                    text: qsTr("播放由房间同步，人人可控")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption
                    color: MTheme.textMuted
                }
            }

            // 离开房间
            Rectangle {
                width: 64
                height: 30
                radius: 15
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding
                anchors.verticalCenter: parent.verticalCenter
                color: MTheme.bgInput

                Text {
                    anchors.centerIn: parent
                    text: qsTr("离开")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption + 1
                    font.bold: true
                    color: MTheme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: websocket.disconnectFromServer()
                }
            }
        }

        // 当前播放卡
        Rectangle {
            width: parent.width - MTheme.pageHPadding * 2
            height: 72
            radius: MTheme.cardRadius
            anchors.horizontalCenter: parent.horizontalCenter
            color: MTheme.bgCard

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    width: 48
                    height: 48
                    radius: MTheme.coverRadius
                    anchors.verticalCenter: parent.verticalCenter
                    color: MTheme.bgInput
                    clip: true

                    RetryImage {
                        anchors.fill: parent
                        visible: playlistmanager.union_cover !== ""
                        coverSource: playlistmanager.union_cover
                        fillMode: Image.PreserveAspectCrop
                    }
                    MIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        visible: playlistmanager.union_cover === ""
                        source: AppIcon.musicNotes
                        color: MTheme.textMuted
                    }
                }

                Column {
                    width: parent.width - 48 - 40 - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: playlistmanager.currentTitle !== "" ? playlistmanager.currentTitle : qsTr("等待播放…")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        font.bold: true
                        color: MTheme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: playlistmanager.currentsingername
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                        elide: Text.ElideRight
                    }
                }

                // 展开点播列表的箭头（点开看房间点播列表）
                Item {
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: root.listExpanded ? MTheme.accentSubtle : MTheme.bgInput

                        MIcon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: AppIcon.caretDown
                            color: root.listExpanded ? MTheme.accent : MTheme.textSecondary
                            rotation: root.listExpanded ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 160 } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.listExpanded = !root.listExpanded
                    }
                }
            }
        }

        // 点播列表（点箭头展开；同步自服务器 210 广播）
        Column {
            id: plPanel

            width: parent.width
            height: root.listExpanded
                    ? Math.min(plHeader.height + plList.height + 6, 300) : 0
            visible: root.listExpanded
            spacing: 0

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            clip: true

            Item {
                id: plHeader

                width: parent.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("点播列表 · %1 首").arg(playlistmanager.togetherplaylist
                                                      ? playlistmanager.togetherplaylist.count : 0)
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption + 1
                    font.bold: true
                    color: MTheme.textSecondary
                }
            }

            ListView {
                id: plList

                width: parent.width
                height: Math.min(count * 56, 260)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: playlistmanager.togetherplaylist

                delegate: Item {
                    id: plRow

                    required property int index
                    required property string title
                    required property string songhash
                    required property string singername
                    required property string duration
                    required property string added_by_nickname

                    readonly property bool current: songhash === playlistmanager.currentSonghash

                    width: plList.width
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        radius: MTheme.coverRadius
                        color: plRowMa.pressed ? MTheme.bgInput : "transparent"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: MTheme.pageHPadding
                        anchors.rightMargin: MTheme.pageHPadding
                        spacing: 10

                        MIcon {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: AppIcon.musicNotes
                            color: plRow.current ? MTheme.accent : MTheme.textMuted
                        }

                        Column {
                            width: parent.width - 16 - 60 - parent.spacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: plRow.title || ""
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontBody
                                font.bold: plRow.current
                                color: plRow.current ? MTheme.accent : MTheme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (plRow.singername || "")
                                      + (plRow.added_by_nickname !== ""
                                         ? "  ·  " + qsTr("%1 点播").arg(plRow.added_by_nickname) : "")
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption
                                color: MTheme.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: 60
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: plRow.duration || ""
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: MTheme.textMuted
                        }
                    }

                    MouseArea {
                        id: plRowMa

                        anchors.fill: parent
                        onClicked: websocket.playTogetherByHash(plRow.songhash)
                    }
                }
            }
        }

        // 聊天区
        ListView {
            id: chatList

            width: parent.width
            height: parent.height - 52 - 72 - 48 - 12 - plPanel.height
            anchors.topMargin: 10
            clip: true
            spacing: 8
            topMargin: 8
            leftMargin: MTheme.pageHPadding
            rightMargin: MTheme.pageHPadding

            model: websocket ? websocket.chatMessages : null

            // 新消息到达自动滚到底部
            onCountChanged: Qt.callLater(function() { chatList.positionViewAtEnd() })

            delegate: Item {
                id: chatRow

                required property int index
                required property var modelData

                width: chatList.width - MTheme.pageHPadding * 2
                height: chatBubble.height + 10

                Rectangle {
                    id: chatBubble

                    anchors.top: parent.top
                    // 注意：内容 Text 的宽度只能引用 chatRow.width，不能引用
                    // chatCol.width / chatBubble.width——否则 implicitWidth ← 子宽度 ←
                    width: Math.min(chatCol.width + 24, chatRow.width)
                    height: chatCol.height + 14
                    radius: 12
                    color: chatRow.modelData.userid === (userManager ? userManager.userid : "")
                           ? MTheme.accentSubtle : MTheme.bgCard

                    Column {
                        id: chatCol

                        x: 12
                        y: 7
                        spacing: 2

                        Text {
                            width: Math.min(implicitWidth, chatRow.width - 44)
                            text: (chatRow.modelData.nickname || qsTr("用户"))
                                  + "  " + root.fmtTime(chatRow.modelData.time)
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption - 2
                            color: MTheme.textMuted
                            elide: Text.ElideRight
                        }
                        Text {
                            width: Math.min(implicitWidth, chatRow.width - 44)
                            text: chatRow.modelData.message || ""
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBody - 1
                            color: MTheme.textPrimary
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        // 聊天输入行
        Item {
            width: parent.width
            height: 48

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: MTheme.pageHPadding
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding + 66
                anchors.verticalCenter: parent.verticalCenter
                height: 38
                radius: 19
                color: MTheme.bgInput

                TextInput {
                    id: chatInput

                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textPrimary
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        visible: chatInput.text === "" && !chatInput.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("和房间里的朋友聊聊…")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textPlaceholder
                    }
                    onAccepted: {
                        var t = chatInput.text.trim()
                        if (t.length > 0 && websocket) {
                            websocket.sendChatMessage(t)
                            chatInput.text = ""
                        }
                    }
                }
            }

            Rectangle {
                width: 58
                height: 34
                radius: 17
                anchors.right: parent.right
                anchors.rightMargin: MTheme.pageHPadding
                anchors.verticalCenter: parent.verticalCenter
                color: MTheme.accent

                Text {
                    anchors.centerIn: parent
                    text: qsTr("发送")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption + 1
                    font.bold: true
                    color: "#FFFFFF"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var t = chatInput.text.trim()
                        if (t.length > 0 && websocket) {
                            websocket.sendChatMessage(t)
                            chatInput.text = ""
                        }
                    }
                }
            }
        }
    }
}
