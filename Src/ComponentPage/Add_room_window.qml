pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    width: parent.width
    height: parent.height

    LoginPage {
        id: loginPopup
    }

    // ========== 未登录状态 ==========
    Item {
        anchors.fill: parent
        visible: !userManager || !userManager.isLoggedIn

        Column {
            anchors.centerIn: parent
            spacing: 20

            Rectangle {
                width: 80
                height: 80
                radius: 40
                color: AppTheme.isDark ? AppTheme.accentDim : "#10FF8A80"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 36
                    color: AppTheme.accent
                }
            }

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
                    onClicked: loginPopup.open()
                }

                Behavior on color { ColorAnimation { duration: 150 } }
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
            contentHeight: loggedContent.height + 60

            Column {
                id: loggedContent
                width: 480
                x: (loggedFlickable.width - width) / 2
                topPadding: 30
                spacing: 24

                // ===== 加入房间卡片 =====
                Rectangle {
                    width: parent.width
                    height: joinCol.implicitHeight + 50
                    radius: 16
                    color: AppTheme.bgCard
                    border.width: 1
                    border.color: AppTheme.borderDefault

                    // 浅色模式下的柔和渐变底色
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        visible: !AppTheme.isDark
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#FFF5F5" }
                            GradientStop { position: 1.0; color: "#F8F8FA" }
                        }
                    }

                    // 顶部装饰线
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 1.5

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.3; color: AppTheme.accent }
                            GradientStop { position: 0.7; color: AppTheme.accentHover }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Column {
                        id: joinCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 28
                        spacing: 16
                        width: 400

                        Text {
                            text: "加入房间，一起嗨歌吧！"
                            font.pixelSize: 22
                            font.family: "黑体"
                            color: AppTheme.textPrimary
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // 用户信息
                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: 10
                            color: AppTheme.bgInput

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        anchors.fill: parent
                                        source: userManager && userManager.avatarUrl !== "" ? userManager.avatarUrl : "qrc:/image/touxi.jpg"
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 32; height: 32; radius: 16 }
                                        }
                                    }
                                }

                                Text {
                                    text: (userManager ? userManager.nickname : "") + "  ·  将以该账号加入房间"
                                    font.pixelSize: 12
                                    font.family: "黑体"
                                    color: AppTheme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 房间号输入
                        TextField {
                            id: roomidtextfield
                            width: parent.width
                            height: 48
                            placeholderText: "输入房间号，若无该房间将自动创建"
                            color: AppTheme.textPrimary
                            palette.placeholderText: AppTheme.textPlaceholder
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            font.family: "黑体"
                            enabled: websocket ? websocket.connectionState === 0 : true
                            background: Rectangle {
                                radius: 12
                                color: AppTheme.bgInput
                                border.width: roomidtextfield.activeFocus ? 2 : 1
                                border.color: roomidtextfield.activeFocus ? AppTheme.accent : AppTheme.borderSubtle
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Behavior on border.width { NumberAnimation { duration: 100 } }
                            }
                        }

                        // 状态提示
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 200
                            height: 46
                            radius: 23

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: joinBtnHover.containsMouse ? AppTheme.accentHover : AppTheme.accent }
                                GradientStop { position: 1.0; color: joinBtnHover.containsMouse ? AppTheme.accent : AppTheme.accentHover }
                            }
                            opacity: (websocket && websocket.connectionState === 1) ? 0.6 : 1.0

                            Text {
                                text: websocket && websocket.connectionState === 1 ? "连接中..." : "开始一起听！"
                                font.pixelSize: 16
                                font.family: "黑体"
                                color: "#FFFFFF"
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
                                    websocket.setUrl(roomidtextfield.text, userManager.userid);
                                }
                            }

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

                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }

                // ===== 活跃房间列表 =====
                Column {
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 8

                        // 标题前的小圆点装饰
                        Rectangle {
                            width: 4
                            height: 16
                            radius: 2
                            color: AppTheme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

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
                                onTapped: { if (websocket) websocket.fetchRoomList() }
                            }
                        }
                    }

                    // 空状态
                    Column {
                        visible: !websocket || websocket.roomList.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        topPadding: 20

                        Rectangle {
                            width: 56
                            height: 56
                            radius: 28
                            color: AppTheme.isDark ? AppTheme.accentDim : "#10FF8A80"
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                font.pixelSize: 24
                                color: AppTheme.accent
                            }
                        }
                        Text {
                            text: "暂无活跃房间"
                            font.pixelSize: 13
                            font.family: "黑体"
                            color: AppTheme.textMuted
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "输入房间号创建一个吧"
                            font.pixelSize: 12
                            font.family: "黑体"
                            color: AppTheme.textDim
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // 房间列表
                    Repeater {
                        model: websocket ? websocket.roomList : []

                        delegate: Rectangle {
                            required property var modelData
                            width: 480
                            height: 64
                            radius: 12
                            color: roomCardMA.containsMouse ? AppTheme.bgCardHover : AppTheme.bgCard
                            border.width: 1
                            border.color: AppTheme.borderDefault

                            // 浅色模式下柔和渐变底色
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                visible: !AppTheme.isDark
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#FFFAFA" }
                                    GradientStop { position: 1.0; color: "#F8F8FC" }
                                }
                            }

                            // 浅色模式下左侧强调线
                            Rectangle {
                                visible: !AppTheme.isDark
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                width: 3
                                radius: 1.5
                                color: AppTheme.accent
                                opacity: 0.5
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                // 房间封面（歌曲封面或首字母）
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 10
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: !modelData.cover_url ? AppTheme.accentDim : "transparent"

                                    Image {
                                        anchors.fill: parent
                                        visible: modelData.cover_url && modelData.cover_url !== ""
                                        source: modelData.cover_url || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !modelData.cover_url || modelData.cover_url === ""
                                        text: modelData.room_id ? modelData.room_id.substring(0, 1) : "#"
                                        color: AppTheme.accent
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                }

                                // 房间信息
                                Column {
                                    width: parent.width - 40 - 12 - memberBadge.width - 12 - joinRoomBtn.width - 12
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
                                    height: 22
                                    width: memberText.width + 14
                                    radius: 11
                                    color: AppTheme.accentDim
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: memberText
                                        anchors.centerIn: parent
                                        text: modelData.member_count + "人"
                                        font.pixelSize: 10
                                        color: AppTheme.accent
                                        font.family: "黑体"
                                    }
                                }

                                // 加入按钮
                                Rectangle {
                                    id: joinRoomBtn
                                    width: 56
                                    height: 28
                                    radius: 14
                                    anchors.verticalCenter: parent.verticalCenter

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: joinRoomBtnMA.containsMouse ? AppTheme.accentHover : AppTheme.accent }
                                        GradientStop { position: 1.0; color: joinRoomBtnMA.containsMouse ? AppTheme.accent : AppTheme.accentHover }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "加入"
                                        font.pixelSize: 12
                                        font.family: "黑体"
                                        color: "#FFFFFF"
                                    }

                                    MouseArea {
                                        id: joinRoomBtnMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (websocket && websocket.connectionState !== 0) return;
                                            roomidtextfield.text = modelData.room_id;
                                            websocket.setUrl(modelData.room_id, userManager.userid);
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: roomCardMA
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
                    }
                }
            }
        }

        Component.onCompleted: {
            if (websocket) websocket.fetchRoomList()
        }
    }
}
