import QtQuick 2.15
import QtQuick.Controls 2.15
import "../BasicConfig"

// 设置页：顶部横向标签页（网易云风格）+ 下方分区滚动。
// 点标签滚到对应区，滚动也反向高亮标签。网络代理（proxyManager）+ 桌面歌词。
Rectangle {
    id: settingsPage
    color: "transparent"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // 顶部标题 + 横向标签
    Item {
        id: tabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 96

        Text {
            text: "设置"
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeTitleLg
            font.weight: Font.Bold
            font.family: AppTheme.fontFamily
            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.top: parent.top
            anchors.topMargin: 24
        }

        Row {
            id: tabRow
            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.bottom: parent.bottom
            spacing: 32

            Repeater {
                model: [
                    { key: "network", title: "网络代理" },
                    { key: "lyrics", title: "桌面歌词" }
                ]
                delegate: Item {
                    required property var modelData
                    width: tabText.implicitWidth
                    height: 42

                    Text {
                        id: tabText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        text: modelData.title
                        color: settingsPage.currentSection === modelData.key ? AppTheme.textPrimary : AppTheme.textSecondary
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.weight: settingsPage.currentSection === modelData.key ? Font.DemiBold : Font.Normal
                        font.family: AppTheme.fontFamily
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }

                    // 选中下划线（缩放进出）
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: tabText.implicitWidth + 8
                        height: 3
                        radius: 1.5
                        color: AppTheme.accent
                        scale: settingsPage.currentSection === modelData.key ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: settingsPage.selectSection(modelData.key)
                    }
                }
            }
        }

        // 底部分隔线
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: AppTheme.borderSubtle
        }
    }

    // 下方滚动区（单列居中，点标签/滚动双向联动）
    Flickable {
        id: settingsFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Behavior on contentY { SmoothedAnimation { duration: 300; easing.type: Easing.OutCubic } }

        function scrollTo(y) {
            cancelFlick()
            contentY = Math.max(0, Math.min(y, contentHeight - height))
        }

        // 滚动时反向高亮当前 section 对应的导航项
        onContentYChanged: {
            Qt.callLater(function() {
                if (lyricsSection && lyricsSection.y - settingsFlick.contentY < 120)
                    settingsPage.currentSection = "lyrics"
                else
                    settingsPage.currentSection = "network"
            })
        }

        Column {
            id: contentCol
            width: settingsFlick.width - 80
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20
            topPadding: 24

            // ===== 网络代理 section =====
            Rectangle {
                id: networkSection
                width: parent.width
                height: networkCol.implicitHeight + 48
                radius: AppTheme.radiusLarge
                color: AppTheme.bgCard
                border.width: 1
                border.color: AppTheme.borderSubtle

                Column {
                    id: networkCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    Text {
                        text: "网络代理"
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeTitle
                        font.weight: Font.Bold
                        font.family: AppTheme.fontFamily
                    }
                    Text {
                        width: parent.width
                        text: "代理影响所有网络请求（接口、歌曲、一起听）。选择「不使用代理」可绕开 Clash 等全局代理。"
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        wrapMode: Text.Wrap
                    }

                    // 三个代理模式
                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [
                                { mode: 0, title: "不使用代理", desc: "强制直连，绕开 Clash 等全局代理" },
                                { mode: 1, title: "系统代理", desc: "跟随系统代理设置（默认）" },
                                { mode: 2, title: "自定义代理", desc: "指定 HTTP / SOCKS5 代理地址" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 52
                                radius: AppTheme.radiusMedium
                                color: settingsPage.editMode === modelData.mode ? AppTheme.accentDim : AppTheme.bgInput
                                border.width: 1
                                border.color: settingsPage.editMode === modelData.mode ? AppTheme.accent : AppTheme.borderSubtle
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: modelData.title
                                        color: AppTheme.textPrimary
                                        font.pixelSize: AppTheme.fontSizeBody
                                        font.weight: Font.DemiBold
                                        font.family: AppTheme.fontFamily
                                    }
                                    Text {
                                        text: modelData.desc
                                        color: AppTheme.textMuted
                                        font.pixelSize: AppTheme.fontSizeCaption
                                        font.family: AppTheme.fontFamily
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✓"
                                    color: AppTheme.accent
                                    font.pixelSize: AppTheme.fontSizeBodyLg
                                    font.weight: Font.Bold
                                    visible: settingsPage.editMode === modelData.mode
                                }

                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: settingsPage.editMode = modelData.mode
                                }
                            }
                        }
                    }

                    // 自定义代理配置
                    Column {
                        width: parent.width
                        visible: settingsPage.editMode === 2
                        spacing: 10

                        // 类型：HTTP / SOCKS5
                        Item {
                            width: parent.width; height: 30
                            Text {
                                text: "类型"
                                color: AppTheme.textSecondary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: [{ t: "HTTP", v: 0 }, { t: "SOCKS5", v: 1 }]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 64; height: 30; radius: 15
                                        color: settingsPage.editType === modelData.v ? AppTheme.accent : "transparent"
                                        border.width: 1
                                        border.color: settingsPage.editType === modelData.v ? AppTheme.accent : AppTheme.borderDefault
                                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.t
                                            color: settingsPage.editType === modelData.v ? "white" : AppTheme.textSecondary
                                            font.pixelSize: AppTheme.fontSizeSmall
                                            font.family: AppTheme.fontFamily
                                        }
                                        TapHandler {
                                            cursorShape: Qt.PointingHandCursor
                                            onTapped: settingsPage.editType = modelData.v
                                        }
                                    }
                                }
                            }
                        }

                        TextField {
                            id: hostInput
                            width: parent.width; height: 42
                            placeholderText: "代理地址（如 127.0.0.1）"
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            leftPadding: 14; rightPadding: 14
                            verticalAlignment: Text.AlignVCenter
                            background: Rectangle {
                                radius: AppTheme.radiusMedium
                                color: AppTheme.bgInput
                                border.color: hostInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderSubtle
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                            }
                            onEditingFinished: settingsPage.editHost = text.trim()
                        }

                        TextField {
                            id: portInput
                            width: parent.width; height: 42
                            placeholderText: "端口（如 7890）"
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            leftPadding: 14; rightPadding: 14
                            verticalAlignment: Text.AlignVCenter
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle {
                                radius: AppTheme.radiusMedium
                                color: AppTheme.bgInput
                                border.color: portInput.activeFocus ? AppTheme.borderFocus : AppTheme.borderSubtle
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                            }
                            onEditingFinished: {
                                var n = parseInt(text)
                                if (!isNaN(n)) settingsPage.editPort = n
                            }
                        }
                    }

                    // 错误提示
                    Text {
                        width: parent.width
                        visible: settingsPage.errMsg !== ""
                        text: settingsPage.errMsg
                        color: AppTheme.errorColor
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // 应用按钮
                    Rectangle {
                        width: parent.width; height: 42
                        radius: AppTheme.radiusMedium
                        color: applyHover.hovered ? AppTheme.accentHover : AppTheme.accent
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                        Text {
                            anchors.centerIn: parent
                            text: "应用"
                            color: "white"
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.weight: Font.DemiBold
                            font.family: AppTheme.fontFamily
                        }
                        HoverHandler { id: applyHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: settingsPage.applyConfig()
                        }
                    }
                }
            }

            // ===== 桌面歌词 section =====
            Rectangle {
                id: lyricsSection
                width: parent.width
                height: lyricsCol.implicitHeight + 48
                radius: AppTheme.radiusLarge
                color: AppTheme.bgCard
                border.width: 1
                border.color: AppTheme.borderSubtle

                Column {
                    id: lyricsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    Text {
                        text: "桌面歌词"
                        color: AppTheme.textPrimary
                        font.pixelSize: AppTheme.fontSizeTitle
                        font.weight: Font.Bold
                        font.family: AppTheme.fontFamily
                    }

                    // 方向：横向 / 竖向
                    Item {
                        width: parent.width
                        height: 30
                        Text {
                            text: "方向"
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            font.family: AppTheme.fontFamily
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Rectangle {
                                width: 56; height: 30; radius: 15
                                color: (lyricsConfig && !lyricsConfig.isVertical) ? AppTheme.accent : "transparent"
                                border.width: 1
                                border.color: (lyricsConfig && !lyricsConfig.isVertical) ? AppTheme.accent : AppTheme.borderDefault
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "横向"
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    color: (lyricsConfig && !lyricsConfig.isVertical) ? "white" : AppTheme.textSecondary
                                }
                                TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: settingsPage._setOrientation(false) }
                            }
                            Rectangle {
                                width: 56; height: 30; radius: 15
                                color: (lyricsConfig && lyricsConfig.isVertical) ? AppTheme.accent : "transparent"
                                border.width: 1
                                border.color: (lyricsConfig && lyricsConfig.isVertical) ? AppTheme.accent : AppTheme.borderDefault
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "竖向"
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    color: (lyricsConfig && lyricsConfig.isVertical) ? "white" : AppTheme.textSecondary
                                }
                                TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: settingsPage._setOrientation(true) }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: AppTheme.borderSubtle }

                    // 跳跃歌词开关
                    Item {
                        width: parent.width
                        height: 42
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: "跳跃歌词"
                                color: AppTheme.textPrimary
                                font.pixelSize: AppTheme.fontSizeBodyLg
                                font.family: AppTheme.fontFamily
                            }
                            Text {
                                text: "（仅横向歌词支持）关闭则普通刷过"
                                color: AppTheme.textMuted
                                font.pixelSize: AppTheme.fontSizeCaption
                                font.family: AppTheme.fontFamily
                            }
                        }
                        Rectangle {
                            width: 46; height: 26; radius: 13
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: (lyricsConfig && lyricsConfig.jumpEnabled) ? AppTheme.accent : AppTheme.scrollbarColor
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Rectangle {
                                x: (lyricsConfig && lyricsConfig.jumpEnabled) ? parent.width - width - 3 : 3
                                y: 3; width: 20; height: 20; radius: 10; color: "white"
                                Behavior on x { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }
                            }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    if (!lyricsConfig) return
                                    lyricsConfig.jumpEnabled = !lyricsConfig.jumpEnabled
                                    lyricsConfig.saveConfig()
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: AppTheme.borderSubtle }

                    ColorField {
                        width: parent.width
                        label: "歌词颜色"
                        colorValue: lyricsConfig ? lyricsConfig.lyricsColor : ""
                        onColorEdited: function(hex) {
                            if (!lyricsConfig) return
                            lyricsConfig.lyricsColor = hex
                            lyricsConfig.saveConfig()
                        }
                    }

                    ColorField {
                        width: parent.width
                        label: "跳跃歌词颜色"
                        colorValue: lyricsConfig ? lyricsConfig.starColor : ""
                        onColorEdited: function(hex) {
                            if (!lyricsConfig) return
                            lyricsConfig.starColor = hex
                            lyricsConfig.saveConfig()
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: AppTheme.borderSubtle }

                    // 大小
                    Column {
                        width: parent.width
                        spacing: 8
                        Item {
                            width: parent.width; height: 16
                            Text {
                                text: "大小"
                                color: AppTheme.textSecondary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: lyricsConfig ? Math.round(lyricsConfig.scale * 100) + "%" : "100%"
                                color: AppTheme.textPrimary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.bold: true
                                font.family: AppTheme.fontFamily
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Slider {
                            width: parent.width
                            from: 0.6; to: 1.5; stepSize: 0.05
                            Binding on value { value: lyricsConfig ? lyricsConfig.scale : 1.0; restoreMode: Binding.RestoreBindingOrValue }
                            onMoved: {
                                if (!lyricsConfig) return
                                lyricsConfig.scale = value
                                lyricsConfig.saveConfig()
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: AppTheme.borderSubtle }

                    // 歌词偏移（±0.25s 微调，按歌生效）
                    Column {
                        width: parent.width
                        spacing: 8
                        Item {
                            width: parent.width; height: 18
                            Text {
                                text: "歌词偏移"
                                color: AppTheme.textSecondary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: {
                                    if (!playlistmanager || playlistmanager.lyricOffsetMs === 0) return "0.00s"
                                    var sign = playlistmanager.lyricOffsetMs > 0 ? "+" : ""
                                    return sign + (playlistmanager.lyricOffsetMs / 1000).toFixed(2) + "s"
                                }
                                font.pixelSize: AppTheme.fontSizeBody
                                font.bold: true
                                font.family: AppTheme.fontFamily
                                color: (playlistmanager && playlistmanager.lyricOffsetMs !== 0) ? AppTheme.accent : AppTheme.textMuted
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: [{ t: "提前 0.25s", d: 250 }, { t: "复原", d: 0 }, { t: "延后 0.25s", d: -250 }]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (parent.width - 12) / 3; height: 32; radius: 16
                                    color: offsetHover.hovered ? AppTheme.iconButtonHover : AppTheme.bgInput
                                    border.width: 1
                                    border.color: AppTheme.borderDefault
                                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.t
                                        font.pixelSize: AppTheme.fontSizeSmall
                                        font.family: AppTheme.fontFamily
                                        color: AppTheme.textSecondary
                                    }
                                    HoverHandler { id: offsetHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: {
                                            if (!playlistmanager) return
                                            if (modelData.d === 0) playlistmanager.resetLyricOffset()
                                            else playlistmanager.adjustLyricOffset(modelData.d)
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

    // ===== 状态 =====
    property string currentSection: "network"
    property int editMode: 1
    property string editHost: ""
    property int editPort: 7890
    property int editType: 0
    property string errMsg: ""

    function selectSection(key) {
        currentSection = key
        if (key === "network" && networkSection) settingsFlick.scrollTo(networkSection.y - 12)
        else if (key === "lyrics" && lyricsSection) settingsFlick.scrollTo(lyricsSection.y - 12)
    }

    function applyConfig() {
        if (!proxyManager) return
        if (editMode === 2) {
            if (hostInput.text.trim() === "") { errMsg = "请输入代理地址"; return }
            var p = parseInt(portInput.text)
            if (isNaN(p) || p <= 0 || p > 65535) { errMsg = "端口需为 1-65535"; return }
            editHost = hostInput.text.trim()
            editPort = p
        }
        var ok = proxyManager.setConfig(editMode, editHost, editPort, editType)
        if (ok) {
            errMsg = ""
            BasicConfig.noticeSuccess("代理设置已应用")
        } else {
            errMsg = "配置无效，请检查地址与端口"
        }
    }

    // 切换横/竖向：写配置 + 让桌面歌词窗口按新方向重新定位
    function _setOrientation(vertical) {
        if (!lyricsConfig) return
        lyricsConfig.isVertical = vertical
        lyricsConfig.saveConfig()
        if (desktopLyricsWindow) {
            desktopLyricsWindow._suppressCentering = true
            Qt.callLater(function() {
                desktopLyricsWindow.restorePosition()
                desktopLyricsWindow.enableCentering()
            })
        }
    }

    Component.onCompleted: {
        // 进入设置页：从生效配置同步编辑态（代理只在设置页改，apply 后保持一致）
        if (proxyManager) {
            editMode = proxyManager.mode
            editHost = proxyManager.customHost
            editPort = proxyManager.customPort
            editType = proxyManager.customType
        }
        hostInput.text = editHost
        portInput.text = editPort
    }
}
