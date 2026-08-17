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

    // 沉浸遮罩：渐变激活时统一白系半透明——深色渐变用低浓度（12%）、浅色渐变用
    // 高浓度（20% 以上，浅底上隐约可见）——用户要求全程不用黑色系遮罩。
    // 无渐变时回退主题卡片色（用户选定：浅色无渐变=纯卡色无边框）。
    // tint 作为函数绑定会在 playlistCoverColor / 主题变化时自动重算。
    readonly property bool gradientDark: BasicConfig.playlistCoverColor !== ""
        && BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent) === "#FFFFFF"
    function tint(darkHex, lightHex, fallback) {
        if (BasicConfig.playlistCoverColor === "") return fallback
        return gradientDark ? darkHex : lightHex
    }

    // 瞬态滚动条:仅滚动时淡入,停止 800ms 后淡出。
    // visible 绑定 size<1(内容超出视口才可滚动)做硬性门控 —— 不可滚动时
    // 彻底隐藏、不响应鼠标;透明状态也不靠 hover 触发,避免鼠标扫过就闪现
    component TransientScrollBar: ScrollBar {
        id: sb
        policy: ScrollBar.AsNeeded
        visible: size < 1.0
        implicitWidth: 8
        opacity: 0

        contentItem: Rectangle {
            width: 6
            radius: 3
            color: AppTheme.isDark ? "#99FFFFFF" : "#99000000"
        }
        background: null

        onActiveChanged: {
            if (active) {
                opacity = 0.9
                hideTimer.stop()
            } else {
                hideTimer.restart()
            }
        }
        onPressedChanged: {
            if (pressed) {
                opacity = 0.9
                hideTimer.stop()
            }
        }

        Timer {
            id: hideTimer
            interval: 800
            onTriggered: {
                if (!sb.pressed && !sb.active)
                    sb.opacity = 0
            }
        }

        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

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
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: AppTheme.animFast; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: AppTheme.animFast; easing.type: Easing.InCubic }
        }

        Column {
            spacing: 20
            width: parent.width

            Text {
                text: "确认离开房间？"
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.family: AppTheme.fontFamily
                font.weight: Font.Bold
                color: AppTheme.textPrimary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "离开后将无法继续与好友同步听歌"
                font.pixelSize: AppTheme.fontSizeBody
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
                    Text { anchors.centerIn: parent; text: "取消"; font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; color: AppTheme.textSecondary }
                    HoverHandler { id: cancelLeaveHover }
                    TapHandler { onTapped: leaveConfirmDialog.close() }
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                }

                Rectangle {
                    width: 100; height: 36; radius: 8
                    color: confirmLeaveHover.hovered ? Qt.darker(AppTheme.errorColor, 1.15) : AppTheme.errorColor
                    Text { anchors.centerIn: parent; text: "离开"; font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; font.weight: Font.DemiBold; color: "#FFFFFF" }
                    HoverHandler { id: confirmLeaveHover }
                    TapHandler { onTapped: { leaveConfirmDialog.close(); websocket.disconnectFromServer(); } }
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                }
            }
        }
    }

    // ========== 数据 ==========
    property var onlineUsers: []
    property int onlineCount: 0
    // 消息列表是 C++ 的 QAbstractListModel(指针恒定,行级增量更新),
    // 不再是每次整体替换的 JS 数组 —— ListView 不会整表销毁重建 delegate。
    // 左栏聊天 / 右栏系统动态,从 C++ 侧分流
    property var chatMessages: websocket ? websocket.chatMessages : null
    property var actionMessages: websocket ? websocket.actionMessages : null
    property int chatCount: chatMessages ? chatMessages.count : 0
    property int actionCount: actionMessages ? actionMessages.count : 0
    property var confirmedMsgIds: ({})
    property var roomSongData: ({})   // 房间当前播放歌曲（由 songInfoUpdated 广播更新，驱动顶部「正在播放」卡）
    property int prevMsgCount: 0      // 上次消息数，用于判断哪些是新增的
    property bool firstLoad: true     // 首次加载不播动画

    onChatCountChanged: {
        if (firstLoad && chatCount > 0) {
            prevMsgCount = chatCount;
            firstLoad = false;
        }
        if (!firstLoad)
            updateCountTimer.start();
    }

    Timer {
        id: updateCountTimer
        interval: 500
        repeat: false
        onTriggered: root.prevMsgCount = root.chatCount
    }

    // ========== 连接状态横幅 ==========
    Rectangle {
        id: connectionBanner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 0
        color: "#30FF4D4F"
        clip: true
        visible: height > 0
        z: 10

        Behavior on height { NumberAnimation { duration: 200 } }

        Text {
            anchors.centerIn: parent
            font.pixelSize: AppTheme.fontSizeBody
            font.family: AppTheme.fontFamily
            color: AppTheme.errorColor
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
                font.pixelSize: AppTheme.fontSizeHeadline
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
                        font.pixelSize: AppTheme.fontSizeSmall
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
                            font.pixelSize: AppTheme.fontSizeBody
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
                                        // 只认 http(s) 头像：网页游客曾传网页相对路径 /images/app-icon.png，
                                        // 按 qrc 解析成不存在的资源刷 Cannot open 警告
                                        source: modelData.avatar_url && String(modelData.avatar_url).indexOf("http") === 0
                                            ? modelData.avatar_url : "qrc:/image/touxi.jpg"
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
                                    font.pixelSize: AppTheme.fontSizeSmall
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
            color: leaveMouseArea.containsMouse ? AppTheme.accentGlow : "transparent"
            border.width: 1
            // 渐变时边框随背景对比色，保证任何封面下都看得清
            border.color: leaveMouseArea.containsMouse ? AppTheme.errorColor
                : (BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.borderDefault)

            Text {
                anchors.centerIn: parent
                text: "离开房间"
                font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily
                // 渐变激活时按背后颜色自动挑白/深字，保证任何封面下都看得清
                color: leaveMouseArea.containsMouse ? AppTheme.errorColor
                     : (BasicConfig.playlistCoverColor !== ""
                        ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                        : AppTheme.textMuted)
            }

            MouseArea {
                id: leaveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: leaveConfirmDialog.open()
            }
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
            Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
        }
    }

    // ========== 房间「正在播放」卡（点击展开/收起全部播放列表）==========
    // 数据来自房间广播 songInfoUpdated；无歌曲时高度 0（不占位，消息列表无需重排）
    Rectangle {
        id: heroCard
        property bool listExpanded: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.topMargin: 6
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        // 无歌 0；有歌收起 68；展开时加播放列表（heroList 含 header，空列表占 130 显示引导）
        height: root.roomSongData.songname
                ? (listExpanded
                    ? 68 + (playlistmanager && playlistmanager.togetherplaylist.count > 0
                            ? heroList.height
                            : 130)
                    : 68)
                : 0
        radius: 16
        clip: true
        // 沉浸：渐变时半透明卡（深色渐变白/浅色渐变黑），无渐变时回退主题卡片色
        color: root.tint("#12FFFFFF", "#33FFFFFF", AppTheme.bgCard)
        border.width: 1
        border.color: root.tint("#1EFFFFFF", "#40FFFFFF", "transparent")
        opacity: root.roomSongData.songname ? 1 : 0

        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }

        // ---- 上部：封面 + 歌名 + 状态 + 展开箭头（整行点击展开/收起）----
        Item {
            id: heroTopRow
            width: parent.width
            height: 68

            Rectangle {
                id: heroCover
                width: 48; height: 48; radius: 10
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.roomSongData.cover_url || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: heroCover.width; height: heroCover.height; radius: 10 }
                    }
                }
            }

            Column {
                anchors.left: heroCover.right
                anchors.leftMargin: 12
                anchors.right: heroExpandArrow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.roomSongData.songname || ""
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: AppTheme.textSongTitle
                }

                Row {
                    spacing: 6

                    NowPlayingIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.roomSongData.is_playing !== 0
                        playing: playlistmanager ? !playlistmanager.isPaused : true
                    }

                    Text {
                        text: root.roomSongData.is_playing === 0 ? "已暂停" : "同步播放中"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        color: root.roomSongData.is_playing === 0 ? AppTheme.textDim : AppTheme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 展开/收起箭头
            Image {
                id: heroExpandArrow
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                source: AppIcon.caretDown
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(128, 128)
                mipmap: true
                rotation: heroCard.listExpanded ? 180 : 0
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: heroExpandArrow
                    color: heroTopHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary
                }
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            HoverHandler { id: heroTopHover }
            // 点击卡片上部：展开/收起全部播放列表
            TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: heroCard.listExpanded = !heroCard.listExpanded }
        }

        // ---- 展开的播放列表（header：数量 + 下一曲 + 刷新）----
        ListView {
            id: heroList
            visible: heroCard.listExpanded && root.roomSongData.songname
                     && playlistmanager && playlistmanager.togetherplaylist.count > 0
            anchors.top: heroTopRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: playlistmanager && playlistmanager.togetherplaylist.count > 0
                ? Math.min(playlistmanager.togetherplaylist.count * 46, 260) + 40
                : 0
            clip: true
            spacing: 2
            cacheBuffer: 1200
            model: playlistmanager ? playlistmanager.togetherplaylist : 0

            header: Item {
                width: heroList.width
                height: 40

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "播放列表"
                        font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily
                        color: AppTheme.textPrimary; font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (playlistmanager ? playlistmanager.togetherplaylist.count : 0) + "首"
                        font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily
                        color: AppTheme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // 下一曲
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: nextBtnHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: nextBtnIcon; anchors.centerIn: parent
                            source: AppIcon.next; width: 12; height: 12; fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: nextBtnIcon; color: AppTheme.textSecondary }
                        }
                        MouseArea { id: nextBtnHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: websocket.playNextTogether() }
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }

                    // 刷新
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: refreshHover.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: refreshIcon; anchors.centerIn: parent
                            source: AppIcon.refresh; width: 12; height: 12; fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: refreshIcon; color: AppTheme.textSecondary }
                        }
                        MouseArea { id: refreshHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: websocket.requestPlaylist() }
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }
                }
            }

            delegate: Rectangle {
                width: heroList.width
                height: 46
                radius: 6
                // hover/播放改为文字高亮（背景透明，渐变下无块状覆盖层）
                color: "transparent"

                HoverHandler { id: songHover }
                // 整行小手光标（悬停行，点击动作在右侧按钮上）
                TapHandler { cursorShape: Qt.PointingHandCursor }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // 序号 / 播放动画
                    Text {
                        width: 20
                        text: (index + 1).toString().padStart(2, "0")
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: AppTheme.fontSizeSmall; color: AppTheme.textDim
                        visible: !(playlistmanager && playlistmanager.currentIndex === index)
                    }

                    NowPlayingIndicator {
                        visible: playlistmanager && playlistmanager.currentIndex === index
                        playing: playlistmanager ? !playlistmanager.isPaused : true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: 30; height: 30
                        anchors.verticalCenter: parent.verticalCenter

                        // 封面（OpacityMask 真正圆角，clip 只裁矩形）
                        Rectangle {
                            id: songCover
                            width: 30; height: 30; radius: 6
                            color: root.tint("#12FFFFFF", "#33FFFFFF", AppTheme.bgCard)

                            Image {
                                anchors.fill: parent
                                source: model.union_cover
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: songCover.width; height: songCover.height; radius: 6 }
                                }
                            }
                        }

                        // 添加人头像（右下角小图标）
                        Image {
                            visible: model.added_by_avatar.length > 0
                            width: 14; height: 14
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -3
                            anchors.bottomMargin: -3
                            source: model.added_by_avatar
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
                                border.color: root.tint("#1EFFFFFF", "#40FFFFFF", "transparent")
                                border.width: 1.5
                                z: -1
                            }
                        }
                    }

                    Column {
                        width: heroList.width - 230
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: model.title
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.bold: true
                            color: playlistmanager && playlistmanager.currentIndex === index ? AppTheme.accentPlaying : (songHover.hovered ? AppTheme.accentPlaying : AppTheme.textSongTitle)
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: model.singername
                            font.pixelSize: AppTheme.fontSizeXs
                            font.bold: true
                            color: AppTheme.textMuted
                            elide: Text.ElideRight
                            width: parent.width
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
                            Image { id: iPlayIco; anchors.centerIn: parent; source: AppIcon.playCircle; width: 10; height: 10; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(128, 128); mipmap: true; layer.enabled: true; layer.effect: ColorOverlay { source: iPlayIco; color: AppTheme.textSecondary } }
                            HoverHandler { id: iPlayBtnHover }
                            TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.playTogetherByHash(model.songhash) }
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
                            TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.upSongByHash(model.songhash) }
                        }
                        // 删除按钮（当前歌曲隐藏）
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            visible: !parent.isCurrent
                            color: iDelBtnHover.hovered ? AppTheme.iconButtonHover : "transparent"
                            Image { id: iDelIco; anchors.centerIn: parent; source: AppIcon.deleteIcon; width: 10; height: 10; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(128, 128); mipmap: true; layer.enabled: true; layer.effect: ColorOverlay { source: iDelIco; color: AppTheme.textSecondary } }
                            HoverHandler { id: iDelBtnHover }
                            TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: websocket.removeSongFromTogether(model.songhash) }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    // 空时长（历史遗留的 FM 歌等）兜底显示，不空白
                    text: model.duration || "--:--"
                    font.pixelSize: AppTheme.fontSizeCaption; font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                }
            }
        }

        // 播放列表空状态（展开且无歌时显示）
        Column {
            visible: heroCard.listExpanded && root.roomSongData.songname
                     && playlistmanager && playlistmanager.togetherplaylist.count === 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: heroTopRow.bottom
            anchors.topMargin: 18
            spacing: 8

            Rectangle {
                width: 52; height: 52; radius: 26
                color: AppTheme.accentSubtle
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 24
                    color: AppTheme.accent
                }
            }

            Text {
                text: "还没有歌曲"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.family: AppTheme.fontFamily
                color: AppTheme.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "去搜索页点「一起听」加歌吧"
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
                color: AppTheme.textDim
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ========== 左半：聊天（自己右侧 / 别人左侧，微信风格）+ 输入栏 ==========
    Item {
        id: chatPane
        anchors.left: parent.left
        anchors.top: heroCard.bottom
        anchors.bottom: parent.bottom
        width: parent.width * 0.5

        ListView {
            id: messageListView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: inputBar.top
            anchors.topMargin: 10
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            anchors.bottomMargin: 6
            clip: true
            spacing: 6
            cacheBuffer: 1000
            model: chatMessages

        // 是否自动滚动到底部（用户在底部附近时为 true，手动上滑后变 false）
        property bool _autoScroll: true

        // 用户拖动 / 惯性滑动时判断是否在底部附近
        onContentYChanged: {
            if (moving || flicking) {
                _autoScroll = (contentY + height >= contentHeight - 30)
            }
        }
        onMovementEnded: {
            _autoScroll = (contentY + height >= contentHeight - 30)
        }

        // 消息数量变化（新增/替换 model）时，如果在底部则滚动到底
        onCountChanged: {
            if (_autoScroll) {
                Qt.callLater(positionViewAtEnd)
            }
        }

        // 行数变化时 positionViewAtEnd 按估算行高定位,delegate 实例化后真实
        // 高度确定的瞬间 contentHeight 会再变一次,此处再贴底校准,确保真正到底
        onContentHeightChanged: {
            if (_autoScroll) {
                Qt.callLater(positionViewAtEnd)
            }
        }

        // 滚动时短暂出现的滚动条
        ScrollBar.vertical: TransientScrollBar { }

        footer: Item { height: 4 }

        delegate: Item {
            id: messageDelegate
            width: messageListView.width
            // 微信式判断：userid 是自己 → 消息靠右
            property bool isMine: userManager && modelData.userid === userManager.userid
            height: bubbleCol.height + 8

            property bool isNewMsg: false
            property real slideX: 0
            property real msgOpacity: 1

            transform: Translate { x: messageDelegate.slideX }
            opacity: messageDelegate.msgOpacity

            Component.onCompleted: {
                var newMsg = index >= root.prevMsgCount && modelData.status !== "sent";
                if (newMsg) {
                    isNewMsg = true;
                    slideX = messageDelegate.isMine ? 60 : -60;
                    msgOpacity = 0;
                    slideInAnim.start();
                }
            }

            ParallelAnimation {
                id: slideInAnim
                NumberAnimation {
                    target: messageDelegate; property: "slideX"
                    from: messageDelegate.isMine ? 60 : -60; to: 0; duration: 500; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: messageDelegate; property: "msgOpacity"
                    from: 0; to: 1; duration: AppTheme.animSlow; easing.type: Easing.OutCubic
                }
            }

            // 微信式排布：自己 → 头像在右、气泡靠右；别人 → 头像在左、气泡靠左
            Row {
                spacing: 8
                layoutDirection: messageDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight
                width: parent.width

                // 头像
                Rectangle {
                    width: 28; height: 28; radius: 14
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        // 同成员列表：非 http(s) 头像一律走内置兜底，避免无效 qrc 路径警告
                        source: modelData.avatarUrl && String(modelData.avatarUrl).indexOf("http") === 0
                            ? modelData.avatarUrl : "qrc:/image/touxi.jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 28; height: 28; radius: 14 }
                        }
                    }
                }

                // Column 的子项只能左贴(不支持行内右对齐),自己消息的气泡会被顶到
                // 时间行的最左端;改用 Item + x 定位,按 isMine 贴对应边
                Item {
                    id: bubbleCol
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(nameRow.width, bubbleRow.width)
                    height: nameRow.height + 2 + bubbleRow.height

                    // 昵称 + 时间
                    Row {
                        id: nameRow
                        spacing: 6
                        layoutDirection: messageDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight
                        x: messageDelegate.isMine ? bubbleCol.width - width : 0

                        Text {
                            text: modelData.nickname || modelData.userid || "未知"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.family: AppTheme.fontFamily
                            color: messageDelegate.isMine ? AppTheme.accent : AppTheme.textDim
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: modelData.time > 0 ? Qt.formatTime(new Date(modelData.time * 1000), "hh:mm") : ""
                            font.pixelSize: AppTheme.fontSizeXs
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 气泡 + 发送状态
                    Row {
                        id: bubbleRow
                        spacing: 4
                        layoutDirection: messageDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight
                        x: messageDelegate.isMine ? bubbleCol.width - width : 0
                        y: nameRow.height + 2

                        Rectangle {
                            id: chatBubbleRect
                            width: bubbleText.width + 24
                            height: bubbleText.height + 14
                            radius: 10
                            color: messageDelegate.isMine
                                       ? AppTheme.accentDim
                                       : root.tint("#12FFFFFF", "#33FFFFFF", AppTheme.bgCard)
                            border.width: 1
                            border.color: messageDelegate.isMine
                                              ? AppTheme.accentSubtle
                                              : root.tint("#1EFFFFFF", "#40FFFFFF", "transparent")

                            Text {
                                id: bubbleText
                                anchors.centerIn: parent
                                text: modelData.message || ""
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                color: messageDelegate.isMine ? AppTheme.textPrimary : AppTheme.textSecondary
                                wrapMode: Text.Wrap
                                width: Math.min(implicitWidth, messageListView.width - 120)
                            }
                        }

                        // 发送状态指示器（仅自己的消息有 status）
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

    // ========== 聊天空状态 ==========
    Column {
        anchors.centerIn: messageListView
        visible: chatCount === 0
        spacing: 8

        Rectangle {
            width: 56; height: 56; radius: 28
            color: AppTheme.accentSubtle
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 26
                color: AppTheme.accent
            }
        }

        Text {
            text: "房间还很安静"
            font.pixelSize: AppTheme.fontSizeBodyLg
            font.family: AppTheme.fontFamily
            color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "说点什么，或点一首歌一起听"
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            // 浅色主题下 textDim 太浅看不见，直接黑色
            color: AppTheme.isDark ? AppTheme.textDim : "#000000"
            anchors.horizontalCenter: parent.horizontalCenter
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
                // 浅色主题下文字/占位符直接黑色（浅色渐变上黑字清晰），深色保持渐变感知白字
                color: AppTheme.isDark
                    ? (BasicConfig.playlistCoverColor !== ""
                        ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                        : AppTheme.textPrimary)
                    : "#000000"
                palette.placeholderText: AppTheme.isDark
                    ? (BasicConfig.playlistCoverColor !== ""
                        ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                        : AppTheme.textPlaceholder)
                    : "#000000"
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
                verticalAlignment: Text.AlignVCenter
                leftPadding: 14
                background: Rectangle {
                    radius: 18
                    // 沉浸：渐变时半透明（深色渐变白/浅色渐变黑），无渐变时主题输入底色
                    // idle 边框：深色主题白边、浅色主题黑边，聚焦变红
                    color: root.tint("#1EFFFFFF", "#40FFFFFF", AppTheme.bgInput)
                    border.color: chatInput.activeFocus ? AppTheme.borderFocus
                        : (AppTheme.isDark ? "#FFFFFF" : "#000000")
                    border.width: 1
                }
                onAccepted: {
                    if (chatInput.text.trim() !== "") {
                        websocket.sendChatMessage(chatInput.text.trim());
                        chatInput.text = "";
                        messageListView._autoScroll = true;
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
                    font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; color: "#FFFFFF"
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
                            messageListView._autoScroll = true;
                        }
                    }
                }
                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
            }
        }
    }
    }   // chatPane 结束

    // 左右分栏分隔线
    Rectangle {
        width: 1
        anchors.left: chatPane.right
        anchors.top: heroCard.bottom
        anchors.bottom: parent.bottom
        color: AppTheme.borderSubtle
    }

    // ========== 右半：房间动态（系统消息）==========
    Item {
        id: actionPane
        anchors.left: chatPane.right
        anchors.leftMargin: 1
        anchors.right: parent.right
        anchors.top: heroCard.bottom
        anchors.bottom: parent.bottom

        Text {
            id: actionPaneTitle
            text: "房间动态"
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            color: AppTheme.textDim
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
        }

        ListView {
            id: actionListView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 16
            anchors.top: actionPaneTitle.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            clip: true
            spacing: 6
            cacheBuffer: 1000
            model: actionMessages

            // 与聊天列表相同的"贴底自动滚动/上滑停止"策略
            property bool _autoScroll: true
            onContentYChanged: {
                if (moving || flicking)
                    _autoScroll = (contentY + height >= contentHeight - 30)
            }
            onMovementEnded: {
                _autoScroll = (contentY + height >= contentHeight - 30)
            }
            onCountChanged: {
                if (_autoScroll)
                    Qt.callLater(positionViewAtEnd)
            }
            // 同聊天列表:估算行高定位后再按真实 contentHeight 校准一次,确保贴底
            onContentHeightChanged: {
                if (_autoScroll)
                    Qt.callLater(positionViewAtEnd)
            }

            ScrollBar.vertical: TransientScrollBar { }

            footer: Item { height: 4 }

            delegate: Item {
                id: actionDelegate
                width: actionListView.width
                height: actionPill.height + 10

                HoverHandler { id: actionHover }

                // 时间：鼠标放上时淡入，紧贴胶囊右侧
                Text {
                    id: actionTime
                    anchors.left: actionPill.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: actionHover.hovered && modelData.time > 0
                    opacity: actionHover.hovered ? 1 : 0
                    text: Qt.formatTime(new Date(modelData.time * 1000), "hh:mm")
                    font.pixelSize: AppTheme.fontSizeXs
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                // 半透明白胶囊：渐变下融入背景，无渐变时回退主题卡片色
                Rectangle {
                    id: actionPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: actionText.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: root.tint("#12FFFFFF", "#33FFFFFF", AppTheme.bgCard)
                    border.width: 1
                    border.color: root.tint("#1EFFFFFF", "#40FFFFFF", "transparent")

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: (modelData.nickname || modelData.userid || "") + " " + (modelData.message || "")
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textSecondary
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, actionListView.width - 60)
                    }
                }
            }
        }

        // 动态空状态（浅色主题下 textDim 太浅，直接黑色）
        Text {
            anchors.centerIn: actionListView
            visible: actionCount === 0
            text: "暂无房间动态"
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            color: AppTheme.isDark ? AppTheme.textDim : "#000000"
            opacity: 0.6
        }
    }

    // ========== 信号连接 ==========
    // togetherplaylist 现为 QAbstractListModel，列表变化由 model 自身信号驱动，
    // 不再需要手动 model=null 重置（原置换会丢失滚动位置并触发入场动画）。

    Connections {
        target: websocket

        function onMessageConfirmed(msgId) {
            var copy = Object.assign({}, confirmedMsgIds);
            copy[msgId] = true;
            confirmedMsgIds = copy;
        }

        // 房间广播歌曲信息 → 驱动「正在播放」卡
        function onSongInfoUpdated(data) {
            root.roomSongData = data;
        }

        function onConnectionStateChanged(state) {
            if (state === 0) {
                connectionBanner.height = 36
                bannerText.text = "连接已断开，正在退出房间..."
                root.firstLoad = true;
                root.prevMsgCount = 0;
                root.confirmedMsgIds = ({});
                root.roomSongData = ({});
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
            // 新系统动态到达时，仅在用户已在底部时自动滚动
            if (actionListView._autoScroll) {
                Qt.callLater(actionListView.positionViewAtEnd)
            }
        }

        function onChatMessageReceived(userid, nickname, avatarUrl, message, timestamp) {
            messageListView._autoScroll = true
            Qt.callLater(messageListView.positionViewAtEnd)

            // 不在当前页面时，弹出系统通知
            if (!root.visible && trayHandler) {
                trayHandler.showMessage(
                    "网狗音乐 - " + (nickname || "未知用户"),
                    message,
                    3000
                );
            }
        }
    }

    // 切回本页(Rightpage 的 pageLoaders 只切 visible/opacity,页面常驻)时,
    // 若离开前列表在底部,确保滚到最新消息;离开前在翻历史则保留原位置
    onVisibleChanged: {
        if (!visible)
            return
        if (messageListView._autoScroll)
            Qt.callLater(messageListView.positionViewAtEnd)
        if (actionListView._autoScroll)
            Qt.callLater(actionListView.positionViewAtEnd)
    }

    Component.onCompleted: {
        if (websocket && websocket.connected) {
            websocket.requestClientList();
        }
        // 延迟到下一帧执行，确保 delegate 已完成布局
        messageListView._autoScroll = true;
        actionListView._autoScroll = true;
        Qt.callLater(actionListView.positionViewAtEnd);
        Qt.callLater(messageListView.positionViewAtEnd);
    }
}
