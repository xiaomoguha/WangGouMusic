import QtQuick 2.15
import QtQuick.Controls 2.15
import "../BasicConfig"

ThemedPopup {
    id: loginPopup

    width: 360
    height: contentColumn.implicitHeight + 56

    property string errorMsg: ""
    property int cooldown: 0
    property bool qrTabActive: false      // false=验证码登录，true=扫码登录
    property string qrKey: ""
    property string qrImg: ""             // data:image/png;base64,xxx（Image source 可直接用）
    property int qrStatus: 1              // 0过期/1等待/2待确认/4成功
    property bool succeed: false          // 登录成功：盖成功提示层，延时关闭

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

        // 登录方式切换：验证码登录 | 扫码登录
        // 两 tab 各占半宽、文字水平居中，关于弹窗中线对称（Row 已占满宽，无需再居中）
        Row {
            width: parent.width
            spacing: 28

            Text {
                text: "验证码登录"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.weight: Font.DemiBold
                font.family: AppTheme.fontFamily
                color: !loginPopup.qrTabActive ? AppTheme.accent : AppTheme.textMuted
                width: parent.width / 2 - 14
                horizontalAlignment: Text.AlignHCenter

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        loginPopup.qrTabActive = false
                        loginPopup.errorMsg = ""
                    }
                }
            }

            Text {
                text: "扫码登录"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.weight: Font.DemiBold
                font.family: AppTheme.fontFamily
                color: loginPopup.qrTabActive ? AppTheme.accent : AppTheme.textMuted
                width: parent.width / 2 - 14
                horizontalAlignment: Text.AlignHCenter

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        loginPopup.qrTabActive = true
                        loginPopup.errorMsg = ""
                        // 每次进入扫码 tab 都用全新 key：旧码可能已过期/已授权，复用会卡死
                        if (userManager)
                            userManager.fetchQrKey()
                    }
                }
            }
        }

        // 扫码面板
        Column {
            width: parent.width
            visible: loginPopup.qrTabActive
            spacing: 12

            Item {
                width: parent.width
                height: 210

                // 二维码（data URL 直接显示）
                Image {
                    id: qrImgView
                    anchors.centerIn: parent
                    width: 170
                    height: 170
                    source: loginPopup.qrImg
                    asynchronous: false
                    visible: source !== ""
                    fillMode: Image.PreserveAspectFit
                }

                // 加载中/过期遮罩
                Rectangle {
                    anchors.centerIn: parent
                    width: 170
                    height: 170
                    radius: 8
                    color: AppTheme.bgCard
                    visible: loginPopup.qrImg === "" || loginPopup.qrStatus === 0
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: loginPopup.qrStatus === 0 ? "二维码已过期" : "正在生成二维码..."
                            color: AppTheme.textMuted
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                        }
                        // 过期时显示刷新按钮
                        Rectangle {
                            visible: loginPopup.qrStatus === 0
                            width: 80
                            height: 32
                            radius: 16
                            color: AppTheme.accent
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text {
                                anchors.centerIn: parent
                                text: "刷新"
                                color: "white"
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: if (userManager) userManager.fetchQrKey()
                            }
                        }
                    }
                }
            }

            // 扫码状态提示
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (loginPopup.qrStatus === 4) return "登录成功"
                    if (loginPopup.qrStatus === 2) return "已扫码，请在手机上确认"
                    if (loginPopup.qrStatus === 0) return "二维码已过期，请刷新"
                    return "打开酷狗 APP 扫描二维码登录"
                }
                color: loginPopup.qrStatus === 2 ? AppTheme.accent : AppTheme.textMuted
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }

        // 手机号
        TextField {
            id: phoneInput
            visible: !loginPopup.qrTabActive
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
            visible: !loginPopup.qrTabActive
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
            visible: loginPopup.errorMsg !== "" && !loginPopup.qrTabActive
            text: loginPopup.errorMsg
            color: AppTheme.errorColor
            font.pixelSize: AppTheme.fontSizeSmall
            font.family: AppTheme.fontFamily
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        // 登录按钮
        Rectangle {
            visible: !loginPopup.qrTabActive
            width: parent.width
            height: 42
            radius: AppTheme.radiusMedium
            color: {
                if (userManager && userManager.isLoading) return AppTheme.textMuted
                // 浅色模式深底（白字）/ 深色模式白底（黑字），保证文字对比度
                return loginBtnHover.hovered ? AppTheme.textSecondary : AppTheme.textPrimary
            }

            Text {
                anchors.centerIn: parent
                text: userManager && userManager.isLoading ? "登录中..." : "登录"
                color: AppTheme.isDark ? "#1A1A2E" : "#FFFFFF"
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
            visible: !loginPopup.qrTabActive
            text: "使用酷狗音乐账号登录"
            color: AppTheme.textDim
            font.pixelSize: AppTheme.fontSizeCaption
            font.family: AppTheme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // 登录成功覆盖层：盖整弹窗，绿色 ✓ + 文案，停 1s 后自动关弹窗
    Rectangle {
        id: succeedOverlay
        anchors.fill: parent
        radius: loginPopup.dialogRadius
        color: AppTheme.bgOverlay
        visible: loginPopup.succeed
        opacity: loginPopup.succeed ? 1 : 0
        z: 10
        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }

        Column {
            anchors.centerIn: parent
            spacing: 14

            Rectangle {
                width: 60; height: 60; radius: 30
                color: AppTheme.successColor
                anchors.horizontalCenter: parent.horizontalCenter
                scale: loginPopup.succeed ? 1 : 0.4
                Behavior on scale { NumberAnimation { duration: AppTheme.animNormal; easing.type: Easing.OutBack } }
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "white"
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }
            }
            Text {
                text: "登录成功"
                color: AppTheme.textPrimary
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.weight: Font.Bold
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 拦截点击，避免穿透到下层表单
        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    // 成功展示 1s 后关弹窗
    Timer {
        id: succeedTimer
        interval: 1000
        onTriggered: {
            loginPopup.succeed = false
            loginPopup.close()
        }
    }

    // 扫码轮询：2.5s 一次，仅扫码 tab 激活且弹窗打开时运行
    Timer {
        id: qrPollTimer
        interval: 2500
        repeat: true
        running: loginPopup.qrTabActive && loginPopup.opened && loginPopup.qrKey !== "" && loginPopup.qrStatus !== 4
        onTriggered: {
            console.log("[LoginPage] QR 轮询 key=" + loginPopup.qrKey + " status=" + loginPopup.qrStatus)
            if (userManager) userManager.checkQrStatus(loginPopup.qrKey)
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
            qrPollTimer.stop()
            loginPopup.succeed = true
            succeedTimer.start()
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
        function onQrKeyReady(key, imgBase64) {
            loginPopup.qrKey = key
            loginPopup.qrImg = imgBase64
            loginPopup.qrStatus = 1
            loginPopup.errorMsg = ""
        }
        function onQrKeyFailed(error) {
            loginPopup.errorMsg = error
        }
        function onQrStatusReady(status) {
            loginPopup.qrStatus = status
            if (status === 0) {
                // 过期：自动换新码继续等（二维码有效期 ~90s，用户扫码动作慢，手动刷新容易卡死）
                qrPollTimer.stop()
                if (userManager)
                    userManager.fetchQrKey()
            }
        }
    }

    onOpened: {
        if (qrTabActive) {
            // 重开弹窗一律换新码（旧码过期/已授权都会卡死轮询）
            if (userManager)
                userManager.fetchQrKey()
        } else {
            phoneInput.forceActiveFocus()
        }
    }

    onClosed: {
        errorMsg = ""
        succeed = false
        qrPollTimer.stop()
    }
}
