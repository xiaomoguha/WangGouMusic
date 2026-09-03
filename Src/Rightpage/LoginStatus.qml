import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Row {
    id: loginStatus
    spacing: 10

    property var userDetailData: null
    property var gradeData: null

    // 积分进度：当前积分相对本级基点的比例（满级/异常数据返回 1 或 0）
    function gradeProgress() {
        if (!gradeData) return 0
        var cur = Number(gradeData.p_current_point || 0)
        var base = Number(gradeData.p_grade_point || 0)
        var next = Number(gradeData.p_next_grade_point || 0)
        if (next <= base) return 1  // 已满级
        return Math.max(0, Math.min(1, (cur - base) / (next - base)))
    }

    // 头像 + 用户名
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: userMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: userAvatar
            anchors.centerIn: parent
            width: 20
            height: 20
            visible: !(userManager && userManager.isLoggedIn && userManager.avatarUrl !== "")
            source: AppIcon.user
            sourceSize: Qt.size(128, 128)
            mipmap: true
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: userAvatar
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.iconDefault
            }
        }

        RetryImage {
            id: userRealAvatar
            anchors.centerIn: parent
            width: 26
            height: 26
            visible: userManager && userManager.isLoggedIn && userManager.avatarUrl !== ""
            coverSource: userManager && userManager.avatarUrl !== "" ? userManager.avatarUrl : ""
            fillMode: Image.PreserveAspectCrop
            layer.enabled: true
            layer.effect: OpacityMask {
                source: userRealAvatar
                maskSource: Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: "white"
                    visible: false
                }
            }
        }

        MouseArea {
            id: userMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (userManager && userManager.isLoggedIn) {
                    userMenu.visible ? userMenu.close() : userMenu.open()
                } else {
                    loginPopup.open()
                }
            }
        }

        Behavior on color {
            ColorAnimation { duration: AppTheme.animFast }
        }
    }

    Text {
        text: userManager ? userManager.nickname : "未登录"
        color: BasicConfig.playlistCoverColor !== ""
            ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
            : (userManager && userManager.isLoggedIn ? AppTheme.textPrimary : AppTheme.textSecondary)
        height: 28
        verticalAlignment: Text.AlignVCenter
        font {
            family: AppTheme.fontFamily
            pixelSize: 13
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (userManager && !userManager.isLoggedIn) {
                    loginPopup.open()
                }
            }
        }
    }

    Connections {
        target: userManager
        function onUserDetailReceived(data) {
            var d = data["data"] || data
            userDetailData = d
        }
        function onGradeInfoReceived(data) {
            gradeData = data
        }
    }

    // 用户菜单（已登录时）：modal + modalInputLock，点击不穿透
    Popup {
        id: userMenu
        y: parent.height + 6
        x: -100
        width: 260
        height: menuContent.implicitHeight + 24
        padding: 12
        modal: true
        closePolicy: Popup.CloseOnEscape
        // 透明遮罩：点菜单外 = 关菜单（替代 CloseOnPressOutside）
        Overlay.modal: Rectangle {
            color: "transparent"
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: userMenu.close() }
        }

        // 兜底吞掉菜单内点击
        MouseArea { anchors.fill: parent; onClicked: {} }

        onAboutToShow: {
            BasicConfig.modalInputLock = true // 锁底层输入，防点击穿透
            if (userManager && userManager.isLoggedIn) {
                // 先加载缓存
                var cached = userManager.loadCachedUserDetail()
                var d = cached["data"] || cached
                if (d && Object.keys(d).length > 0) userDetailData = d
                // 后台刷新
                userManager.fetchUserDetail()
                userManager.fetchGradeInfo()
            }
        }

        onClosed: BasicConfig.modalInputLock = false

        background: Rectangle {
            radius: AppTheme.radiusMedium
            color: AppTheme.bgOverlay
            border.color: AppTheme.dialogBorder
            border.width: 1

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 4
                radius: 12
                samples: 16
                color: "#40000000"
            }
        }

        Column {
            id: menuContent
            anchors.fill: parent
            spacing: 12

            // ── 用户信息区 ──
            Row {
                width: parent.width
                spacing: 12

                // 大头像
                Rectangle {
                    width: 50
                    height: 50
                    radius: 25
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: userManager && userManager.avatarUrl !== "" ? userManager.avatarUrl : "qrc:/image/user_line.png"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }

                Column {
                    width: parent.width - 62
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        spacing: 6

                        Text {
                            text: userManager ? userManager.nickname : ""
                            color: AppTheme.textPrimary
                            font.pixelSize: 15
                            font.bold: true
                            font.family: AppTheme.fontFamily
                        }

                        // VIP 标识
                        Rectangle {
                            visible: userManager && userManager.isVip
                            width: vipText.implicitWidth + 10
                            height: 18
                            radius: 9
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#FFD700" }
                                GradientStop { position: 1.0; color: "#FFA500" }
                            }
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: vipText
                                anchors.centerIn: parent
                                text: "VIP"
                                color: "#333"
                                font.pixelSize: AppTheme.fontSizeXs
                                font.bold: true
                                font.family: AppTheme.fontFamily
                            }
                        }
                    }

                    Text {
                        text: {
                            if (!userDetailData) return "加载中..."
                            var parts = []
                            var province = userDetailData.province || ""
                            var city = userDetailData.city || ""
                            if (province) parts.push(province)
                            if (city && city !== province) parts.push(city)
                            return parts.length > 0 ? parts.join(" · ") : "未知地区"
                        }
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                    }
                }
            }

            // 签名
            Text {
                visible: userDetailData && userDetailData.descri && userDetailData.descri !== ""
                text: userDetailData ? (userDetailData.descri || "") : ""
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: AppTheme.textSecondary
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }

            // ── 社交数据 ──
            Row {
                width: parent.width
                spacing: 0

                Repeater {
                    model: [
                        { label: "关注", value: userDetailData ? (userDetailData.follows || 0) : 0 },
                        { label: "粉丝", value: userDetailData ? (userDetailData.fans || 0) : 0 },
                        { label: "好友", value: userDetailData ? (userDetailData.friends || 0) : 0 }
                    ]

                    delegate: Item {
                        width: parent.width / 3
                        height: 36

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.value
                                color: AppTheme.textPrimary
                                font.pixelSize: AppTheme.fontSizeBodyLg
                                font.bold: true
                                font.family: AppTheme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: modelData.label
                                color: AppTheme.textMuted
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }

            // ── 听歌等级 ──
            Column {
                width: parent.width
                spacing: 5
                visible: gradeData !== null

                Row {
                    spacing: 8

                    Rectangle {
                        width: gradeText.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: AppTheme.accentSubtle
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: gradeText
                            anchors.centerIn: parent
                            text: gradeData ? ("Lv." + gradeData.p_grade) : ""
                            color: AppTheme.accent
                            font.pixelSize: AppTheme.fontSizeXs
                            font.bold: true
                            font.family: AppTheme.fontFamily
                        }
                    }

                    Text {
                        text: gradeData ? ("累计听歌 " + (Number(gradeData.d_sec || 0) / 3600).toFixed(1) + " 小时") : ""
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 升级积分进度条
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: AppTheme.bgInput

                    Rectangle {
                        width: parent.width * gradeProgress()
                        height: parent.height
                        radius: 2
                        color: AppTheme.accent
                    }
                }

                Text {
                    text: {
                        if (!gradeData) return ""
                        var next = Number(gradeData.p_next_grade_point || 0)
                        return next > 0
                            ? (Number(gradeData.p_current_point || 0) + " / " + next + " 积分 · 距 Lv." + gradeData.p_next_grade)
                            : "积分 " + Number(gradeData.p_current_point || 0) + " · 已满级"
                    }
                    color: AppTheme.textMuted
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.family: AppTheme.fontFamily
                }
            }

            // ── 分隔线 ──
            Rectangle {
                width: parent.width
                height: 1
                color: AppTheme.borderSubtle
            }

            // ── 个人信息 ──
            Column {
                width: parent.width
                spacing: 6
                visible: userDetailData !== null

                Row {
                    spacing: 6
                    visible: userDetailData && userDetailData.birthday && userDetailData.birthday !== ""
                    Image {
                        id: birthIcon
                        source: AppIcon.lyrics
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 12; height: 12
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.effect: ColorOverlay { source: birthIcon; color: AppTheme.textMuted }
                    }
                    Text {
                        text: userDetailData ? String(userDetailData.birthday || "") : ""
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 6
                    visible: {
                        if (!userDetailData) return false
                        var occ = userDetailData.occupation || ""
                        return occ !== ""
                    }
                    Image {
                        id: occIcon
                        source: AppIcon.user
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        width: 12; height: 12
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.effect: ColorOverlay { source: occIcon; color: AppTheme.textMuted }
                    }
                    Text {
                        text: userDetailData ? String(userDetailData.occupation || "") : ""
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ── 分隔线 ──
            Rectangle {
                width: parent.width
                height: 1
                color: AppTheme.borderSubtle
            }

            // ── 登录设备 ──
            Rectangle {
                width: parent.width
                height: 32
                radius: 6
                color: menuDeviceHover.hovered ? AppTheme.bgNavHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "登录设备"
                    color: AppTheme.textPrimary
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                }

                HoverHandler { id: menuDeviceHover }

                TapHandler {
                    onTapped: {
                        userMenu.close()
                        devicePopup.open()
                    }
                }
            }

            // ── 退出登录 ──
            Rectangle {
                width: parent.width
                height: 32
                radius: 6
                color: menuLogoutHover.hovered ? AppTheme.bgNavHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "退出登录"
                    color: AppTheme.errorColor
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                }

                HoverHandler { id: menuLogoutHover }

                TapHandler {
                    onTapped: {
                        userMenu.close()
                        if (userManager) userManager.logout()
                    }
                }
            }
        }
    }

    // 登录设备列表窗口：ThemedPopup + modalInputLock，点击不穿透
    ThemedPopup {
        id: devicePopup
        width: 400
        height: 460
        padding: 0

        property var devices: []
        property bool loading: false
        property string errorMsg: ""

        function refresh() {
            if (!userManager || !userManager.isLoggedIn) return
            loading = true
            errorMsg = ""
            userManager.fetchLoginDevices()
        }

        onAboutToShow: {
            BasicConfig.modalInputLock = true // 锁底层输入，防点击穿透
            // 首次打开拉一次；之后沿用缓存，手动点刷新才重新请求
            // （登录时间字段服务端更新有延迟，频繁刷新看不出变化）
            if (!devices || devices.length === 0) refresh()
        }

        onClosed: {
            BasicConfig.modalInputLock = false
            loading = false
        }

        Connections {
            target: userManager
            function onLoginDevicesReceived(devices) {
                devicePopup.devices = devices
                devicePopup.loading = false
            }
            function onLoginDevicesFailed(error) {
                if (!devicePopup.loading) return
                devicePopup.errorMsg = error
                devicePopup.loading = false
            }
        }

        contentItem: Item {
            clip: true

            // 兜底吞掉弹窗内点击
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: deviceCol
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                // ── 标题 + 刷新 + 关闭 ──
                Item {
                    width: parent.width
                    height: 24

                    Text {
                        text: "当前登录设备"
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeTitle
                        font.bold: true
                        font.family: AppTheme.fontFamily
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 刷新
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        anchors.right: deviceCloseBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: deviceRefreshHover.hovered ? AppTheme.iconButtonHover : "transparent"

                        Image {
                            id: deviceRefreshIcon
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            source: AppIcon.refresh
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: deviceRefreshIcon; color: AppTheme.textSecondary }
                        }

                        HoverHandler { id: deviceRefreshHover }
                        TapHandler { onTapped: devicePopup.refresh() }
                    }

                    // 关闭
                    Rectangle {
                        id: deviceCloseBtn
                        width: 24
                        height: 24
                        radius: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: deviceCloseHover.hovered ? AppTheme.iconButtonHover : "transparent"

                        Image {
                            id: deviceCloseIcon
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: AppIcon.close
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay { source: deviceCloseIcon; color: AppTheme.textSecondary }
                        }

                        HoverHandler { id: deviceCloseHover }
                        TapHandler { onTapped: devicePopup.close() }
                    }
                }

                // ── 加载 / 错误状态 ──
                Text {
                    visible: devicePopup.loading
                    text: "加载中..."
                    color: AppTheme.textMuted
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 24
                }

                Text {
                    visible: !devicePopup.loading && devicePopup.errorMsg !== ""
                    text: devicePopup.errorMsg
                    color: AppTheme.errorColor
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 24
                }

                // ── 设备列表 ──
                ListView {
                    id: deviceList
                    visible: !devicePopup.loading && devicePopup.errorMsg === ""
                    width: parent.width
                    height: deviceCol.height - 36
                    clip: true
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    model: devicePopup.devices

                    delegate: Rectangle {
                        width: deviceList.width
                        height: 58
                        radius: AppTheme.radiusSmall
                        color: AppTheme.bgInput

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            Item {
                                width: parent.width
                                height: 20

                                Text {
                                    text: modelData.app || "未知应用"
                                    color: AppTheme.textPrimary
                                    font.pixelSize: AppTheme.fontSizeBody
                                    font.bold: true
                                    font.family: AppTheme.fontFamily
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.loc || "未知位置"
                                    color: AppTheme.textMuted
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    elide: Text.ElideRight
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    // API 登录不传 dev，酷狗回 "-"：原样显示
                                    text: modelData.dev || "-"
                                    color: AppTheme.textSecondary
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.t > 0
                                        ? Qt.formatDateTime(new Date(modelData.t * 1000), "MM-dd hh:mm") + " 登录"
                                        : ""
                                    color: AppTheme.textMuted
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 主题按钮（月亮/太阳切换）
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: moonMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: moonbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: AppTheme.isDark ? AppIcon.moon : AppIcon.sun
            sourceSize: Qt.size(128, 128)
            mipmap: true
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: moonbuttom
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.iconDefault
            }
        }

        MouseArea {
            id: moonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AppTheme.toggleTheme()
        }

        Behavior on color {
            ColorAnimation { duration: AppTheme.animFast }
        }
    }
}
