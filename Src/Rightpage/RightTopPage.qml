import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

//上层状态栏
Item {
    id: rightTop
    property bool canGoBack: false
    signal goBack()

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
