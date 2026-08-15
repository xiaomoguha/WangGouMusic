import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

//上层状态栏
Item {
    id: rightTop
    property bool canGoBack: false
    signal goBack()

    // ===== 服务器共享 token 看门狗状态（设置图标左侧小圆点）=====
    // 每 30 秒拉一次 /admin/token/status——服务器只回看门狗落盘的缓存结果，
    // 不会触发真实检测（服务器自身按 30 分钟 / 16:30-16:45 每 30 秒的节奏检测）
    property var guardData: null      // 最近一次返回的 data {guard, shared, server_time}
    property string guardError: ""    // 拉取失败原因（网络 / 密钥未配置）

    readonly property string guardState: {
        if (guardError !== "") return "error"
        if (!guardData || !guardData.guard) return "unknown"
        return guardData.guard.state || "unknown"
    }

    function guardFmtTime(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "hh:mm:ss")
    }

    readonly property string guardTooltip: {
        var g = guardData && guardData.guard ? guardData.guard : null
        switch (guardState) {
        case "ok":
            var t = "服务器 Token 存活 ✓\n检测于 " + (guardFmtTime(g.checked_at) || "-") + "，每30秒自动刷新"
            if (g && g.relogin && g.relogin.result === "success")
                t += "\n上次自动重登 " + (guardFmtTime(g.relogin.at) || "-")
            return t
        case "invalid":
            var d2 = "服务器 Token 已失效（" + (g && g.error_code ? g.error_code : "?") + "）\n"
            if (g && g.relogin && g.relogin.result === "captcha")
                d2 += "自动重登需人工滑块验证：\napi.special520.com/login_captcha.html"
            else if (g && g.detail)
                d2 += g.detail
            else
                d2 += "看门狗正在自动重登，稍后恢复"
            return d2
        case "net-error":
            return "服务器验活请求异常（网络波动）\n稍后自动恢复"
        case "error":
            return guardError
        default:
            return "看门狗状态未知（服务器刚启动？）"
        }
    }

    Timer {
        id: guardPollTimer
        interval: 30000
        repeat: true
        running: rightTop.visible && serverAdmin && serverAdmin.adminKey !== ""
        triggeredOnStart: true
        onTriggered: if (serverAdmin) serverAdmin.fetchGuardStatus()
    }

    Connections {
        target: serverAdmin
        function onGuardStatusReceived(data) { rightTop.guardData = data; rightTop.guardError = "" }
        function onRequestFailed(operation, error) {
            // guard 轮询失败只反映到状态点，不弹任何提示
            if (operation === "guard") rightTop.guardError = error
        }
    }

    // 后退按钮
    Rectangle {
        width: 28
        height: 28
        radius: 14
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: backMA.containsMouse ? (BasicConfig.playlistCoverColor !== "" ? "#1EFFFFFF" : AppTheme.bgCard) : "transparent"
        visible: canGoBack
        opacity: canGoBack ? 1 : 0

        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }

        Image {
            id: backIcon
            anchors.centerIn: parent
            source: AppIcon.back
            sourceSize: Qt.size(128, 128)
            mipmap: true
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
            layer.enabled: true
            layer.effect: ColorOverlay {
                source: backIcon
                // 渐变时随背景挑白/深色，与搜索框文字一致
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.textPrimary
            }
        }

        MouseArea {
            id: backMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: goBack()
        }
    }

    //搜索、后退、语音按钮
    Search {
        anchors.left: parent.left
        anchors.leftMargin: canGoBack ? 48 : 0.03 * root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        Behavior on anchors.leftMargin { NumberAnimation { duration: AppTheme.animFast } }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 0.02 * root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        // 服务器 token 看门狗状态点（设置图标左侧；颜色随缓存状态变化，失效时呼吸闪烁）
        Item {
            width: 18
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 9; height: 9; radius: 4.5
                color: rightTop.guardState === "ok" ? AppTheme.successColor
                     : rightTop.guardState === "invalid" ? AppTheme.errorColor
                     : rightTop.guardState === "net-error" ? "#FFA726"
                     : AppTheme.textDim
            }
            // 失效时呼吸提醒（存活/未知状态静止）
            SequentialAnimation on opacity {
                running: rightTop.guardState === "invalid"
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.25; to: 1; duration: 600; easing.type: Easing.InOutQuad }
            }
            HoverHandler { id: guardHover }
            ToolTip {
                visible: guardHover.hovered
                delay: 300
                text: rightTop.guardTooltip
            }
        }

        // 网络代理设置（检查更新左侧，齿轮图标）
        IconButton {
            id: networkSettingsBtn
            anchors.verticalCenter: parent.verticalCenter
            iconSource: AppIcon.settings
            size: 32
            iconSize: 17
            iconColor: BasicConfig.playlistCoverColor !== ""
                ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                : (netSetHover.hovered ? AppTheme.textPrimary : AppTheme.textMuted)
            HoverHandler { id: netSetHover }
            ToolTip {
                visible: netSetHover.hovered
                delay: 400
                text: "网络设置（代理）"
            }
            onClicked: BasicConfig.pushPage("qrc:/Src/ComponentPage/SettingsPage.qml")
        }

        // 检查更新（头像左侧，向上箭头；hover 显示版本号）
        IconButton {
            id: updateIconBtn
            anchors.verticalCenter: parent.verticalCenter
            iconSource: AppIcon.arrowUp
            size: 32
            iconSize: 17
            // 渐变激活时随背景挑白/深色（同搜索框文字），否则 hover 提亮
            iconColor: BasicConfig.playlistCoverColor !== ""
                ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                : (updateIconHover.hovered ? AppTheme.textPrimary : AppTheme.textMuted)

            ToolTip {
                visible: updateIconHover.hovered
                delay: 400
                text: appUpdater ? "检查更新 v" + appUpdater.currentVersion : "检查更新"
            }

            HoverHandler { id: updateIconHover }

            onClicked: {
                if (appUpdater) {
                    root.autoCheckUpdate = false;
                    appUpdater.checkForUpdate();
                }
            }
        }

        //登录信息
        LoginStatus {
            spacing: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        //最大化最小化
        MaxMin {
            visible: Qt.platform.os !== "osx"   // mac 用原生 traffic lights
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
