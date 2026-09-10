import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 设置页：顶部横向标签页（网易云风格）+ 下方分区滚动。
// 点标签滚到对应区，滚动也反向高亮标签。网络代理（proxyManager）+ 桌面歌词。
Rectangle {
    id: settingsPage
    color: "transparent"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // ===== 入场动画 =====
    // 标题/标签先起，三张卡片依次上浮（错开 0.12）；页面首次创建时播一次
    property real enterProgress: 0
    function enterAlpha(i) {
        var p = (settingsPage.enterProgress - i * 0.12) / 0.5
        return Math.max(0, Math.min(1, p))
    }
    Timer {
        interval: 24
        running: true
        repeat: false
        onTriggered: enterAnim.start()
    }
    NumberAnimation {
        id: enterAnim
        target: settingsPage
        property: "enterProgress"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.OutCubic
    }

    // 分区标题：只占文字本体尺寸，光晕溢出到父项外
    //（直接用 GlowText 的话，它给光晕留的 padding 会把列布局撑开、标题也会错位）
    component SectionTitle: Item {
        property alias text: secLabel.text
        readonly property real glowPad: 10
        implicitWidth: secLabel.implicitWidth - glowPad * 2
        implicitHeight: secLabel.implicitHeight - glowPad * 2

        GlowText {
            id: secLabel
            anchors.centerIn: parent
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeTitle
            font.weight: Font.Bold
            glowRadius: parent.glowPad
            glowSpread: 0.05
            glowColor: Qt.rgba(1, 1, 1, 0.26)
        }
    }

    // 两端淡出的分隔线：玻璃卡片里比通栏实线柔和，不会有"切一刀"的观感
    component SoftDivider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.12; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.88; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }

    // 顶部标题 + 横向标签
    Item {
        id: tabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 96
        opacity: settingsPage.enterAlpha(0)
        transform: Translate { y: 10 * (1 - settingsPage.enterAlpha(0)) }

        GlowText {
            // 36/24 是文字本体的目标位置，GlowText 四周留了 glowRadius 给光晕，这里减掉
            anchors.left: parent.left
            anchors.leftMargin: 36 - 14
            anchors.top: parent.top
            anchors.topMargin: 24 - 14
            text: "设置"
            color: AppTheme.textPrimary
            font.pixelSize: AppTheme.fontSizeTitleLg
            font.weight: Font.Bold
            glowRadius: 14
            glowSpread: 0.06
            glowColor: Qt.rgba(1, 1, 1, 0.30)
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
                    { key: "lyrics", title: "桌面歌词" },
                    { key: "server", title: "服务器" }
                ]
                delegate: Item {
                    required property var modelData
                    width: tabText.implicitWidth + 24
                    height: 42

                    readonly property bool selected: settingsPage.currentSection === modelData.key

                    // hover 柔光胶囊（与搜索弹层同款：两端淡出，不铺实心块）
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        anchors.leftMargin: -2
                        anchors.rightMargin: -2
                        radius: height / 2
                        opacity: (tabHover.hovered && !parent.selected) ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
                            GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
                        }
                    }

                    Text {
                        id: tabText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        text: modelData.title
                        color: parent.selected ? AppTheme.textPrimary : (tabHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.weight: parent.selected ? Font.DemiBold : Font.Normal
                        font.family: AppTheme.fontFamily
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                    }

                    // 选中下划线（缩放进出）+ 同色柔光
                    Rectangle {
                        id: tabUnderline
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: tabText.implicitWidth + 8
                        height: 3
                        radius: 1.5
                        color: AppTheme.accent
                        scale: parent.selected ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                        layer.enabled: true
                        layer.effect: Glow {
                            radius: 7
                            samples: 13
                            spread: 0.12
                            color: AppTheme.accentGlow
                            transparentBorder: true
                        }
                    }

                    HoverHandler { id: tabHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: settingsPage.selectSection(modelData.key)
                    }
                }
            }
        }

        // 底部分隔线（两端淡出）
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.10; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 0.90; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.0) }
            }
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
                if (serverSection && serverSection.y - settingsFlick.contentY < 120)
                    settingsPage.currentSection = "server"
                else if (lyricsSection && lyricsSection.y - settingsFlick.contentY < 120)
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
                // 玻璃卡片：上亮下暗的竖向渐变（有上方光源感）+ 极细亮边
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.085) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.030) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                // 入场：依次上浮 + 淡入
                opacity: settingsPage.enterAlpha(1)
                transform: Translate { y: 16 * (1 - settingsPage.enterAlpha(1)) }

                Column {
                    id: networkCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    SectionTitle { text: "网络代理" }
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
                                id: modeRow
                                required property var modelData
                                readonly property bool _selected: settingsPage.editMode === modelData.mode
                                width: parent.width
                                height: 52
                                radius: AppTheme.radiusMedium
                                // 玻璃底：不再铺不透明块；选中=强调色淡染，hover=提亮一档
                                color: _selected ? AppTheme.accentDim
                                                 : (modeHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                                border.width: 1
                                border.color: _selected ? AppTheme.accent
                                                        : (modeHover.hovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12))
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    // hover 时内容轻微右移（与列表行同款反馈）
                                    transform: Translate {
                                        x: (modeHover.hovered && !modeRow._selected) ? 4 : 0
                                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    }
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
                                    // 选中标记：淡入 + 回弹放大
                                    opacity: modeRow._selected ? 1 : 0
                                    scale: modeRow._selected ? 1 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }
                                    Behavior on scale {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
                                    }
                                }

                                HoverHandler { id: modeHover }
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
                                spacing: 8
                                Repeater {
                                    model: [{ t: "HTTP", v: 0 }, { t: "SOCKS5", v: 1 }]
                                    delegate: Rectangle {
                                        id: typeChip
                                        required property var modelData
                                        readonly property bool _on: settingsPage.editType === modelData.v
                                        width: 64; height: 30; radius: 15
                                        color: _on ? AppTheme.accent
                                                   : (typeHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                                        border.width: 1
                                        border.color: _on ? AppTheme.accent
                                                          : (typeHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14))
                                        scale: typeTap.pressed ? 0.95 : (typeHover.hovered ? 1.04 : 1)
                                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                        Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.t
                                            color: typeChip._on ? "white" : (typeHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                                            font.pixelSize: AppTheme.fontSizeSmall
                                            font.family: AppTheme.fontFamily
                                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                        }
                                        HoverHandler { id: typeHover }
                                        TapHandler {
                                            id: typeTap
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
                                // 玻璃输入框：半透明填充，聚焦时提亮 + 强调色描边
                                color: hostInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: hostInput.activeFocus ? 1.5 : 1
                                border.color: hostInput.activeFocus ? AppTheme.borderFocus : Qt.rgba(1, 1, 1, 0.13)
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
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
                                color: portInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: portInput.activeFocus ? 1.5 : 1
                                border.color: portInput.activeFocus ? AppTheme.borderFocus : Qt.rgba(1, 1, 1, 0.13)
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
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
                        // hover 轻微上浮、按下回弹
                        scale: applyTap.pressed ? 0.985 : (applyHover.hovered ? 1.012 : 1)
                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
                            id: applyTap
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
                // 玻璃卡片：上亮下暗的竖向渐变（有上方光源感）+ 极细亮边
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.085) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.030) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                // 入场：依次上浮 + 淡入
                opacity: settingsPage.enterAlpha(2)
                transform: Translate { y: 16 * (1 - settingsPage.enterAlpha(2)) }

                Column {
                    id: lyricsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    SectionTitle { text: "桌面歌词" }

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
                            spacing: 8
                            Repeater {
                                model: [{ t: "横向", v: false }, { t: "竖向", v: true }]
                                delegate: Rectangle {
                                    id: orientChip
                                    required property var modelData
                                    readonly property bool _on: !!lyricsConfig && lyricsConfig.isVertical === modelData.v
                                    width: 56; height: 30; radius: 15
                                    color: _on ? AppTheme.accent
                                               : (orientHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                                    border.width: 1
                                    border.color: _on ? AppTheme.accent
                                                      : (orientHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14))
                                    scale: orientTap.pressed ? 0.95 : (orientHover.hovered ? 1.04 : 1)
                                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on scale {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.t
                                        font.family: AppTheme.fontFamily
                                        font.pixelSize: AppTheme.fontSizeSmall
                                        color: orientChip._on ? "white"
                                                              : (orientHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    }
                                    HoverHandler { id: orientHover }
                                    TapHandler {
                                        id: orientTap
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: settingsPage._setOrientation(modelData.v)
                                    }
                                }
                            }
                        }
                    }

                    SoftDivider {}

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
                            id: jumpSwitch
                            readonly property bool _on: !!lyricsConfig && lyricsConfig.jumpEnabled
                            width: 46; height: 26; radius: 13
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: _on ? AppTheme.accent : Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            border.color: _on ? AppTheme.accent
                                              : (jumpSwitchHover.hovered ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.18))
                            scale: jumpSwitchHover.hovered ? 1.06 : 1
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            // 滑块：OutBack 回弹，切换时有点"咔哒"的手感
                            Rectangle {
                                x: jumpSwitch._on ? parent.width - width - 3 : 3
                                y: 3; width: 20; height: 20; radius: 10; color: "white"
                                Behavior on x {
                                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
                                }
                            }
                            HoverHandler { id: jumpSwitchHover }
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

                    SoftDivider {}

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

                    SoftDivider {}

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
                            id: scaleSlider
                            width: parent.width
                            height: 34
                            from: 0.6; to: 1.5; stepSize: 0.05
                            Binding on value { value: lyricsConfig ? lyricsConfig.scale : 1.0; restoreMode: Binding.RestoreBindingOrValue }
                            onMoved: {
                                if (!lyricsConfig) return
                                lyricsConfig.scale = value
                                lyricsConfig.saveConfig()
                            }

                            // 轨道：半透明底 + 强调色填充（拖拽时不做动画，跟手）
                            background: Rectangle {
                                implicitHeight: 6
                                x: scaleSlider.leftPadding
                                y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                                width: scaleSlider.availableWidth
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.10)
                                Rectangle {
                                    width: parent.width * scaleSlider.visualPosition
                                    height: parent.height
                                    radius: parent.radius
                                    color: AppTheme.accent
                                    Behavior on width {
                                        enabled: !scaleSlider.pressed
                                        NumberAnimation { duration: AppTheme.animFast }
                                    }
                                }
                            }

                            // 白色旋钮 + 强调色描边，hover/拖拽时放大
                            handle: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                x: scaleSlider.leftPadding + scaleSlider.visualPosition * (scaleSlider.availableWidth - width)
                                y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                                width: 18
                                height: 18
                                radius: 9
                                color: "white"
                                border.width: 2
                                border.color: AppTheme.accent
                                scale: scaleSlider.pressed ? 1.25 : (scaleSliderHover.hovered ? 1.12 : 1)
                                Behavior on scale {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                                }
                            }

                            HoverHandler { id: scaleSliderHover }
                        }
                    }

                    SoftDivider {}

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
                                    id: offsetChip
                                    required property var modelData
                                    width: (parent.width - 12) / 3; height: 32; radius: 16
                                    color: offsetHover.hovered ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: offsetHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.13)
                                    scale: offsetTap.pressed ? 0.96 : (offsetHover.hovered ? 1.03 : 1)
                                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on scale {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.t
                                        font.pixelSize: AppTheme.fontSizeSmall
                                        font.family: AppTheme.fontFamily
                                        color: offsetHover.hovered ? AppTheme.textPrimary : AppTheme.textSecondary
                                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    }
                                    HoverHandler { id: offsetHover }
                                    TapHandler {
                                        id: offsetTap
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

            // ===== 服务器 section =====
            Rectangle {
                id: serverSection
                width: parent.width
                height: serverCol.implicitHeight + 48
                radius: AppTheme.radiusLarge
                // 玻璃卡片：上亮下暗的竖向渐变（有上方光源感）+ 极细亮边
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.085) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.030) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                // 入场：依次上浮 + 淡入
                opacity: settingsPage.enterAlpha(3)
                transform: Translate { y: 16 * (1 - settingsPage.enterAlpha(3)) }

                Column {
                    id: serverCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    SectionTitle { text: "服务器共享 Token" }
                    Text {
                        width: parent.width
                        text: "服务器取歌 token 被踢失效时：在本客户端重新扫码登录共享账号，回来点「同步」即可，服务器热更新免重启，重启后也会保留最新值。"
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        wrapMode: Text.Wrap
                    }

                    // 管理密钥
                    Column {
                        width: parent.width
                        spacing: 8
                        Text {
                            text: "管理密钥"
                            color: AppTheme.textSecondary
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                        }
                        TextField {
                            id: adminKeyInput
                            width: parent.width; height: 42
                            placeholderText: "粘贴服务器 ~/KuGouMusicApi/.env 里的 ADMIN_KEY"
                            echoMode: TextInput.Password
                            color: AppTheme.textPrimary
                            font.pixelSize: AppTheme.fontSizeBody
                            font.family: AppTheme.fontFamily
                            leftPadding: 14; rightPadding: 14
                            verticalAlignment: Text.AlignVCenter
                            background: Rectangle {
                                radius: AppTheme.radiusMedium
                                color: adminKeyInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: adminKeyInput.activeFocus ? 1.5 : 1
                                border.color: adminKeyInput.activeFocus ? AppTheme.borderFocus : Qt.rgba(1, 1, 1, 0.13)
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                            }
                            onEditingFinished: {
                                serverAdmin.setAdminKey(text)
                                serverMsgOk("管理密钥已保存")
                            }
                        }
                    }

                    SoftDivider {}

                    // 服务器当前状态
                    Column {
                        width: parent.width
                        spacing: 10

                        Item {
                            width: parent.width; height: 24
                            Text {
                                text: "当前共享状态"
                                color: AppTheme.textSecondary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.family: AppTheme.fontFamily
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: refreshLink
                                text: serverAdmin && serverAdmin.busy ? "查询中..." : "刷新"
                                color: refreshStatusHover.hovered ? AppTheme.textPrimary : AppTheme.accent
                                font.pixelSize: AppTheme.fontSizeSmall
                                font.family: AppTheme.fontFamily
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                                // hover 时下划线从中间展开
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 1
                                    height: 1
                                    width: parent.width * (refreshStatusHover.hovered ? 1 : 0)
                                    color: refreshLink.color
                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }

                                HoverHandler { id: refreshStatusHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: if (serverAdmin) serverAdmin.fetchStatus()
                                }
                            }
                        }

                        // 数据行（label + value 复用样式）
                        Repeater {
                            model: {
                                if (!serverStatus) return []
                                var dt = ""
                                if (serverStatus.updated_at) {
                                    var d = new Date(serverStatus.updated_at)
                                    if (!isNaN(d.getTime())) dt = Qt.formatDateTime(d, "MM-dd hh:mm")
                                }
                                return [
                                    { label: "账号", value: serverStatus.userid || "-" },
                                    { label: "会员", value: serverStatus.vip_type > 0 ? "VIP（类型 " + serverStatus.vip_type + "）" : "非 VIP" },
                                    { label: "Token", value: serverStatus.token_masked || "-" },
                                    { label: "更新时间", value: dt || "-" }
                                ]
                            }
                            delegate: Item {
                                required property var modelData
                                width: parent.width; height: 22
                                Text {
                                    text: modelData.label
                                    color: AppTheme.textMuted
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.value
                                    color: AppTheme.textPrimary
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.family: AppTheme.fontFamily
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Text {
                            visible: !serverStatus
                            text: "尚未获取——填好管理密钥后点「刷新」"
                            color: AppTheme.textDim
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                        }
                    }

                    SoftDivider {}

                    // 操作按钮
                    Row {
                        width: parent.width
                        spacing: 12

                        // 同步当前登录 token 到服务器
                        Rectangle {
                            width: (parent.width - 12) / 2; height: 42
                            radius: AppTheme.radiusMedium
                            // 未登录时置灰但仍可点（点了会提示先登录）
                            opacity: userManager && userManager.isLoggedIn ? 1 : 0.45
                            color: syncHover.hovered ? AppTheme.accentHover : AppTheme.accent
                            scale: syncTap.pressed ? 0.985 : (syncHover.hovered ? 1.012 : 1)
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: serverAdmin && serverAdmin.busy ? "处理中..." : "同步当前登录 Token"
                                color: "white"
                                font.pixelSize: AppTheme.fontSizeBody
                                font.weight: Font.DemiBold
                                font.family: AppTheme.fontFamily
                            }
                            HoverHandler { id: syncHover }
                            TapHandler {
                                id: syncTap
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    if (!serverAdmin) return
                                    if (!userManager || !userManager.isLoggedIn) {
                                        serverMsgErr("请先在客户端登录共享账号，再同步到服务器")
                                        return
                                    }
                                    serverMsgOk("正在同步（服务器会先向酷狗校验 token）...")
                                    serverAdmin.syncToken(userManager.token, userManager.userid)
                                }
                            }
                        }

                        // 检测服务器 token 有效性
                        Rectangle {
                            width: (parent.width - 12) / 2; height: 42
                            radius: AppTheme.radiusMedium
                            color: checkHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: checkHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                            scale: checkTap.pressed ? 0.985 : (checkHover.hovered ? 1.012 : 1)
                            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: serverAdmin && serverAdmin.busy ? "检测中..." : "检测 Token 有效性"
                                color: AppTheme.textPrimary
                                font.pixelSize: AppTheme.fontSizeBody
                                font.weight: Font.DemiBold
                                font.family: AppTheme.fontFamily
                            }
                            HoverHandler { id: checkHover }
                            TapHandler {
                                id: checkTap
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    if (!serverAdmin) return
                                    serverMsgOk("正在检测...")
                                    serverAdmin.checkToken()
                                }
                            }
                        }
                    }

                    Text {
                        visible: userManager && !userManager.isLoggedIn
                        width: parent.width
                        text: "当前客户端未登录：同步需要先用共享账号扫码登录"
                        color: AppTheme.textMuted
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        wrapMode: Text.Wrap
                    }

                    // 结果提示
                    Text {
                        width: parent.width
                        visible: serverMsg !== ""
                        text: serverMsg
                        color: serverMsgIsError ? AppTheme.errorColor : AppTheme.accent
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.family: AppTheme.fontFamily
                        wrapMode: Text.Wrap
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

    // 服务器分区状态
    property var serverStatus: null       // {userid, vip_type, token_masked, updated_at}
    property string serverMsg: ""
    property bool serverMsgIsError: false

    function serverMsgOk(msg) { serverMsg = msg; serverMsgIsError = false }
    function serverMsgErr(msg) { serverMsg = msg; serverMsgIsError = true }

    Connections {
        target: serverAdmin
        function onStatusReceived(data) { serverStatus = data }
        function onSyncResult(data) {
            serverStatus = data
            serverMsgOk("已同步并生效 ✓（账号 " + data.userid + "，VIP 类型 " + data.vip_type + "）")
        }
        function onCheckResult(data) {
            if (data.valid)
                serverMsgOk("服务器 token 当前有效 ✓（账号 " + data.userid + "，VIP 类型 " + data.vip_type + "）")
            else
                serverMsgErr(data.msg || "token 已失效，请重新扫码登录后同步")
        }
        function onRequestFailed(operation, error) {
            serverMsgErr(error)
        }
    }

    function selectSection(key) {
        currentSection = key
        if (key === "network" && networkSection) settingsFlick.scrollTo(networkSection.y - 12)
        else if (key === "lyrics" && lyricsSection) settingsFlick.scrollTo(lyricsSection.y - 12)
        else if (key === "server" && serverSection) {
            settingsFlick.scrollTo(serverSection.y - 12)
            if (serverAdmin && serverAdmin.adminKey !== "" && !serverStatus && !serverAdmin.busy)
                serverAdmin.fetchStatus()
        }
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
        // 服务器分区：回显已存密钥，密钥就绪则顺带拉一次状态
        if (serverAdmin) {
            adminKeyInput.text = serverAdmin.adminKey
            if (serverAdmin.adminKey !== "")
                serverAdmin.fetchStatus()
        }
    }
}
