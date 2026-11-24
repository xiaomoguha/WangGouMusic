import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

/*
 * 一起听 · 三栏布局
 * 左：房间信息 / 成员    中：正在播放 / 队列 / 点歌    右：聊天 + 房间动态时间线
 * 设计约束：
 *  - 不使用封面取色沉浸背景，统一 AppTheme
 *  - 无主持人 / 无投票；所有人都可以切歌、置顶、删歌
 *  - 系统动态与聊天气泡按时间合并到同一列（C++ timelineMessages）
 */
Item {
    id: root
    objectName: "togethermusic"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    clip: true

    readonly property bool compact: width < 820
    property var onlineUsers: []
    property int onlineCount: 0

    // C++ 侧合并后的单一时间线（聊天 + 房间动态）
    property var timelineMessages: websocket ? websocket.timelineMessages : null
    property int timelineCount: timelineMessages ? timelineMessages.count : 0
    property var confirmedMsgIds: ({})
    property var roomSongData: ({})
    property int prevTimelineCount: 0
    property bool firstLoad: true
    property string requestKeyword: ""

    // 一起听点赞：likeRevision 作为依赖，让 nowCard 通过 get(hash) 读取的点赞刷新
    readonly property int likeRevision: playlistmanager && playlistmanager.togetherplaylist
                                        ? playlistmanager.togetherplaylist.likeRevision : 0
    readonly property var currentQueueSong: {
        likeRevision
        var pl = playlistmanager ? playlistmanager.togetherplaylist : null
        if (!pl || !roomSongData.songhash) return null
        var idx = pl.indexOfHash(roomSongData.songhash)
        return idx >= 0 ? pl.get(idx) : null
    }
    readonly property int currentLikeCount: currentQueueSong ? (currentQueueSong.like_count || 0) : 0
    readonly property bool currentLiked: {
        var s = currentQueueSong
        if (!s || !userManager) return false
        var arr = s.liked_by || []
        return arr.indexOf(userManager.userid) >= 0
    }
    readonly property string nowPlayingStatus: {
        if (!roomSongData || roomSongData.is_playing === 0) return "已暂停"
        var q = currentQueueSong
        var source = q ? (q.recommend_source || "") : ""
        var by = q ? (q.added_by_nickname || "") : ""
        if (source.length > 0) {
            if (by.length === 0 || by === "系统推荐" || by === "系统")
                return "正在播放由「" + source + "」自动推荐的歌曲"
            return "正在播放 " + by + " 推荐的歌曲"
        }
        return "正在播放"
    }

    // ==================== 通用小组件 ====================

    component TransientScrollBar: ScrollBar {
        id: sb
        policy: ScrollBar.AsNeeded
        visible: size < 1.0
        implicitWidth: 8
        opacity: 0

        contentItem: Rectangle {
            width: 6
            radius: 3
            color: AppTheme.scrollbarColor
        }
        background: null

        onActiveChanged: {
            if (active) {
                opacity: 0.9
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

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: pillText.implicitWidth + 30
        implicitHeight: 30
        width: implicitWidth
        height: implicitHeight
        radius: 15
        color: primary
               ? (pillHover.hovered ? AppTheme.accentHover : AppTheme.accent)
               : (pillHover.hovered ? AppTheme.iconButtonHover : "transparent")
        border.width: primary ? 0 : 1
        border.color: AppTheme.borderDefault

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            font.weight: pill.primary ? Font.DemiBold : Font.Normal
            color: pill.primary ? "#FFFFFF" : AppTheme.textSecondary
        }

        HoverHandler { id: pillHover }
        TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: pill.clicked() }
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
    }

    component IconButton: Rectangle {
        id: iconBtn
        property string iconSource: ""
        property color iconColor: AppTheme.textSecondary
        property string tooltip: ""
        property int diameter: 30
        signal clicked()

        width: diameter
        height: diameter
        radius: diameter / 2
        color: iconHover.hovered ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: iconImage
            anchors.centerIn: parent
            source: iconBtn.iconSource
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(128, 128)
            mipmap: true
            layer.enabled: true
            layer.effect: ColorOverlay { source: iconImage; color: iconBtn.iconColor }
        }

        HoverHandler { id: iconHover }
        TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: iconBtn.clicked() }
        ToolTip {
            id: iconTip
            visible: iconHover.hovered && iconBtn.tooltip !== ""
            text: iconBtn.tooltip
            padding: 8
            x: Math.round((iconBtn.width - width) / 2)
            y: -height - 6
            z: 100
            background: Rectangle {
                radius: 10
                color: AppTheme.bgOverlay
                border.color: AppTheme.dialogBorder
                border.width: 1
            }
            contentItem: Text {
                text: iconBtn.tooltip
                color: AppTheme.textSecondary
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
    }

    // 表情右键菜单项：与全局歌曲右键菜单（ContextMenuItem）保持同一套视觉
    component StickerMenuItem: MenuItem {
        id: stickerMenuItem
        property string iconSource: ""
        property bool danger: false

        height: 34

        background: Rectangle {
            radius: 6
            color: stickerMenuItem.hovered
                   ? (stickerMenuItem.danger ? "#33FF6B6B" : AppTheme.bgNavHover)
                   : "transparent"
        }

        contentItem: Item {
            implicitHeight: 34

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Image {
                    width: 14
                    height: 14
                    source: stickerMenuItem.iconSource
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: stickerMenuItem.danger
                               ? AppTheme.errorColor
                               : (stickerMenuItem.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                    }
                }

                Text {
                    text: stickerMenuItem.text
                    color: stickerMenuItem.danger
                           ? AppTheme.errorColor
                           : (stickerMenuItem.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
            }
        }
    }

    // ==================== 工具函数 ====================

    function sendChatText() {
        var text = chatInput.text.trim()
        if (text === "" || !websocket)
            return
        websocket.sendChatMessage(text)
        chatInput.text = ""
        timelineList._autoScroll = true
        Qt.callLater(timelineList.positionViewAtEnd)
    }

    function sendSticker(id) {
        if (!websocket || !stickers || id === "")
            return
        if (stickers.pathFor(id) === "")
            return
        websocket.sendChatMessage("[sticker]" + id)
        stickers.markRecent(id)
        timelineList._autoScroll = true
        Qt.callLater(timelineList.positionViewAtEnd)
    }

    function copyInvite() {
        if (!websocket || !websocket.Roomid)
            return
        clipboardHelper.text = "一起来听歌！房间号：" + websocket.Roomid
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        BasicConfig.noticeSuccess("房间号已复制")
    }

    function timeLabel(secs) {
        if (!secs || secs <= 0)
            return ""
        var d = new Date(secs * 1000)
        var now = new Date()
        var hm = Qt.formatTime(d, "hh:mm")
        if (d.getFullYear() === now.getFullYear()
                && d.getMonth() === now.getMonth()
                && d.getDate() === now.getDate())
            return hm
        var y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)
        if (d.getFullYear() === y.getFullYear()
                && d.getMonth() === y.getMonth()
                && d.getDate() === y.getDate())
            return "昨天 " + hm
        return Qt.formatDate(d, "MM-dd") + " " + hm
    }

    function stickerItems() {
        var arr = [""]
        if (!stickers)
            return arr
        var rev = stickers.revision
        var rec = stickers.recent
        var lib = stickers.library
        var src = (chatPane.stickerTab === "recent" && rec.length > 0) ? rec : lib
        for (var i = 0; i < src.length; i++)
            arr.push(src[i])
        return arr
    }

    function searchSongs() {
        if (!togetherSearch)
            return
        var kw = requestInput.text.trim()
        if (kw === "")
            return
        requestKeyword = kw
        togetherSearch.fetchComplexData(kw)
    }

    // ==================== 背景 ====================

    Rectangle {
        anchors.fill: parent
        color: AppTheme.bgContent
    }

    onTimelineCountChanged: {
        if (firstLoad && timelineCount > 0) {
            prevTimelineCount = timelineCount
            firstLoad = false
        }
        if (!firstLoad)
            updateCountTimer.start()
    }

    Timer {
        id: updateCountTimer
        interval: 500
        repeat: false
        onTriggered: root.prevTimelineCount = root.timelineCount
    }

    // 复制房间号用的隐藏输入框（QML 没有全局剪贴板 API）
    TextEdit {
        id: clipboardHelper
        width: 1
        height: 1
        opacity: 0
        readOnly: false
    }

    // ==================== 离开确认 ====================

    Dialog {
        id: leaveConfirmDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: ""
        closePolicy: Popup.CloseOnEscape
        width: 300
        padding: 24

        onAboutToShow: BasicConfig.pushModalInputLock(leaveConfirmDialog)
        onClosed: BasicConfig.popModalInputLock(leaveConfirmDialog)
        Component.onDestruction: BasicConfig.popModalInputLock(leaveConfirmDialog)

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

    // ==================== 连接横幅 ====================

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

    // ==================== 顶栏 ====================

    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: connectionBanner.bottom
        height: 56
        color: "transparent"
        z: 5

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: "一起听"
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.family: AppTheme.fontFamily
                font.weight: Font.Bold
                color: AppTheme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: roomIdText.implicitWidth + 22
                height: 26
                radius: 13
                color: AppTheme.bgInput
                border.width: 1
                border.color: AppTheme.borderSubtle
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: roomIdText
                    anchors.centerIn: parent
                    text: "房间 " + (websocket ? websocket.Roomid : "")
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textSecondary
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // 在线人数（hover 展开成员列表；左栏收起时也可用）
            Rectangle {
                width: onlineRow.width + 16
                height: 28
                radius: 14
                color: AppTheme.accentDim
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: onlineRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 7; height: 7; radius: 3.5
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

                Rectangle {
                    visible: onlineHover.hovered
                    anchors.top: parent.bottom
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 210
                    height: Math.min(onlineUsers.length * 38 + 66, 300)
                    radius: 12
                    color: AppTheme.bgOverlay
                    border.color: AppTheme.dialogBorder
                    border.width: 1
                    z: 600
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "在线成员"
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            font.weight: Font.Bold
                            color: AppTheme.textPrimary
                        }
                        Rectangle { width: parent.width; height: 1; color: AppTheme.borderSubtle }

                        ListView {
                            width: parent.width
                            height: parent.height - 44
                            clip: true
                            spacing: 4
                            model: onlineUsers

                            delegate: Row {
                                spacing: 8
                                height: 32

                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    RetryImage {
                                        anchors.fill: parent
                                        coverSource: modelData.avatar_url && String(modelData.avatar_url).indexOf("http") === 0
                                                     ? modelData.avatar_url : "qrc:/image/touxi.jpg"
                                        fillMode: Image.PreserveAspectCrop
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

            PillButton {
                label: "邀请"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.copyInvite()
            }

            Rectangle {
                width: 88; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: leaveHover.hovered ? AppTheme.accentGlow : "transparent"
                border.width: 1
                border.color: leaveHover.hovered ? AppTheme.errorColor : AppTheme.borderDefault

                Text {
                    anchors.centerIn: parent
                    text: "离开房间"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    color: leaveHover.hovered ? AppTheme.errorColor : AppTheme.textMuted
                }

                HoverHandler { id: leaveHover }
                TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: leaveConfirmDialog.open() }
                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
            }
        }
    }

    // ==================== 主体三栏 ====================

    Item {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        anchors.topMargin: 4

        // ---------- 左：房间信息 + 成员 ----------
        Rectangle {
            id: membersPane
            visible: !root.compact
            width: 190
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 16
            color: AppTheme.bgCard
            border.width: 1
            border.color: AppTheme.borderSubtle

            Item {
                id: roomInfo
                width: parent.width
                height: 96

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 6

                    Text {
                        text: "房间"
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textDim
                    }
                    Text {
                        text: websocket ? websocket.Roomid : ""
                        font.pixelSize: AppTheme.fontSizeDisplay
                        font.family: AppTheme.fontFamily
                        font.weight: Font.Bold
                        color: AppTheme.textPrimary
                    }
                    Text {
                        text: onlineCount + " 人在线"
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                }
            }

            Rectangle {
                id: roomDivider
                anchors.top: roomInfo.bottom
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: AppTheme.borderSubtle
            }

            Item {
                id: membersHeader
                anchors.top: roomDivider.bottom
                width: parent.width
                height: 42

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "成员"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    font.weight: Font.Bold
                    color: AppTheme.textSecondary
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: onlineUsers.length
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                }
            }

            ListView {
                id: memberList
                anchors.top: membersHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 10
                clip: true
                spacing: 2
                model: onlineUsers
                ScrollBar.vertical: TransientScrollBar {}

                delegate: Rectangle {
                    width: memberList.width
                    height: 40
                    radius: 8
                    color: memberHover.hovered ? AppTheme.bgNavHover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9

                        Rectangle {
                            width: 28; height: 28; radius: 14
                            anchors.verticalCenter: parent.verticalCenter

                            RetryImage {
                                anchors.fill: parent
                                coverSource: modelData.avatar_url && String(modelData.avatar_url).indexOf("http") === 0
                                             ? modelData.avatar_url : "qrc:/image/touxi.jpg"
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: 28; height: 28; radius: 14 }
                                }
                            }
                        }

                        Text {
                            text: modelData.nickname || modelData.userId || "未知用户"
                            width: memberList.width - 70
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: memberHover }
                }

                Text {
                    anchors.centerIn: parent
                    visible: onlineUsers.length === 0
                    text: "还没有其他人"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                }
            }
        }

        // ---------- 右：聊天/动态时间线 ----------
        Rectangle {
            id: chatPane
            width: Math.max(290, Math.min(380, root.width * 0.33))
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 16
            color: AppTheme.bgCard
            border.width: 1
            border.color: AppTheme.borderSubtle
            clip: true

            property bool stickerPanelOpen: false
            property string stickerTab: "all"

            Item {
                id: chatHeader
                width: parent.width
                height: 46

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "聊天"
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.weight: Font.Bold
                    color: AppTheme.textPrimary
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.timelineCount > 0 ? root.timelineCount + " 条" : ""
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                }
            }

            Rectangle {
                id: chatHeaderDivider
                anchors.top: chatHeader.bottom
                width: parent.width
                height: 1
                color: AppTheme.borderSubtle
            }

            ListView {
                id: timelineList
                anchors.top: chatHeaderDivider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputBar.top
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 6
                anchors.bottomMargin: 4
                clip: true
                spacing: 2
                cacheBuffer: 1000
                model: root.timelineMessages

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
                onContentHeightChanged: {
                    if (_autoScroll)
                        Qt.callLater(positionViewAtEnd)
                }

                ScrollBar.vertical: TransientScrollBar {}
                footer: Item { height: 4 }

                delegate: Item {
                    id: timelineDelegate
                    width: timelineList.width

                    readonly property var msg: modelData
                    readonly property bool isAction: String(msg.type) === "action"
                    readonly property bool isMine: !isAction && userManager && msg.userid === userManager.userid
                    readonly property bool isSticker: String(msg.message || "").indexOf("[sticker]") === 0
                    readonly property string stickerId: isSticker ? String(msg.message).substring(9) : ""
                    readonly property bool stickerAnimated: /\.(gif|webp)$/i.test(stickerId)

                    readonly property bool showTime: {
                        var t = Number(msg.time || 0)
                        if (t <= 0)
                            return false
                        if (index <= 0)
                            return true
                        var prev = root.timelineMessages ? root.timelineMessages.get(index - 1) : null
                        if (!prev)
                            return true
                        var pt = Number(prev.time || 0)
                        return pt <= 0 || t - pt >= 300
                    }

                    height: contentColumn.height + 2

                    property bool isNewMsg: false
                    property real slideX: 0
                    property real msgOpacity: 1
                    transform: Translate { x: timelineDelegate.slideX }
                    opacity: timelineDelegate.msgOpacity

                    Component.onCompleted: {
                        var newMsg = !isAction && index >= root.prevTimelineCount && msg.status !== "sent"
                        if (newMsg) {
                            isNewMsg = true
                            slideX = timelineDelegate.isMine ? 60 : -60
                            msgOpacity = 0
                            slideInAnim.start()
                        }
                    }

                    ParallelAnimation {
                        id: slideInAnim
                        NumberAnimation {
                            target: timelineDelegate; property: "slideX"
                            from: timelineDelegate.isMine ? 60 : -60; to: 0
                            duration: 500; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: timelineDelegate; property: "msgOpacity"
                            from: 0; to: 1
                            duration: AppTheme.animSlow; easing.type: Easing.OutCubic
                        }
                    }

                    Column {
                        id: contentColumn
                        width: parent.width

                        // 时间分隔
                        Item {
                            width: parent.width
                            height: timelineDelegate.showTime ? 28 : 0
                            visible: height > 0

                            Rectangle {
                                anchors.centerIn: parent
                                width: timelineTime.implicitWidth + 20
                                height: 20
                                radius: 10
                                color: AppTheme.bgContent
                                border.width: 1
                                border.color: AppTheme.borderSubtle

                                Text {
                                    id: timelineTime
                                    anchors.centerIn: parent
                                    text: root.timeLabel(Number(timelineDelegate.msg.time || 0))
                                    font.pixelSize: AppTheme.fontSizeXs
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textDim
                                }
                            }
                        }

                        // 系统动态：居中胶囊
                        Item {
                            width: parent.width
                            height: timelineDelegate.isAction ? 32 : 0
                            visible: timelineDelegate.isAction

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(actionText.implicitWidth + 24, timelineList.width - 48)
                                height: 26
                                radius: 13
                                color: AppTheme.bgContent
                                border.width: 1
                                border.color: AppTheme.borderDefault

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, timelineList.width - 72)
                                    text: (timelineDelegate.msg.nickname || timelineDelegate.msg.userid || "")
                                          + " " + (timelineDelegate.msg.message || "")
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.family: AppTheme.fontFamily
                                    color: AppTheme.textMuted
                                }
                            }
                        }

                        // 聊天气泡
                        Item {
                            width: parent.width
                            height: timelineDelegate.isAction ? 0 : chatRow.height + 6
                            visible: !timelineDelegate.isAction

                            Row {
                                id: chatRow
                                width: parent.width
                                spacing: 8
                                layoutDirection: timelineDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight

                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    anchors.verticalCenter: parent.verticalCenter

                                    RetryImage {
                                        anchors.fill: parent
                                        coverSource: modelData.avatarUrl && String(modelData.avatarUrl).indexOf("http") === 0
                                                     ? modelData.avatarUrl : "qrc:/image/touxi.jpg"
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle { width: 28; height: 28; radius: 14 }
                                        }
                                    }
                                }

                                Item {
                                    id: bubbleCol
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(nameRow.width, bubbleRow.width)
                                    height: nameRow.height + 2 + bubbleRow.height

                                    Row {
                                        id: nameRow
                                        spacing: 6
                                        layoutDirection: timelineDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight
                                        x: timelineDelegate.isMine ? bubbleCol.width - width : 0

                                        Text {
                                            text: timelineDelegate.msg.nickname || timelineDelegate.msg.userid || "未知"
                                            font.pixelSize: AppTheme.fontSizeSmall
                                            font.family: AppTheme.fontFamily
                                            color: timelineDelegate.isMine ? AppTheme.accent : AppTheme.textDim
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

                                    Row {
                                        id: bubbleRow
                                        spacing: 4
                                        layoutDirection: timelineDelegate.isMine ? Qt.RightToLeft : Qt.LeftToRight
                                        x: timelineDelegate.isMine ? bubbleCol.width - width : 0
                                        y: nameRow.height + 2

                                        Rectangle {
                                            id: chatBubbleRect
                                            visible: !timelineDelegate.isSticker
                                            width: bubbleText.width + 24
                                            height: bubbleText.height + 14
                                            radius: 10
                                            color: timelineDelegate.isMine ? AppTheme.accentDim : AppTheme.bgInput
                                            border.width: 1
                                            border.color: timelineDelegate.isMine ? AppTheme.accentSubtle : AppTheme.borderDefault

                                            Text {
                                                id: bubbleText
                                                anchors.centerIn: parent
                                                text: timelineDelegate.msg.message || ""
                                                font.pixelSize: AppTheme.fontSizeBody
                                                font.family: AppTheme.fontFamily
                                                color: timelineDelegate.isMine ? AppTheme.textPrimary : AppTheme.textSecondary
                                                wrapMode: Text.Wrap
                                                width: Math.min(implicitWidth, timelineList.width - 100)
                                            }
                                        }

                                        // 表情消息
                                        Item {
                                            id: stickerBox
                                            visible: timelineDelegate.isSticker
                                            width: 120
                                            height: 120

                                            readonly property string src: {
                                                var r = stickers ? stickers.revision : 0
                                                return stickers ? stickers.pathFor(timelineDelegate.stickerId) : ""
                                            }

                                            AnimatedImage {
                                                anchors.fill: parent
                                                visible: timelineDelegate.stickerAnimated && stickerBox.src !== ""
                                                source: stickerBox.src
                                                fillMode: Image.PreserveAspectFit
                                                playing: visible
                                            }
                                            Image {
                                                anchors.fill: parent
                                                visible: !timelineDelegate.stickerAnimated && stickerBox.src !== ""
                                                source: stickerBox.src
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: stickerBox.src === ""
                                                radius: 10
                                                color: AppTheme.bgInput
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "加载中"
                                                    font.pixelSize: AppTheme.fontSizeXs
                                                    font.family: AppTheme.fontFamily
                                                    color: AppTheme.textDim
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    stickerMenu.stickerId = timelineDelegate.stickerId
                                                    stickerMenu.popup()
                                                }
                                            }
                                        }

                                        // 发送状态
                                        Item {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            property bool isConfirmed: root.confirmedMsgIds[timelineDelegate.msg._msgId] === true
                                            visible: (timelineDelegate.msg.status === "sending" && !isConfirmed)
                                                     || timelineDelegate.msg.status === "failed"

                                            Canvas {
                                                id: sendingSpinner
                                                anchors.fill: parent
                                                visible: timelineDelegate.msg.status === "sending" && !parent.isConfirmed
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
                                                    running: sendingSpinner.visible && !BasicConfig.uiIdle
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                visible: timelineDelegate.msg.status === "failed"
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
                                                        if (timelineDelegate.msg._msgId)
                                                            websocket.retryMessage(timelineDelegate.msg._msgId)
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
            }

            // 聊天空状态
            Column {
                anchors.centerIn: timelineList
                visible: root.timelineCount === 0
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
                    color: AppTheme.textDim
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 点击列表收起表情
            MouseArea {
                id: stickerPanelCloser
                anchors.top: chatHeaderDivider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputBar.top
                z: 19
                visible: chatPane.stickerPanelOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: chatPane.stickerPanelOpen = false
            }

            // 输入栏
            Rectangle {
                id: inputBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 58
                color: "transparent"
                z: 35

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    spacing: 8

                    TextField {
                        id: chatInput
                        width: parent.width - emojiBtn.width - sendBtn.width - parent.spacing * 2
                        height: 36
                        placeholderText: "说点什么..."
                        color: AppTheme.textPrimary
                        palette.placeholderText: AppTheme.textPlaceholder
                        font.pixelSize: AppTheme.fontSizeBody
                        font.family: AppTheme.fontFamily
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 14
                        background: Rectangle {
                            radius: 18
                            color: AppTheme.bgInput
                            border.color: chatInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderDefault
                            border.width: 1
                        }
                        onAccepted: root.sendChatText()
                    }

                    IconButton {
                        id: emojiBtn
                        diameter: 34
                        iconSource: AppIcon.smile
                        iconColor: chatPane.stickerPanelOpen ? AppTheme.accent : AppTheme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: chatPane.stickerPanelOpen = !chatPane.stickerPanelOpen
                    }

                    PillButton {
                        id: sendBtn
                        label: "发送"
                        primary: true
                        implicitHeight: 36
                        radius: 18
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.sendChatText()
                    }
                }
            }

            // 表情面板
            Rectangle {
                id: stickerPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputBar.top
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.bottomMargin: 6
                height: chatPane.stickerPanelOpen ? 264 : 0
                radius: 12
                z: 30
                visible: height > 1
                opacity: chatPane.stickerPanelOpen ? 1 : 0
                clip: true
                color: AppTheme.bgOverlay
                border.width: 1
                border.color: AppTheme.dialogBorder

                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 140 } }

                Item {
                    id: stickerTabs
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 18

                        Item {
                            width: allTabText.implicitWidth
                            height: 30
                            Text {
                                id: allTabText
                                anchors.centerIn: parent
                                text: "全部"
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                font.weight: chatPane.stickerTab === "all" ? Font.Bold : Font.Normal
                                color: chatPane.stickerTab === "all" ? AppTheme.accent : AppTheme.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chatPane.stickerTab = "all"
                            }
                        }

                        Item {
                            width: recentTabText.implicitWidth
                            height: 30
                            Text {
                                id: recentTabText
                                anchors.centerIn: parent
                                text: "最近"
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                font.weight: chatPane.stickerTab === "recent" ? Font.Bold : Font.Normal
                                color: chatPane.stickerTab === "recent" ? AppTheme.accent : AppTheme.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chatPane.stickerTab = "recent"
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: AppTheme.borderSubtle
                    }
                }

                GridView {
                    id: stickerGrid
                    anchors.top: stickerTabs.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    cellWidth: 62
                    cellHeight: 62
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.stickerItems()

                    delegate: Item {
                        id: stickerCell
                        required property int index
                        required property var modelData
                        width: stickerGrid.cellWidth
                        height: stickerGrid.cellHeight

                        readonly property bool isAdd: String(modelData) === ""
                        readonly property string src: {
                            if (isAdd)
                                return ""
                            var r = stickers ? stickers.revision : 0
                            return stickers ? stickers.pathFor(String(modelData)) : ""
                        }
                        readonly property bool animated: /\.(gif|webp)$/i.test(String(modelData))

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 10
                            visible: stickerCell.isAdd
                            color: cellMa.containsMouse ? AppTheme.bgInput : "transparent"
                            border.width: 1
                            border.color: AppTheme.borderSubtle

                            Image {
                                anchors.centerIn: parent
                                source: AppIcon.plus
                                width: 22; height: 22
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(64, 64)
                                layer.enabled: true
                                layer.effect: ColorOverlay { color: AppTheme.textSecondary }
                            }
                        }

                        AnimatedImage {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: !stickerCell.isAdd && stickerCell.animated && stickerCell.src !== ""
                            source: stickerCell.src
                            fillMode: Image.PreserveAspectFit
                            playing: visible
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: !stickerCell.isAdd && !stickerCell.animated && stickerCell.src !== ""
                            source: stickerCell.src
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (stickerCell.isAdd) {
                                    stickerFileDialog.open()
                                    return
                                }
                                var id = String(modelData)
                                if (mouse.button === Qt.RightButton) {
                                    stickerMenu.stickerId = id
                                    stickerMenu.popup()
                                    return
                                }
                                root.sendSticker(id)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: stickerGrid
                    visible: chatPane.stickerTab === "recent" && stickers && stickers.recent.length === 0
                    text: "还没有最近使用的表情"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    color: AppTheme.textDim
                }
            }
        }

        // ---------- 中：正在播放 + 队列 ----------
        Item {
            id: mainPane
            anchors.left: membersPane.visible ? membersPane.right : parent.left
            anchors.leftMargin: membersPane.visible ? 12 : 0
            anchors.right: chatPane.left
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Rectangle {
                id: nowCard
                width: parent.width
                height: 148
                radius: 16
                color: AppTheme.bgCard
                border.width: 1
                border.color: AppTheme.borderSubtle

                // 有歌
                Row {
                    visible: !!root.roomSongData.songname
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    spacing: 12

                    Rectangle {
                        id: nowCover
                        width: 76; height: 76
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter

                        RetryImage {
                            anchors.fill: parent
                            coverSource: root.roomSongData.cover_url || ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle { width: 76; height: 76; radius: 11 }
                            }
                        }
                    }

                    Column {
                        width: parent.width - 76 - 12 - rightButtons.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.roomSongData.songname || ""
                            font.pixelSize: AppTheme.fontSizeTitleLg
                            font.family: AppTheme.fontFamily
                            font.weight: Font.Bold
                            color: AppTheme.textSongTitle
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.roomSongData.singername || ""
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                        }
                    }

                    Column {
                        id: rightButtons
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Row {
                            spacing: 2
                            anchors.horizontalCenter: parent.horizontalCenter

                            IconButton {
                                diameter: 28
                                iconSource: root.currentLiked ? AppIcon.heartFill : AppIcon.heart
                                iconColor: root.currentLiked ? AppTheme.accent : AppTheme.textMuted
                                tooltip: root.currentLiked ? "取消点赞" : "点赞"
                                onClicked: websocket.likeTogetherSong(root.roomSongData.songhash)
                            }

                            Text {
                                visible: root.currentLikeCount > 0
                                text: root.currentLikeCount
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: root.currentLiked ? AppTheme.accent : AppTheme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        PillButton {
                            label: "点歌"
                            primary: true
                            onClicked: requestDialog.open()
                        }
                    }
                }

                Row {
                    id: nowStatusRow
                    anchors.left: parent.left
                    anchors.leftMargin: 102
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 7

                    NowPlayingIndicator {
                        id: nowPlayingIndicator
                        visible: root.roomSongData.is_playing !== 0
                        playing: root.roomSongData.is_playing !== 0
                    }

                    Text {
                        width: parent.width - (nowPlayingIndicator.visible ? nowPlayingIndicator.width + 7 : 0)
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: root.nowPlayingStatus
                        font.pixelSize: AppTheme.fontSizeXs
                        font.family: AppTheme.fontFamily
                        color: root.roomSongData.is_playing === 0 ? AppTheme.textDim : AppTheme.accent
                    }
                }

                // 无歌
                Column {
                    visible: !root.roomSongData.songname
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "还没有正在播放的歌曲"
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "从下方点歌，或等房间里的其他人先点一首"
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textDim
                    }
                }
            }

            Item {
                id: queueHeader
                anchors.top: nowCard.bottom
                anchors.topMargin: 14
                width: parent.width
                height: 34

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "播放队列"
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.family: AppTheme.fontFamily
                        font.weight: Font.Bold
                        color: AppTheme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: queueCountText.implicitWidth + 16
                        height: 20
                        radius: 10
                        color: AppTheme.bgInput
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: queueCountText
                            anchors.centerIn: parent
                            text: (playlistmanager ? playlistmanager.togetherplaylist.count : 0) + " 首"
                            font.pixelSize: AppTheme.fontSizeXs
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textMuted
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton {
                        iconSource: AppIcon.next
                        tooltip: "下一首"
                        onClicked: websocket.playNextTogether()
                    }
                    IconButton {
                        iconSource: AppIcon.refresh
                        tooltip: "刷新队列"
                        onClicked: websocket.requestPlaylist()
                    }
                    Item { width: 6; height: 1 }
                    PillButton {
                        label: "点歌"
                        primary: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: requestDialog.open()
                    }
                }
            }

            ListView {
                id: queueList
                anchors.top: queueHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                clip: true
                spacing: 2
                cacheBuffer: 1200
                model: playlistmanager ? playlistmanager.togetherplaylist : null
                ScrollBar.vertical: TransientScrollBar {}

                delegate: Rectangle {
                    id: queueRow
                    width: queueList.width
                    height: 54
                    radius: 8
                    color: queueHover.hovered ? AppTheme.bgNavHover : "transparent"

                    readonly property bool isCurrent: root.roomSongData.songhash === model.songhash
                    readonly property bool narrow: queueList.width < 420
                    readonly property bool liked: {
                        if (!userManager) return false
                        var arr = model.liked_by
                        if (!arr) return false
                        for (var i = 0; i < arr.length; ++i)
                            if (arr[i] === userManager.userid) return true
                        return false
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Item {
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                visible: !queueRow.isCurrent
                                text: (index + 1 < 10 ? "0" : "") + (index + 1)
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textDim
                            }
                            NowPlayingIndicator {
                                anchors.centerIn: parent
                                visible: queueRow.isCurrent
                                playing: root.roomSongData.is_playing !== 0
                            }
                        }

                        Item {
                            width: 38; height: 38
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: queueCover
                                width: 38; height: 38; radius: 8
                                color: AppTheme.bgCard

                                RetryImage {
                                    anchors.fill: parent
                                    coverSource: model.union_cover || ""
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle { width: 38; height: 38; radius: 8 }
                                    }
                                }
                            }

                            RetryImage {
                                visible: String(model.added_by_avatar || "").length > 0
                                width: 14; height: 14
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -3
                                anchors.bottomMargin: -3
                                coverSource: model.added_by_avatar || ""
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: 14; height: 14; radius: 7 }
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

                        Column {
                            width: parent.width - 22 - 38 - queueLikeRow.width - queueActions.width
                                   - (queueDuration.visible ? queueDuration.width + 10 : 0) - 40
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: model.title
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                font.weight: Font.DemiBold
                                color: queueRow.isCurrent ? AppTheme.accentPlaying
                                                          : (queueHover.hovered ? AppTheme.accentPlaying : AppTheme.textSongTitle)
                            }

                            Text {
                                width: parent.width
                                text: {
                                    var by = model.added_by_nickname || ""
                                    var src = model.recommend_source || ""
                                    if (src.length > 0) {
                                        if (by.length === 0 || by === "系统推荐" || by === "系统")
                                            return (model.singername || "") + "  ·  系统 · " + src
                                        return (model.singername || "") + "  ·  " + by + " 推荐"
                                    }
                                    return (model.singername || "") + (by ? "  ·  " + by + " 点歌" : "")
                                }
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                            }
                        }

                        Row {
                            id: queueLikeRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            IconButton {
                                diameter: 22
                                iconSource: queueRow.liked ? AppIcon.heartFill : AppIcon.heart
                                iconColor: queueRow.liked ? AppTheme.accent : AppTheme.textDim
                                tooltip: queueRow.liked ? "取消点赞" : "点赞"
                                onClicked: websocket.likeTogetherSong(model.songhash)
                            }

                            Text {
                                visible: (model.like_count || 0) > 0
                                text: model.like_count
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: queueRow.liked ? AppTheme.accent : AppTheme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            id: queueActions
                            opacity: queueHover.hovered ? 1 : 0
                            enabled: queueHover.hovered
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            IconButton {
                                visible: !queueRow.isCurrent
                                diameter: 22
                                iconSource: AppIcon.playCircle
                                tooltip: "播放"
                                onClicked: websocket.playTogetherByHash(model.songhash)
                            }
                            IconButton {
                                visible: !queueRow.isCurrent
                                diameter: 22
                                iconSource: AppIcon.caretUp
                                tooltip: "置顶"
                                onClicked: websocket.upSongByHash(model.songhash)
                            }
                            IconButton {
                                visible: !queueRow.isCurrent
                                diameter: 22
                                iconSource: AppIcon.deleteIcon
                                tooltip: "从队列移除"
                                onClicked: websocket.removeSongFromTogether(model.songhash)
                            }
                        }

                        Text {
                            id: queueDuration
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !queueRow.narrow
                            text: model.duration || "--:--"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textDim
                        }
                    }

                    HoverHandler { id: queueHover }
                }

                Column {
                    anchors.centerIn: parent
                    visible: !playlistmanager || playlistmanager.togetherplaylist.count === 0
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "队列还是空的"
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textMuted
                    }
                    PillButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: "点一首歌"
                        primary: true
                        onClicked: requestDialog.open()
                    }
                }
            }
        }
    }

    // ==================== 点歌弹窗 ====================

    Dialog {
        id: requestDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(620, root.width - 80)
        height: Math.min(560, root.height - 80)
        contentWidth: width
        contentHeight: height
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        onAboutToShow: {
            BasicConfig.pushModalInputLock(requestDialog)
            requestInput.forceActiveFocus()
        }
        onClosed: BasicConfig.popModalInputLock(requestDialog)
        Component.onDestruction: BasicConfig.popModalInputLock(requestDialog)

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

        contentItem: Item {
            Item {
                id: dialogHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                height: 32

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "点歌"
                    font.pixelSize: AppTheme.fontSizeTitleLg
                    font.family: AppTheme.fontFamily
                    font.weight: Font.Bold
                    color: AppTheme.textPrimary
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: AppIcon.close
                    tooltip: "关闭"
                    onClicked: requestDialog.close()
                }
            }

            Row {
                id: searchRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: dialogHeader.bottom
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 10
                spacing: 8

                TextField {
                    id: requestInput
                    width: parent.width - searchButton.width - parent.spacing
                    height: 38
                    placeholderText: "搜索歌曲、歌手"
                    color: AppTheme.textPrimary
                    palette.placeholderText: AppTheme.textPlaceholder
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 14
                    background: Rectangle {
                        radius: 10
                        color: AppTheme.bgInput
                        border.color: requestInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderDefault
                        border.width: 1
                    }
                    onAccepted: root.searchSongs()
                }

                PillButton {
                    id: searchButton
                    label: "搜索"
                    primary: true
                    implicitHeight: 38
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.searchSongs()
                }
            }

            ListView {
                id: requestResults
                anchors.top: searchRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 18
                anchors.topMargin: 12
                clip: true
                spacing: 2
                model: togetherSearch
                ScrollBar.vertical: TransientScrollBar {}

                delegate: Rectangle {
                    width: requestResults.width
                    height: 58
                    radius: 8
                    color: requestHover.hovered ? AppTheme.bgNavHover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 40; height: 40; radius: 8
                            anchors.verticalCenter: parent.verticalCenter

                            RetryImage {
                                anchors.fill: parent
                                coverSource: model.union_cover || ""
                                fillMode: Image.PreserveAspectCrop
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: 40; height: 40; radius: 8 }
                                }
                            }
                        }

                        Column {
                            width: parent.width - 40 - 10 - resultDuration.width - 10 - addBtn.width - 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: model.songname || ""
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                font.weight: Font.DemiBold
                                color: AppTheme.textPrimary
                            }
                            Text {
                                width: parent.width
                                text: (model.singername || "") + (model.album_name ? "  ·  " + model.album_name : "")
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                            }
                        }

                        Text {
                            id: resultDuration
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.duration || "--:--"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                            color: AppTheme.textDim
                        }

                        PillButton {
                            id: addBtn
                            label: "添加"
                            primary: true
                            implicitHeight: 26
                            radius: 13
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (websocket) {
                                    websocket.addSongToTogether(
                                        model.songname, model.songhash, model.singername,
                                        model.album_name, model.duration, model.union_cover
                                    )
                                }
                            }
                        }
                    }

                    HoverHandler { id: requestHover }
                }
            }

            Text {
                anchors.centerIn: requestResults
                visible: !togetherSearch || (!togetherSearch.isLoading && togetherSearch.count === 0)
                text: root.requestKeyword === "" ? "输入关键词搜索歌曲" : "没有找到相关歌曲"
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
                color: AppTheme.textDim
            }

            Text {
                anchors.centerIn: requestResults
                visible: togetherSearch && togetherSearch.isLoading
                text: "搜索中..."
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
                color: AppTheme.textMuted
            }
        }
    }

    // ==================== 表情菜单 / 文件选择 ====================

    Menu {
        id: stickerMenu
        property string stickerId: ""
        width: 180
        padding: 6

        StickerMenuItem {
            text: "添加到表情包"
            iconSource: AppIcon.plus
            onTriggered: stickers.addSticker(stickerMenu.stickerId)
        }
        StickerMenuItem {
            text: "从表情包删除"
            iconSource: AppIcon.deleteIcon
            danger: true
            onTriggered: stickers.removeSticker(stickerMenu.stickerId)
        }

        background: Rectangle {
            radius: 10
            color: AppTheme.bgOverlay
            border.color: AppTheme.dialogBorder
            border.width: 1
        }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
        }
    }

    FileDialog {
        id: stickerFileDialog
        title: "添加表情"
        nameFilters: ["图片 (*.gif *.webp *.png *.jpg *.jpeg)"]
        onAccepted: {
            var path = String(selectedFile)
            if (path.indexOf("file:///") === 0)
                path = path.substring(8)
            else if (path.indexOf("file://") === 0)
                path = path.substring(7)
            else if (path.indexOf("file:") === 0)
                path = path.substring(5)
            try { path = decodeURIComponent(path) } catch (e) {}
            stickers.addFile(path)
        }
    }

    Connections {
        target: stickers

        function onNotice(message) {
            BasicConfig.noticeSuccess(message)
        }
        function onErrorOccurred(message) {
            BasicConfig.noticeError(message)
        }
        function onFileAdded(id, send) {
            if (!send || !websocket)
                return
            websocket.sendChatMessage("[sticker]" + id)
            stickers.markRecent(id)
            timelineList._autoScroll = true
            Qt.callLater(timelineList.positionViewAtEnd)
        }
    }

    // 拖放：上传由窗口层 C++ 过滤器处理，这里只接受并提示
    DropArea {
        id: stickerDrop
        anchors.fill: parent
        z: 300
        onEntered: (drag) => drag.acceptProposedAction()
        onDropped: (drop) => drop.acceptProposedAction()
    }

    Rectangle {
        id: stickerDropOverlay
        anchors.fill: parent
        z: 299
        enabled: false
        visible: stickerDrop.containsDrag
        color: "#66000000"
        border.width: 2
        border.color: AppTheme.accent

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "松开添加并发送表情"
                color: "white"
                font.pixelSize: AppTheme.fontSizeTitle
                font.bold: true
                font.family: AppTheme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "支持 GIF / WebP / PNG / JPG，不超过 2MB"
                color: "#D9FFFFFF"
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }
    }

    // ==================== 信号连接 ====================

    Connections {
        target: websocket

        function onMessageConfirmed(msgId) {
            var copy = Object.assign({}, confirmedMsgIds)
            copy[msgId] = true
            confirmedMsgIds = copy
        }

        function onSongInfoUpdated(data) {
            root.roomSongData = data
        }

        function onConnectionStateChanged(state) {
            if (state === 0) {
                connectionBanner.height = 36
                bannerText.text = "连接已断开，正在退出房间..."
                root.firstLoad = true
                root.prevTimelineCount = 0
                root.confirmedMsgIds = ({})
                root.roomSongData = ({})
            } else if (state === 2) {
                connectionBanner.height = 0
                root.firstLoad = true
                root.prevTimelineCount = 0
                root.confirmedMsgIds = ({})
            }
        }

        function onConnectFail() {
            connectionBanner.height = 36
            bannerText.text = "连接失败，请检查网络后重新加入房间"
        }

        function onClientListUpdated(json) {
            if (json["client_list"] !== undefined) {
                var arr = json["client_list"]
                var users = []
                for (var i = 0; i < arr.length; i++)
                    users.push(arr[i])
                onlineUsers = users
                onlineCount = users.length
            }
        }

        function onRoomActionsReceived(actions) {
            if (timelineList._autoScroll)
                Qt.callLater(timelineList.positionViewAtEnd)
        }

        function onChatMessageReceived(userid, nickname, avatarUrl, message, timestamp) {
            timelineList._autoScroll = true
            Qt.callLater(timelineList.positionViewAtEnd)

            if (BasicConfig.windowObscured && trayHandler) {
                trayHandler.showMessage(
                    "网狗音乐 - " + (nickname || "未知用户"),
                    message,
                    3000
                )
            }
        }

        function onServerNotice(message, mode) {
            if (!message)
                return
            if (mode === "error")
                BasicConfig.noticeError(message)
            else if (mode === "success")
                BasicConfig.noticeSuccess(message)
        }
    }

    // 切回本页时，若之前在底部则贴到最新
    onVisibleChanged: {
        if (!visible)
            return
        if (timelineList._autoScroll)
            Qt.callLater(timelineList.positionViewAtEnd)
    }

    Component.onCompleted: {
        if (websocket && websocket.connected)
            websocket.requestClientList()
        timelineList._autoScroll = true
        Qt.callLater(timelineList.positionViewAtEnd)
        if (stickers && userManager && userManager.isLoggedIn)
            stickers.refresh()
    }
}
