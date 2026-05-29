pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    width: parent.width
    height: parent.height

    // 登录弹窗
    LoginPage {
        id: loginPopup
    }

    // ========== 未登录状态 ==========
    Item {
        anchors.fill: parent
        visible: !userManager || !userManager.isLoggedIn

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0.25 * parent.height
            width: 400
            height: 220
            radius: 20
            color: AppTheme.bgRoomCard

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20

                Text {
                    text: "请先登录酷狗账号"
                    font.pixelSize: 20
                    font.family: "黑体"
                    color: AppTheme.textPrimary
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "登录后即可加入房间，与其他人一起听歌"
                    font.pixelSize: 13
                    font.family: "黑体"
                    color: AppTheme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 180
                    height: 46
                    radius: 23
                    color: loginBtnHover.containsMouse ? AppTheme.accentHover : AppTheme.accent
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "去登录"
                        font.pixelSize: 16
                        font.family: "黑体"
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: loginBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            loginPopup.open();
                        }
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }

    // ========== 已登录状态 ==========
    Item {
        anchors.fill: parent
        visible: userManager && userManager.isLoggedIn

        Flickable {
            id: loggedFlickable
            anchors.fill: parent
            clip: true
            contentHeight: loggedContentColumn.height + 40

            Column {
                id: loggedContentColumn
                width: 500
                x: (loggedFlickable.width - width) / 2
                topPadding: loggedFlickable.height * 0.06
                spacing: 20

                // ===== 加入房间卡片 =====
                Rectangle {
                    width: parent.width
                    height: loggedCol.implicitHeight + 60
                    radius: 20
                    color: AppTheme.bgRoomCard

                    Column {
                        id: loggedCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 25
                        spacing: 18
                        width: 400

                        Text {
                            text: qsTr("加入房间，一起嗨歌吧！")
                            font.pixelSize: 20
                            font.family: "黑体"
                            color: AppTheme.textPrimary
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // 当前登录用户信息
                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: 12
                            color: AppTheme.bgInput
                            border.color: AppTheme.borderSubtle
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                // 用户头像
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        anchors.fill: parent
                                        source: userManager && userManager.avatarUrl !== "" ? userManager.avatarUrl : "qrc:/image/touxi.jpg"
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 18
                                            }
                                        }
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: userManager ? userManager.nickname : ""
                                        font.pixelSize: 14
                                        font.family: "黑体"
                                        font.weight: Font.Bold
                                        color: AppTheme.textPrimary
                                    }
                                    Text {
                                        text: "将以该账号加入房间"
                                        font.pixelSize: 11
                                        font.family: "黑体"
                                        color: AppTheme.textMuted
                                    }
                                }
                            }
                        }

                        // 房间号输入
                        TextField {
                            id: roomidtextfield
                            width: parent.width
                            height: 50
                            placeholderText: "输入要加入的房间号，若无该房间将新建一个房间"
                            color: AppTheme.textPrimary
                            palette.placeholderText: AppTheme.textPlaceholder
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            font.family: "黑体"
                            leftPadding: 15
                            enabled: websocket ? websocket.connectionState === 0 : true
                            background: Rectangle {
                                anchors.fill: parent
                                radius: 20
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { color: AppTheme.roomOuterStart; position: 0 }
                                    GradientStop { color: AppTheme.roomOuterEnd; position: 1 }
                                }
                                Rectangle {
                                    id: ineer
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: parent.radius - 1
                                    property real gradientStopPos: 1
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { color: AppTheme.roomInnerStart; position: 0 }
                                        GradientStop { color: AppTheme.roomInnerEnd; position: ineer.gradientStopPos }
                                    }
                                }
                            }
                            Connections {
                                target: BasicConfig
                                function onBkanAreaClicked() { ineer.gradientStopPos = 1 }
                            }
                            onPressed: { ineer.gradientStopPos = 0 }
                        }

                        // 连接状态提示
                        Text {
                            id: statusText
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.pixelSize: 13
                            font.family: "黑体"
                            visible: false
                            property string statusMsg: ""
                            property color statusColor: AppTheme.textMuted
                            text: statusMsg
                            color: statusColor
                        }

                        // 加入按钮
                        Rectangle {
                            Connections {
                                target: websocket
                                function onUrlChanged(url_back) {
                                    if (url_back.includes("roomid=" + roomidtextfield.text)) {
                                        websocket.connectToServer();
                                        statusText.statusMsg = "正在连接...";
                                        statusText.statusColor = AppTheme.infoColor;
                                        statusText.visible = true;
                                    }
                                }
                                function onConnectionStateChanged(state) {
                                    if (state === 1) {
                                        statusText.statusMsg = "正在连接服务器...";
                                        statusText.statusColor = AppTheme.infoColor;
                                        statusText.visible = true;
                                    } else if (state === 2) {
                                        statusText.statusMsg = "已连接！正在同步房间数据...";
                                        statusText.statusColor = AppTheme.successColor;
                                        statusText.visible = true;
                                    } else if (state === 3) {
                                        statusText.statusMsg = "连接断开，正在重连...";
                                        statusText.statusColor = "#FFA500";
                                        statusText.visible = true;
                                    }
                                }
                                function onConnectFail() {
                                    statusText.statusMsg = "连接失败，请检查网络或稍后重试";
                                    statusText.statusColor = AppTheme.errorColor;
                                    statusText.visible = true;
                                }
                                function onErrorOccurred(error) {
                                    statusText.statusMsg = error;
                                    statusText.statusColor = AppTheme.errorColor;
                                    statusText.visible = true;
                                }
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 180
                            height: 50
                            radius: 13
                            color: joinBtnHover.containsMouse ? AppTheme.accentHover : AppTheme.accent
                            opacity: (websocket && websocket.connectionState === 1) ? 0.6 : 1.0

                            Text {
                                text: websocket && websocket.connectionState === 1 ? "连接中..." : "开始一起听！"
                                font.pixelSize: 16
                                font.family: "黑体"
                                color: AppTheme.textPrimary
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                id: joinBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (roomidtextfield.text === "") {
                                        BasicConfig.notice_error("请输入房间号");
                                        return;
                                    }
                                    if (websocket && websocket.connectionState !== 0) return;
                                    // 用 userManager 的 userid 和 nickname
                                    websocket.setUrl(roomidtextfield.text, userManager.userid);
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }

                // ===== 活跃房间列表 =====
                Column {
                    width: parent.width
                    spacing: 10

                    Row {
                        spacing: 10

                        Text {
                            text: "当前活跃房间"
                            font.pixelSize: 16
                            font.bold: true
                            color: AppTheme.textPrimary
                            font.family: "黑体"
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: roomRefreshHover.hovered ? AppTheme.iconButtonHover : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: roomRefreshIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/shuaxin.png"
                                width: 12
                                height: 12
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: roomRefreshIcon
                                    color: AppTheme.iconDefault
                                }
                            }

                            HoverHandler { id: roomRefreshHover }
                            TapHandler {
                                cursorShape: Qt.PointingCursor
                                onTapped: {
                                    if (websocket) websocket.fetchRoomList()
                                }
                            }
                        }
                    }

                    // 空状态
                    Text {
                        visible: !websocket || websocket.roomList.length === 0
                        text: "暂无活跃房间，输入房间号创建一个吧"
                        font.pixelSize: 13
                        font.family: "黑体"
                        color: AppTheme.textMuted
                    }

                    // 房间列表
                    Repeater {
                        model: websocket ? websocket.roomList : []

                        delegate: Rectangle {
                            required property var modelData
                            width: 500
                            height: 56
                            radius: 12
                            color: roomCardHover.hovered ? AppTheme.bgCard : AppTheme.bgRoomCard

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                // 房间图标
                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: AppTheme.accentDim
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.room_id ? modelData.room_id.substring(0, 1) : "#"
                                        color: AppTheme.accent
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }

                                // 房间信息
                                Column {
                                    width: parent.width - 48 - memberBadge.width - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: "房间 " + modelData.room_id
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: AppTheme.textPrimary
                                        font.family: "黑体"
                                    }
                                    Text {
                                        text: modelData.current_song ? (modelData.current_song + " - " + modelData.singername) : "空闲中"
                                        font.pixelSize: 11
                                        color: AppTheme.textMuted
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                // 在线人数
                                Rectangle {
                                    id: memberBadge
                                    height: 24
                                    width: memberText.width + 16
                                    radius: 12
                                    color: AppTheme.accentDim
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: memberText
                                        anchors.centerIn: parent
                                        text: modelData.member_count + "人在线"
                                        font.pixelSize: 11
                                        color: AppTheme.accent
                                        font.family: "黑体"
                                    }
                                }
                            }

                            HoverHandler { id: roomCardHover }
                            TapHandler {
                                cursorShape: Qt.PointingCursor
                                onTapped: {
                                    roomidtextfield.text = modelData.room_id
                                }
                            }

                            // 加入按钮
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 60
                                height: 28
                                radius: 14
                                color: joinRoomBtn.containsMouse ? AppTheme.accentHover : AppTheme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "加入"
                                    font.pixelSize: 12
                                    font.family: "黑体"
                                    color: "#FFFFFF"
                                }

                                MouseArea {
                                    id: joinRoomBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (websocket && websocket.connectionState !== 0) return;
                                        roomidtextfield.text = modelData.room_id;
                                        websocket.setUrl(modelData.room_id, userManager.userid);
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            if (websocket) websocket.fetchRoomList()
        }
    }
}
