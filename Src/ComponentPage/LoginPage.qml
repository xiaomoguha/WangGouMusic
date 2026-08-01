import QtQuick 2.15
import QtQuick.Controls 2.15
import "../BasicConfig"

ThemedPopup {
    id: loginPopup

    width: 360
    height: contentColumn.implicitHeight + 56

    property string errorMsg: ""
    property int cooldown: 0

    // 关闭按钮
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: 28
        height: 28
        radius: 14
        color: closeHover.hovered ? AppTheme.iconButtonHover : "transparent"
        z: 1

        Text {
            anchors.centerIn: parent
            text: "×"
            color: AppTheme.textMuted
            font.pixelSize: AppTheme.fontSizeTitleLg
        }

        HoverHandler { id: closeHover }
        TapHandler {
            onTapped: loginPopup.close()
        }

        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16

        Text {
            text: "登录网狗音乐"
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeHeadline
            font.weight: Font.Bold
            font.family: AppTheme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "验证码登录，无需密码"
            color: AppTheme.textMuted
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 手机号
        TextField {
            id: phoneInput
            width: parent.width
            height: 42
            placeholderText: "请输入手机号"
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeBodyLg
            font.family: AppTheme.fontFamily
            leftPadding: 14
            rightPadding: 14
            verticalAlignment: Text.AlignVCenter
            inputMethodHints: Qt.ImhDialableCharactersOnly
            maximumLength: 11
            background: Rectangle {
                radius: AppTheme.radiusMedium
                color: AppTheme.bgInput
                border.color: phoneInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderSubtle
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
            }
            onAccepted: codeInput.forceActiveFocus()
        }

        // 验证码 + 发送按钮
        Row {
            width: parent.width
            spacing: 10

            TextField {
                id: codeInput
                width: parent.width - sendBtn.width - parent.spacing
                height: 42
                placeholderText: "请输入验证码"
                color: AppTheme.textPrimary
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.family: AppTheme.fontFamily
                leftPadding: 14
                rightPadding: 14
                verticalAlignment: Text.AlignVCenter
                inputMethodHints: Qt.ImhDigitsOnly
                maximumLength: 6
                background: Rectangle {
                    radius: AppTheme.radiusMedium
                    color: AppTheme.bgInput
                    border.color: codeInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderSubtle
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                }
                onAccepted: doLogin()
            }

            Rectangle {
                id: sendBtn
                width: 110
                height: 42
                radius: AppTheme.radiusMedium
                color: {
                    if (cooldown > 0) return AppTheme.textMuted
                    return sendHover.hovered ? AppTheme.accentHover : AppTheme.accent
                }

                Text {
                    anchors.centerIn: parent
                    text: cooldown > 0 ? cooldown + "s" : "获取验证码"
                    color: "white"
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                }

                HoverHandler { id: sendHover }
                TapHandler {
                    enabled: cooldown === 0
                    onTapped: doSendCaptcha()
                }

                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
            }
        }

        // 错误提示
        Text {
            width: parent.width
            visible: loginPopup.errorMsg !== ""
            text: loginPopup.errorMsg
            color: AppTheme.errorColor
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        // 登录按钮
        Rectangle {
            width: parent.width
            height: 42
            radius: AppTheme.radiusMedium
            color: {
                if (userManager && userManager.isLoading) return AppTheme.textMuted
                return loginBtnHover.hovered ? AppTheme.accentHover : AppTheme.accent
            }

            Text {
                anchors.centerIn: parent
                text: userManager && userManager.isLoading ? "登录中..." : "登录"
                color: "white"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.weight: Font.DemiBold
                font.family: AppTheme.fontFamily
            }

            HoverHandler { id: loginBtnHover }
            TapHandler {
                enabled: !(userManager && userManager.isLoading)
                onTapped: doLogin()
            }

            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }

        // 底部提示
        Text {
            text: "使用酷狗音乐账号登录"
            color: AppTheme.textDim
            font.pixelSize: AppTheme.fontSizeCaption
            font.family: AppTheme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // 倒计时定时器
    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            loginPopup.cooldown--
            if (loginPopup.cooldown <= 0) {
                cooldownTimer.stop()
            }
        }
    }

    function doSendCaptcha() {
        if (!userManager) return
        var phone = phoneInput.text.trim()
        if (phone.length !== 11) {
            loginPopup.errorMsg = "请输入正确的手机号"
            return
        }
        loginPopup.errorMsg = ""
        userManager.sendCaptcha(phone)
    }

    function doLogin() {
        if (!userManager) return
        var phone = phoneInput.text.trim()
        var code = codeInput.text.trim()
        if (phone.length !== 11) {
            loginPopup.errorMsg = "请输入正确的手机号"
            return
        }
        if (code.length === 0) {
            loginPopup.errorMsg = "请输入验证码"
            return
        }
        loginPopup.errorMsg = ""
        userManager.loginByPhone(phone, code)
    }

    Connections {
        target: userManager
        function onLoginSuccess() {
            loginPopup.errorMsg = ""
            phoneInput.text = ""
            codeInput.text = ""
            loginPopup.close()
        }
        function onLoginFailed(error) {
            loginPopup.errorMsg = error
        }
        function onCaptchaSent(success, msg) {
            if (success) {
                loginPopup.cooldown = 60
                cooldownTimer.start()
            } else {
                loginPopup.errorMsg = msg
            }
        }
    }

    onOpened: {
        phoneInput.forceActiveFocus()
    }

    onClosed: {
        errorMsg = ""
    }
}
