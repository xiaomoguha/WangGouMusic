import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Row {
    id: loginStatus
    spacing: 10

    property var userDetailData: null

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
            source: "qrc:/image/user_line.png"
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: userAvatar
                color: AppTheme.iconDefault
            }
        }

        Image {
            id: userRealAvatar
            anchors.centerIn: parent
            width: 26
            height: 26
            visible: userManager && userManager.isLoggedIn && userManager.avatarUrl !== ""
            source: userManager && userManager.avatarUrl !== "" ? userManager.avatarUrl : ""
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
            ColorAnimation { duration: 150 }
        }
    }

    Text {
        text: userManager ? userManager.nickname : "未登录"
        color: userManager && userManager.isLoggedIn ? AppTheme.textPrimary : AppTheme.textSecondary
        height: 28
        verticalAlignment: Text.AlignVCenter
        font {
            family: "黑体"
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
    }

    // 用户菜单（已登录时）
    Popup {
        id: userMenu
        y: parent.height + 6
        x: -100
        width: 260
        height: menuContent.implicitHeight + 24
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onAboutToShow: {
            if (userManager && userManager.isLoggedIn) {
                // 先加载缓存
                var cached = userManager.loadCachedUserDetail()
                var d = cached["data"] || cached
                if (d && Object.keys(d).length > 0) userDetailData = d
                // 后台刷新
                userManager.fetchUserDetail()
            }
        }

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
                            font.family: "黑体"
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
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "黑体"
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
                        font.pixelSize: 11
                        font.family: "黑体"
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
                font.pixelSize: 12
                font.family: "黑体"
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
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "黑体"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: modelData.label
                                color: AppTheme.textMuted
                                font.pixelSize: 11
                                font.family: "黑体"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
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
                        source: "qrc:/image/geci.png"
                        width: 12; height: 12
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.effect: ColorOverlay { source: birthIcon; color: AppTheme.textMuted }
                    }
                    Text {
                        text: userDetailData ? String(userDetailData.birthday || "") : ""
                        color: AppTheme.textMuted
                        font.pixelSize: 11
                        font.family: "黑体"
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
                        source: "qrc:/image/user_line.png"
                        width: 12; height: 12
                        fillMode: Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                        layer.enabled: true
                        layer.effect: ColorOverlay { source: occIcon; color: AppTheme.textMuted }
                    }
                    Text {
                        text: userDetailData ? String(userDetailData.occupation || "") : ""
                        color: AppTheme.textMuted
                        font.pixelSize: 11
                        font.family: "黑体"
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
                    font.pixelSize: 13
                    font.family: "黑体"
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

    // 消息按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: mailMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: mailbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/mail_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: mailbuttom
                color: AppTheme.iconDefault
            }
        }

        MouseArea {
            id: mailMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // 设置按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: settingMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"

        Image {
            id: settingbuttom
            anchors.centerIn: parent
            width: 14
            height: 14
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/setting_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: settingbuttom
                color: AppTheme.iconDefault
            }
        }

        MouseArea {
            id: settingMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Behavior on color {
            ColorAnimation { duration: 150 }
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
            source: AppTheme.isDark ? "qrc:/image/moon_line.png" : "qrc:/image/sun_line.png"
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: moonbuttom
                color: AppTheme.iconDefault
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
            ColorAnimation { duration: 150 }
        }
    }
}
