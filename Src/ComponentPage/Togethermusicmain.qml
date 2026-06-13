import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    id: root
    objectName: "togethermusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    clip: true

    // ========== 离开房间确认弹窗 ==========
    Dialog {
        id: leaveConfirmDialog
        parent: Overlay.overlay
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
            MouseArea { anchors.fill: parent }
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
            width: parent.width

            Text {
                text: "确认离开房间？"
                font.pixelSize: 18
                font.family: AppTheme.fontFamily
                font.weight: Font.Bold
                color: AppTheme.textPrimary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "离开后将无法继续与好友同步听歌"
                font.pixelSize: 13
                font.family: AppTheme.fontFamily
                color: AppTheme.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 100; height: 36; radius: 8
                    color: cancelLeaveHover.hovered ? AppTheme.iconButtonHover : "transparent"
                    border.width: 1; border.color: AppTheme.borderDefault
                    Text { anchors.centerIn: parent; text: "取消"; font.pixelSize: 13; font.family: AppTheme.fontFamily; color: AppTheme.textSecondary }
                    HoverHandler { id: cancelLeaveHover }
                    TapHandler { onTapped: leaveConfirmDialog.close() }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    width: 100; height: 36; radius: 8
                    color: confirmLeaveHover.hovered ? "#E04040" : "#FF4D4F"
                    Text { anchors.centerIn: parent; text: "离开"; font.pixelSize: 13; font.family: AppTheme.fontFamily; font.weight: Font.Medium; color: "#FFFFFF" }
                    HoverHandler { id: confirmLeaveHover }
                    TapHandler { onTapped: { leaveConfirmDialog.close(); websocket.disconnectFromServer(); } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }

    // ========== 数据 ==========
    property var onlineUsers: []
    property int onlineCount: 0
    property var messages: websocket ? websocket.messages : []
    property var confirmedMsgIds: ({})
    property bool messageAutoScroll: true
    property int prevMsgCount: 0      // 上次消息数，用于判断哪些是新增的
    property bool firstLoad: true     // 首次加载不播动画

    onMessagesChanged: {
        if (firstLoad && messages.length > 0) {
            prevMsgCount = messages.length;
            firstLoad = false;
        }
        if (!firstLoad)
            updateCountTimer.start();
    }

    Timer {
        id: updateCountTimer
        interval: 500
        repeat: false
        onTriggered: root.prevMsgCount = root.messages.length
    }

    // ========== 连接状态横幅 ==========
    Rectangle {
        id: connectionBanner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 0
        color: "#30FFA500"
        clip: true
        visible: height > 0
        z: 10

        Behavior on height { NumberAnimation { duration: 200 } }

        Text {
            anchors.centerIn: parent
            font.pixelSize: 13
            font.family: AppTheme.fontFamily
            color: "#FFA500"
            text: bannerText.text
        }
        Text { id: bannerText; visible: false }
    }

    // ========== 顶栏 ==========
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: connectionBanner.bottom
        height: 52
        color: "transparent"
        z: 5

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: qsTr(websocket ? websocket.Roomid : "")
                font.pixelSize: 20
                font.family: AppTheme.fontFamily
                color: AppTheme.textPrimary
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }

            // 在线人数（hover 显示用户列表）
            Rectangle {
                width: onlineRow.width + 14
                height: 26
                radius: 13
                color: AppTheme.accentDim
                anchors.verticalCenter: parent.verticalCenter
                z: 200

                Row {
                    id: onlineRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: AppTheme.successColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: onlineCount + " 人在线"
                        font.pixelSize: 12
                        font.family: AppTheme.fontFamily
                        color: AppTheme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: onlineHover }

                // 在线用户弹出面板
                Rectangle {
                    visible: onlineHover.hovered
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200
                    height: Math.min(onlineUsers.length * 38 + 64, 280)
                    radius: 10
                    color: AppTheme.bgOverlay
                    border.color: AppTheme.dialogBorder
                    border.width: 1
                    z: 300
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Text {
                            text: "在线用户"
                            font.pixelSize: 13
                            font.family: AppTheme.fontFamily
                            font.weight: Font.Bold
                            color: AppTheme.textPrimary
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: AppTheme.borderSubtle
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 32
                            clip: true
                            spacing: 4
                            model: onlineUsers

                            delegate: Row {
                                spacing: 8
                                height: 32

                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.avatar_url && modelData.avatar_url !== "" ? modelData.avatar_url : "qrc:/image/touxi.jpg"
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 24; height: 24; radius: 12 }
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.nickname || modelData.userId || "未知用户"
                                    font.pixelSize: 12
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textPrimary
                                    elide: Text.ElideRight
                                    width: 130
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // 离开房间按钮
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 90; height: 34; radius: 17
            color: leaveMouseArea.containsMouse ? "#40FF4D4F" : "transparent"
            border.width: 1
            border.color: leaveMouseArea.containsMouse ? "#FF4D4F" : AppTheme.borderDefault

            Text {
                anchors.centerIn: parent
                text: "离开房间"
                font.pixelSize: 13; font.family: AppTheme.fontFamily
                color: leaveMouseArea.containsMouse ? "#FF4D4F" : AppTheme.textMuted
            }

            MouseArea {
                id: leaveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: leaveConfirmDialog.open()
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
    }

    // ========== 消息列表（聊天 + 操作动态统一显示）==========
    ListView {
        id: messageListView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: inputBar.top
        anchors.topMargin: 6
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottomMargin: 6
        clip: true
        spacing: 6
        cacheBuffer: 9999
        model: messages

        onContentHeightChanged: positionViewAtEnd()

        footer: Item { height: 4 }

        delegate: Item {
            id: messageDelegate
            width: messageListView.width
            height: modelData.type === "action" ? actionRow.height + 6 : chatBubble.height + 8

            property bool isNewMsg: false
            property real slideX: 0
            property real msgOpacity: 1

            transform: Translate { x: messageDelegate.slideX }
            opacity: messageDelegate.msgOpacity

            Component.onCompleted: {
                var newMsg = index >= root.prevMsgCount && modelData.status !== "sent";
                if (newMsg) {
                    isNewMsg = true;
                    slideX = -60;
                    msgOpacity = 0;
                    slideInAnim.start();
                }
            }

            ParallelAnimation {
                id: slideInAnim
                NumberAnimation {
                    target: messageDelegate; property: "slideX"
                    from: -60; to: 0; duration: 500; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: messageDelegate; property: "msgOpacity"
                    from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic
                }
            }

            // --- 操作动态 ---
            Row {
                id: actionRow
                visible: modelData.type === "action"
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                height: Math.max(actionAvatar.height, actionText.height + 4)

                Rectangle {
                    id: actionAvatar
                    width: 18; height: 18; radius: 9
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    color: AppTheme.bgInput

                    Image {
                        anchors.fill: parent
                        source: modelData.avatar_url && modelData.avatar_url !== "" ? modelData.avatar_url : "qrc:/image/touxi.jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 18; height: 18; radius: 9 }
                        }
                    }
                }

                Text {
                    id: actionText
                    text: {
                        var d = modelData;
                        var timeStr = "";
                        if (d.time > 0) {
                            var dt = new Date(d.time * 1000);
                            timeStr = Qt.formatTime(dt, "hh:mm") + " ";
                        }
                        return timeStr + (d.nickname || d.userid || "") + " " + (d.message || "");
                    }
                    font.pixelSize: 12
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textSecondary
                    wrapMode: Text.Wrap
                    width: Math.min(messageListView.width - 60, 360)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- 聊天消息 ---
            Row {
                id: chatBubble
                visible: modelData.type === "chat"
                anchors.left: parent.left
                spacing: 8

                // 头像
                Rectangle {
                    width: 28; height: 28; radius: 14
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: modelData.avatarUrl && modelData.avatarUrl !== "" ? modelData.avatarUrl : "qrc:/image/touxi.jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 28; height: 28; radius: 14 }
                        }
                    }
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 6

                        Text {
                            text: modelData.nickname || modelData.userid || "未知"
                            font.pixelSize: 12
                            font.family: AppTheme.fontFamily
                            color: AppTheme.accent
                            font.weight: Font.Medium
                        }

                        Text {
                            text: {
                                if (modelData.time > 0) {
                                    return Qt.formatTime(new Date(modelData.time * 1000), "hh:mm");
                                }
                                return "";
                            }
                            font.pixelSize: 10
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 4
                        anchors.right: parent.right

                        Text {
                            text: modelData.message || ""
                            font.pixelSize: 13
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textSecondary
                            wrapMode: Text.Wrap
                            width: Math.min(messageListView.width - 90, 380)
                        }

                        // 发送状态指示器
                        Item {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            property bool isConfirmed: root.confirmedMsgIds[modelData._msgId] === true
                            visible: (modelData.status === "sending" && !isConfirmed) || modelData.status === "failed"

                            // 发送中：旋转小圈
                            Canvas {
                                id: sendingSpinner
                                anchors.fill: parent
                                visible: modelData.status === "sending" && !parent.isConfirmed
                                property real angle: 0

                                onAngleChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.beginPath();
                                    ctx.arc(8, 8, 5, angle, angle + Math.PI * 1.5);
                                    ctx.strokeStyle = AppTheme.textDim;
                                    ctx.lineWidth = 1.5;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }

                                NumberAnimation on angle {
                                    from: 0; to: Math.PI * 2
                                    duration: 800; loops: Animation.Infinite
                                }
                            }

                            // 发送失败：感叹号
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                visible: modelData.status === "failed"
                                color: "transparent"

                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        ctx.beginPath();
                                        ctx.arc(8, 8, 7, 0, Math.PI * 2);
                                        ctx.fillStyle = "#FF4D4F";
                                        ctx.fill();
                                        ctx.beginPath();
                                        ctx.arc(8, 5.5, 1, 0, Math.PI * 2);
                                        ctx.fillStyle = "#FFFFFF";
                                        ctx.fill();
                                        ctx.beginPath();
                                        ctx.arc(8, 10, 1, 0, Math.PI * 2);
                                        ctx.fillStyle = "#FFFFFF";
                                        ctx.fill();
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData._msgId) {
                                            websocket.retryMessage(modelData._msgId);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== 底部输入栏 ==========
    Rectangle {
        id: inputBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 54
        color: "transparent"

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            TextField {
                id: chatInput
                width: parent.width - sendBtn.width - parent.spacing
                height: 36
                placeholderText: "说点什么..."
                color: AppTheme.textPrimary
                font.pixelSize: 13
                font.family: AppTheme.fontFamily
                verticalAlignment: Text.AlignVCenter
                leftPadding: 14
                background: Rectangle {
                    radius: 18
                    color: AppTheme.bgInput
                    border.color: chatInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderSubtle
                    border.width: 1
                }
                onAccepted: {
                    if (chatInput.text.trim() !== "") {
                        websocket.sendChatMessage(chatInput.text.trim());
                        chatInput.text = "";
                        root.messageAutoScroll = true;
                    }
                }
            }

            Rectangle {
                id: sendBtn
                width: 70; height: 36; radius: 18
                color: sendBtnHover.containsMouse ? AppTheme.accentHover : AppTheme.accent

                Text {
                    anchors.centerIn: parent
                    text: "发送"
                    font.pixelSize: 13; font.family: AppTheme.fontFamily; color: "#FFFFFF"
                }

                MouseArea {
                    id: sendBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (chatInput.text.trim() !== "") {
                            websocket.sendChatMessage(chatInput.text.trim());
                            chatInput.text = "";
                            root.messageAutoScroll = true;
                        }
                    }
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    // ========== 播放列表侧滑抽屉 ==========
    Rectangle {
        id: playlistDrawer
        property bool open: true

        anchors.top: topBar.bottom
        anchors.bottom: inputBar.top
        width: 380
        z: 20
        color: "transparent"

        // 滑动：关闭时只露出 toggleTab(26px)，打开时全部露出
        x: parent.width - (open ? width : 26)

        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        // 切换按钮
        Rectangle {
            id: toggleTab
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 56
            radius: 6
            color: toggleHover.containsMouse ? AppTheme.bgCard : AppTheme.bgInput

            Text {
                anchors.centerIn: parent
                text: playlistDrawer.open ? "›" : "‹"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: AppTheme.textSecondary
            }

            MouseArea {
                id: toggleHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: playlistDrawer.open = !playlistDrawer.open
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // 播放列表面板
        Rectangle {
            anchors.left: toggleTab.right
            anchors.leftMargin: 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 356
            radius: 10
            color: AppTheme.bgOverlay
            border.color: AppTheme.dialogBorder
            border.width: 1
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // 标题 + 控制
                Row {
                    spacing: 12

                    Text {
                        text: qsTr("播放列表")
                        font.pixelSize: 15; font.family: AppTheme.fontFamily
                        color: AppTheme.textPrimary; font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (playlistmanager ? playlistmanager.togetherplaylist.length : 0) + "首"
                        font.pixelSize: 12; font.family: AppTheme.fontFamily
                        color: AppTheme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 8; height: 1 }

                    // 播放/暂停
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: ctrlPlayBtn.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: ctrlPlayIcon; anchors.centerIn: parent
                            source: playlistmanager && !playlistmanager.isPaused ? "qrc:/image/paused.png" : "qrc:/image/play.png"
                            width: 12; height: 12; fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: ctrlPlayIcon; color: AppTheme.textSecondary }
                        }
                        MouseArea {
                            id: ctrlPlayBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: playlistmanager && playlistmanager.isPaused ? websocket.resumeTogether() : websocket.pauseTogether()
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // 下一首
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: nextBtnHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: nextBtnIcon; anchors.centerIn: parent
                            source: "qrc:/image/nextplay.png"; width: 12; height: 12; fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: nextBtnIcon; color: AppTheme.textSecondary }
                        }
                        MouseArea { id: nextBtnHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: websocket.playNextTogether() }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // 刷新
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: refreshHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: refreshIcon; anchors.centerIn: parent
                            source: "qrc:/image/shuaxin.png"; width: 12; height: 12; fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: refreshIcon; color: AppTheme.textSecondary }
                        }
                        MouseArea { id: refreshHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: websocket.requestPlaylist() }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // 分割线
                Rectangle {
                    width: parent.width
                    height: 1
                    color: AppTheme.borderSubtle
                }

                // 歌曲列表
                ListView {
                    id: playlistView
                    width: parent.width
                    height: parent.height - 62
                    clip: true
                    spacing: 2
                    model: playlistmanager ? playlistmanager.togetherplaylist : 0

                    delegate: Rectangle {
                        width: playlistView.width
                        height: 46
                        radius: 6
                        color: {
                            if (playlistmanager && playlistmanager.currentIndex === index)
                                return AppTheme.accentDim;
                            return songHover.hovered ? AppTheme.bgCardHover : "transparent";
                        }

                        HoverHandler { id: songHover }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // 序号 / 播放动画
                            Text {
                                width: 20
                                text: index + 1 <= 9 ? "0" + String(index + 1) : index + 1
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 12; color: AppTheme.textDim
                                visible: !(playlistmanager && playlistmanager.currentIndex === index)
                            }

                            AnimatedImage {
                                width: 20; height: 20
                                source: "qrc:/image/isplaying.gif"
                                playing: visible
                                visible: playlistmanager && playlistmanager.currentIndex === index
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 封面
                            Item {
                                width: 30; height: 30
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    width: 30; height: 30
                                    source: modelData.union_cover
                                    asynchronous: true
                                }

                                // 添加人头像（右下角小图标）
                                Image {
                                    visible: modelData.added_by_avatar.length > 0
                                    width: 14; height: 14
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: -3
                                    anchors.bottomMargin: -3
                                    source: modelData.added_by_avatar
                                    asynchronous: true
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 14; height: 14; radius: 7
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -1
                                        radius: 8
                                        color: "transparent"
                                        border.color: AppTheme.bgCard
                                        border.width: 1.5
                                        z: -1
                                    }
                                }
                            }

                            // 歌名 + 歌手
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    text: modelData.title
                                    font.pixelSize: 12
                                    color: playlistmanager && playlistmanager.currentIndex === index ? AppTheme.accentPlaying : AppTheme.textPrimary
                                    elide: Text.ElideRight
                                    width: 140
                                }
                                Text {
                                    text: modelData.singername
                                    font.pixelSize: 10
                                    color: AppTheme.textMuted
                                    elide: Text.ElideRight
                                    width: 140
                                }
                            }

                            // 悬停操作（固定宽度，用 opacity 避免闪烁）
                            Row {
                                property bool isCurrent: playlistmanager && playlistmanager.currentIndex === index
                                opacity: songHover.hovered ? 1 : 0
                                visible: opacity > 0
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Behavior on opacity { NumberAnimation { duration: 80 } }

                                // 播放按钮（当前歌曲隐藏）
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    visible: !parent.isCurrent
                                    color: iPlayBtnHover.hovered ? AppTheme.iconButtonHover : "transparent"
                                    Image { id: iPlayIco; anchors.centerIn: parent; source: "qrc:/image/playnow.png"; width: 10; height: 10; fillMode: Image.PreserveAspectFit; layer.enabled: true; layer.effect: ColorOverlay { source: iPlayIco; color: AppTheme.textSecondary } }
                                    HoverHandler { id: iPlayBtnHover }
                                    TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.playTogetherByHash(modelData.songhash) }
                                }
                                // 置顶按钮（当前歌曲隐藏）
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    visible: !parent.isCurrent
                                    color: iUpBtnHover.hovered ? AppTheme.iconButtonHover : "transparent"
                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 12; height: 12
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            ctx.strokeStyle = AppTheme.textSecondary;
                                            ctx.lineWidth = 1.5;
                                            ctx.lineCap = ctx.lineJoin = "round";
                                            // 上箭头：先画竖线
                                            ctx.beginPath();
                                            ctx.moveTo(6, 10);
                                            ctx.lineTo(6, 2);
                                            ctx.stroke();
                                            // 箭头头部 V
                                            ctx.beginPath();
                                            ctx.moveTo(2.5, 5.5);
                                            ctx.lineTo(6, 2);
                                            ctx.lineTo(9.5, 5.5);
                                            ctx.stroke();
                                            // 顶部横线（表示"顶"）
                                            ctx.beginPath();
                                            ctx.moveTo(2, 2);
                                            ctx.lineTo(10, 2);
                                            ctx.stroke();
                                        }
                                    }
                                    HoverHandler { id: iUpBtnHover }
                                    TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.upSongByHash(modelData.songhash) }
                                }
                                // 删除按钮（当前歌曲隐藏）
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    visible: !parent.isCurrent
                                    color: iDelBtnHover.hovered ? AppTheme.iconButtonHover : "transparent"
                                    Image { id: iDelIco; anchors.centerIn: parent; source: "qrc:/image/delete_line.png"; width: 10; height: 10; fillMode: Image.PreserveAspectFit; layer.enabled: true; layer.effect: ColorOverlay { source: iDelIco; color: AppTheme.textSecondary } }
                                    HoverHandler { id: iDelBtnHover }
                                    TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.removeSongFromTogether(modelData.songhash) }
                                }
                            }
                        }

                        // 时长
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.duration
                            font.pixelSize: 11; font.family: AppTheme.fontFamily
                            color: AppTheme.textDim
                        }

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }
            }
        }
    }

    // ========== 信号连接 ==========
    Connections {
        target: playlistmanager
        function onTogetherplaylistUpdated() {
            playlistView.model = null;
            playlistView.model = playlistmanager ? playlistmanager.togetherplaylist : 0;
        }
    }

    Connections {
        target: websocket

        function onMessageConfirmed(msgId) {
            var copy = Object.assign({}, confirmedMsgIds);
            copy[msgId] = true;
            confirmedMsgIds = copy;
        }

        function onConnectionStateChanged(state) {
            if (state === 0) {
                connectionBanner.height = 36
                bannerText.text = "连接已断开，正在退出房间..."
                root.firstLoad = true;
                root.prevMsgCount = 0;
                root.confirmedMsgIds = ({});
            } else if (state === 2) {
                connectionBanner.height = 0
                root.firstLoad = true;
                root.prevMsgCount = 0;
                root.confirmedMsgIds = ({});
            }
        }

        function onConnectFail() {
            connectionBanner.height = 36
            bannerText.text = "连接失败，请检查网络后重新加入房间"
        }

        function onClientListUpdated(json) {
            if (json["client_list"] !== undefined) {
                var arr = json["client_list"];
                var users = [];
                for (var i = 0; i < arr.length; i++) users.push(arr[i]);
                onlineUsers = users;
                onlineCount = users.length;
            }
        }

        function onRoomActionsReceived(actions) {
            root.messageAutoScroll = messageListView.atYEnd || messageListView.contentHeight <= messageListView.height
        }

        function onChatMessageReceived(userid, nickname, avatarUrl, message, timestamp) {
            root.messageAutoScroll = true
        }
    }

    Component.onCompleted: {
        if (websocket && websocket.connected) {
            websocket.requestClientList();
        }
        messageListView.positionViewAtEnd();
    }
}
