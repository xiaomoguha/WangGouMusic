import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    objectName: "togethermusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // 离开房间确认弹窗
    Dialog {
        id: leaveConfirmDialog
        anchors.centerIn: parent
        modal: true
        title: ""
        closePolicy: Popup.CloseOnEscape
        width: 300
        padding: 24

        background: Rectangle {
            radius: 16
            color: AppTheme.bgOverlay
            border.color: AppTheme.dialogBorder
            border.width: 1
        }

        Overlay.modal: Rectangle {
            color: AppTheme.dialogOverlay
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 200; easing.type: Easing.OutBack }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: 150; easing.type: Easing.InCubic }
        }

        Column {
            spacing: 20

            Text {
                text: "确认离开房间？"
                font.pixelSize: 18
                font.family: "黑体"
                font.weight: Font.Bold
                color: AppTheme.textPrimary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "离开后将无法继续与好友同步听歌"
                font.pixelSize: 13
                font.family: "黑体"
                color: AppTheme.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 100
                    height: 36
                    radius: 8
                    color: cancelLeaveHover.hovered ? AppTheme.iconButtonHover : "transparent"
                    border.width: 1
                    border.color: AppTheme.borderDefault

                    Text {
                        anchors.centerIn: parent
                        text: "取消"
                        font.pixelSize: 13
                        font.family: "黑体"
                        color: AppTheme.textSecondary
                    }

                    HoverHandler { id: cancelLeaveHover }
                    TapHandler {
                        onTapped: leaveConfirmDialog.close()
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    width: 100
                    height: 36
                    radius: 8
                    color: confirmLeaveHover.hovered ? "#E04040" : "#FF4D4F"

                    Text {
                        anchors.centerIn: parent
                        text: "离开"
                        font.pixelSize: 13
                        font.family: "黑体"
                        font.weight: Font.Medium
                        color: "#FFFFFF"
                    }

                    HoverHandler { id: confirmLeaveHover }
                    TapHandler {
                        onTapped: {
                            leaveConfirmDialog.close();
                            websocket.disconnectFromServer();
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }

    // 在线用户列表数据
    property var onlineUsers: []
    property int onlineCount: 0

    // 监听客户端列表更新
    Connections {
        target: websocket
        function onClientListUpdated(json) {
            if (json["client_list"] !== undefined) {
                var arr = json["client_list"];
                var users = [];
                for (var i = 0; i < arr.length; i++) {
                    users.push(arr[i]);
                }
                onlineUsers = users;
                onlineCount = users.length;
            }
        }
    }

    // 组件加载完成后，如果已连接则刷新客户端列表
    Component.onCompleted: {
        if (websocket && websocket.connected) {
            websocket.requestClientList();
        }
    }

    // ========== 顶栏：房间信息 + 离开按钮 ==========
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 60
        color: "transparent"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 0.05 * root.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            // 房间标题
            Text {
                text: qsTr("房间 " + (websocket ? websocket.Roomid : ""))
                font.pixelSize: 22
                font.family: "黑体"
                color: AppTheme.textPrimary
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }

            // 在线人数
            Rectangle {
                width: onlineRow.width + 16
                height: 24
                radius: 12
                color: AppTheme.accentDim
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: onlineRow
                    anchors.centerIn: parent
                    spacing: 4

                    // 绿色圆点
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: AppTheme.successColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: onlineCount + " 人在线"
                        font.pixelSize: 12
                        font.family: "黑体"
                        color: AppTheme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 离开房间按钮
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 0.05 * root.width
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            height: 34
            radius: 17
            color: leaveMouseArea.containsMouse ? "#40FF4D4F" : "transparent"
            border.width: 1
            border.color: leaveMouseArea.containsMouse ? "#FF4D4F" : AppTheme.borderDefault

            Text {
                anchors.centerIn: parent
                text: "离开房间"
                font.pixelSize: 13
                font.family: "黑体"
                color: leaveMouseArea.containsMouse ? "#FF4D4F" : AppTheme.textMuted
            }

            MouseArea {
                id: leaveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    leaveConfirmDialog.open();
                }
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    // ========== 播放控制栏 ==========
    Row {
        id: controlBar
        anchors.left: parent.left
        anchors.leftMargin: 0.05 * root.width
        anchors.top: topBar.bottom
        anchors.topMargin: 15
        spacing: 12

        Text {
            text: qsTr("播放列表")
            font.pixelSize: 16
            font.family: "黑体"
            color: AppTheme.textPrimary
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "共" + (playlistmanager ? playlistmanager.togetherplaylist.length : 0) + "首"
            font.pixelSize: 13
            font.family: "黑体"
            color: AppTheme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        // 播放/暂停按钮
        Rectangle {
            width: 34
            height: 34
            radius: 17
            color: ctrlPlayBtn.containsMouse ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: ctrlPlayIcon
                anchors.centerIn: parent
                source: playlistmanager && !playlistmanager.isPaused ? "qrc:/image/paused.png" : "qrc:/image/play.png"
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: ctrlPlayIcon
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: ctrlPlayBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (playlistmanager && playlistmanager.isPaused) {
                        websocket.resumeTogether();
                    } else {
                        websocket.pauseTogether();
                    }
                }
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // 下一首按钮
        Rectangle {
            width: 34
            height: 34
            radius: 17
            color: nextBtnHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: nextBtnIcon
                anchors.centerIn: parent
                source: "qrc:/image/nextplay.png"
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: nextBtnIcon
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: nextBtnHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: websocket.playNextTogether()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // 刷新按钮
        Rectangle {
            width: 34
            height: 34
            radius: 17
            color: refreshHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: refreshIcon
                anchors.centerIn: parent
                source: "qrc:/image/shuaxin.png"
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: refreshIcon
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                id: refreshHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: websocket.requestPlaylist()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ========== 主内容区域：播放列表 + 在线用户 ==========
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: controlBar.bottom
        anchors.topMargin: 15
        anchors.bottom: parent.bottom

        // 播放列表
        Flickable {
            id: playlistFlick
            anchors.left: parent.left
            anchors.right: userListPanel.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            clip: true
            contentWidth: playlistColumn.width
            contentHeight: playlistColumn.height

            Column {
                id: playlistColumn
                width: playlistFlick.width
                spacing: 5

                Repeater {
                    model: playlistmanager ? playlistmanager.togetherplaylist : 0
                    delegate: Rectangle {
                        width: playlistColumn.width
                        height: playlistRow.height + 20
                        radius: 5
                        color: {
                            if (playlistmanager && playlistmanager.currentIndex === index)
                                return AppTheme.bgCardHover;
                            return songHover.containsMouse ? AppTheme.bgCardHover : "transparent";
                        }

                        MouseArea {
                            id: songHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            id: playlistRow
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            // 序号 / 播放动画
                            Text {
                                width: 25
                                text: index + 1 <= 9 ? "0" + String(index + 1) : index + 1
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 14
                                color: AppTheme.textMuted
                                visible: !(playlistmanager && playlistmanager.currentIndex === index)
                            }

                            AnimatedImage {
                                width: 25
                                height: 25
                                source: "qrc:/image/isplaying.gif"
                                playing: visible
                                visible: playlistmanager && playlistmanager.currentIndex === index
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 封面
                            Image {
                                width: 36
                                height: 36
                                source: modelData.union_cover
                                anchors.verticalCenter: parent.verticalCenter
                                asynchronous: true
                            }

                            // 歌名 + 歌手
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    text: modelData.title
                                    font.pixelSize: 13
                                    color: playlistmanager && playlistmanager.currentIndex === index ? AppTheme.accentPlaying : AppTheme.textPrimary
                                    elide: Text.ElideRight
                                    width: 0.14 * root.width
                                    wrapMode: Text.NoWrap
                                }
                                Text {
                                    text: modelData.singername
                                    font.pixelSize: 11
                                    color: AppTheme.textMuted
                                    elide: Text.ElideRight
                                    width: 0.14 * root.width
                                    wrapMode: Text.NoWrap
                                }
                            }

                            // 操作按钮（悬停显示）
                            Row {
                                visible: songHover.containsMouse
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                // 播放
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: itemPlayBtn.containsMouse ? AppTheme.iconButtonHover : "transparent"
                                    Image {
                                        anchors.centerIn: parent
                                        source: "qrc:/image/playnow.png"
                                        width: 14
                                        height: 14
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: true
                                        layer.effect: ColorOverlay {
                                            source: parent.children[0]
                                            color: "#FFFFFF"
                                        }
                                    }
                                    MouseArea {
                                        id: itemPlayBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: websocket.playTogetherByHash(modelData.songhash)
                                    }
                                }

                                // 置顶
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: itemUpBtn.containsMouse ? AppTheme.iconButtonHover : "transparent"
                                    Image {
                                        anchors.centerIn: parent
                                        source: "qrc:/image/upplay.png"
                                        width: 14
                                        height: 14
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: true
                                        layer.effect: ColorOverlay {
                                            source: parent.children[0]
                                            color: "#FFFFFF"
                                        }
                                    }
                                    MouseArea {
                                        id: itemUpBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: websocket.upSongByHash(modelData.songhash)
                                    }
                                }

                                // 删除
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: itemDelBtn.containsMouse ? AppTheme.iconButtonHover : "transparent"
                                    Image {
                                        anchors.centerIn: parent
                                        source: "qrc:/image/delete_line.png"
                                        width: 14
                                        height: 14
                                        fillMode: Image.PreserveAspectFit
                                        layer.enabled: true
                                        layer.effect: ColorOverlay {
                                            source: parent.children[0]
                                            color: "#FFFFFF"
                                        }
                                    }
                                    MouseArea {
                                        id: itemDelBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: websocket.removeSongFromTogether(modelData.songhash)
                                    }
                                }
                            }
                        }

                        // 专辑名
                        Text {
                            x: 0.32 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.album_name
                            font.pixelSize: 13
                            font.family: "黑体"
                            color: AppTheme.textMuted
                            elide: Text.ElideRight
                            width: 0.15 * root.width
                            wrapMode: Text.NoWrap
                        }

                        // 时长
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.duration
                            font.pixelSize: 13
                            font.family: "黑体"
                            color: AppTheme.textDim
                        }
                    }
                }
            }
        }

        // ========== 右侧：在线用户面板 ==========
        Rectangle {
            id: userListPanel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 180
            radius: 10
            color: AppTheme.bgCard

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "在线用户"
                    font.pixelSize: 14
                    font.family: "黑体"
                    font.weight: Font.Bold
                    color: AppTheme.textPrimary
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: AppTheme.borderSubtle
                }

                ListView {
                    id: userListView
                    width: parent.width
                    height: parent.height - 50
                    clip: true
                    spacing: 6
                    model: onlineUsers

                    delegate: Rectangle {
                        width: userListView.width
                        height: 38
                        radius: 6
                        color: userItemHover.containsMouse ? AppTheme.bgNavHover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // 头像
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.fill: parent
                                    source: modelData.avatar_url && modelData.avatar_url !== "" ? modelData.avatar_url : "qrc:/image/touxi.jpg"
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                        }
                                    }
                                }
                            }

                            // 昵称
                            Text {
                                text: modelData.nickname || modelData.userId || "未知用户"
                                font.pixelSize: 12
                                font.family: "黑体"
                                color: AppTheme.textPrimary
                                elide: Text.ElideRight
                                width: 105
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: userItemHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
