import QtQuick
import QtQuick.Effects
import ".."
import "../Src/BasicConfig"

// 全屏播放页 —— 仿网易云音乐手机版（截图②）：
// 封面高斯模糊背景；顶部 ∨收起 + 居中歌名/歌手 + 分享；
// 中部"黑胶唱片 ↔ 全屏滚动歌词"点击切换（网易云双模式）；
// 音质/收藏/评论动作行 + 进度条两侧时间 + 实心三角五键 + 底部辅助图标行。
// 歌词：playlistmanager.m_lyrics + lyricsindex（KRC 通道，与桌面同源）。
Rectangle
{
    id: root

    property bool shown: false
    property real dragY: 0
    property bool lyricsMode: false   // 黑胶视图 / 歌词视图

    // ===== 前景色自适应：按封面主色亮度决定深/浅前景 =====
    // 背景亮 → 深色按钮/文字；背景暗 → 白色，避免固定色看不清
    readonly property bool bgDark: {
        var c = playlistmanager ? playlistmanager.dominantColor : ""
        if (!c || c === "")
            return true
        try {
            var col = Qt.color(c)
            return (0.299 * col.r + 0.587 * col.g + 0.114 * col.b) < 0.6
        } catch (e) {
            return true
        }
    }
    readonly property color fgStrong: "#FFFFFFFF"                       // 主文字/主图标（永远纯白）
    readonly property color fgMid: bgDark ? "#E6FFFFFF" : "#D9FFFFFF"   // 次级
    readonly property color fgDim: bgDark ? "#99FFFFFF" : "#8CFFFFFF"   // 弱化/描边

    // 主播放键磨砂圆盘（参考网易云：全页唯一带底座的按钮）
    component GlassCircle: Rectangle {
        radius: width / 2
        color: "#2EFFFFFF"
        border.width: 1
        border.color: "#24FFFFFF"
    }

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    // 关闭态停在屏外（可见性由位置决定）
    y: root.shown ? root.dragY : root.height
    visible: y < root.height - 1
    color: "#26262B"
    clip: true

    function openPage() { root.shown = true }
    function closePage() { root.shown = false }

    // 进度条 seek（拖动/点击），钳制到 0..1
    function seekTo(p) {
        playlistmanager.seekToPercent(Math.max(0, Math.min(1, p)))
    }

    // 拖拽进行中关闭 Behavior（跟手），松手恢复动画（回弹/收起）
    Behavior on y {
        enabled: !dragHandler.active
        NumberAnimation { duration: MTheme.animNormal; easing.type: Easing.OutCubic }
    }

    DragHandler {
        id: dragHandler

        xAxis.enabled: false
        onTranslationChanged: if (active) root.dragY = Math.max(0, translation.y)
        onActiveChanged: {
            if (!active) {
                if (root.dragY > root.height * 0.18)
                    root.shown = false
                root.dragY = 0
            }
        }
    }

    // ===== 背景：封面高斯模糊（网易云同款）+ 压暗保可读性 =====
    Image {
        id: bgSource

        anchors.fill: parent
        anchors.margins: -60   // 外扩：模糊后边缘不露底
        source: playlistmanager.union_cover !== "" ? playlistmanager.union_cover : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: bgSource
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: -0.45
        brightness: root.bgDark ? -0.30 : -0.42
    }
    // 页面下部渐进压暗（参考网易云：越往下越深，保证控制区图标可读）
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 0.8; color: "#4D000000" }
            GradientStop { position: 1.0; color: "#90000000" }
        }
    }
    // 整页压暗：亮封面压得更重，保证白色图标永远清晰（参考图策略）
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.bgDark ? 0.32 : 0.45
    }

    // ===== 顶栏：∨ / 歌名+歌手 / 分享 =====
    Item {
        id: topBlock

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: MTheme.safeTop + 2
        height: 58

        // ∨ 收起
        Item {
            width: MTheme.touchMin
            height: MTheme.touchMin
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter

            MIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: AppIcon.caretDown
                color: root.fgStrong
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.closePage()
            }
        }

        // 歌名 + 歌手（居中）
        Column {
            anchors.centerIn: parent
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: playlistmanager.currentTitle
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBodyLg
                font.bold: true
                color: root.fgStrong
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: playlistmanager.currentsingername
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontCaption
                color: root.fgMid
            }
        }

        // 分享
        Item {
            width: MTheme.touchMin
            height: MTheme.touchMin
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter

            MIcon {
                anchors.centerIn: parent
                width: 19
                height: 19
                source: AppIcon.share
                color: root.fgStrong
            }
            MouseArea {
                anchors.fill: parent
                // 分享功能待移植
                onClicked: { /* 分享（占位） */ }
            }
        }
    }

    // ===== 中区：黑胶 ↔ 歌词（点击切换） =====
    Item {
        id: centerBlock

        anchors.top: topBlock.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBlock.top

        // ---- 黑胶唱片视图 ----
        Item {
            id: vinylView

            anchors.fill: parent
            visible: !root.lyricsMode

            Item {
                id: vinylWrap

                width: Math.min(parent.width - 90, 264)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(18, (parent.height - height) / 2 - 46)

                // 唱片（旋转：播放时匀速、暂停即停、恢复续转）
                Item {
                    id: disc

                    anchors.fill: parent

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        duration: 22000
                        to: 360
                        // 停在屏外或暂停时不运行；恢复时从当前角度续转（不写 from，避免跳回 0 点）
                        running: root.visible && !playlistmanager.isPaused
                    }

                    // 盘体
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2B2B2B" }
                            GradientStop { position: 0.5; color: "#161616" }
                            GradientStop { position: 1.0; color: "#050505" }
                        }
                    }

                    // 同心黑胶纹
                    Repeater {
                        model: [0.94, 0.83, 0.72]

                        delegate: Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * modelData
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: "#2E2E2E"
                        }
                    }

                    // 中心圆封面（MCover 圆形遮罩：图片严格裁进圆内）
                    Item {
                        anchors.centerIn: parent
                        width: parent.width * 0.66
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: MTheme.bgInput
                            border.width: 5
                            border.color: "#0A0A0A"
                        }

                        MCover {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: width / 2
                            source: playlistmanager.union_cover
                        }

                        MIcon {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            visible: playlistmanager.union_cover === ""
                            source: AppIcon.musicNotes
                            color: "#666666"
                        }
                    }
                }

                // 唱针（不随盘旋转）：播放落针 / 暂停抬针
                Item {
                    id: needleArm

                    width: 96
                    height: 128
                    x: parent.width - 42
                    y: -20
                    z: 10
                    rotation: playlistmanager.isPaused ? -30 : 0
                    transformOrigin: Item.TopLeft
                    Behavior on rotation { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                    // 底座（红点转轴）
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: "#F2F2F2"
                        border.width: 1
                        border.color: "#C8C8C8"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: MTheme.accent
                        }
                    }

                    // 针臂
                    Rectangle {
                        x: 12
                        y: 23
                        width: 4
                        height: 82
                        radius: 2
                        color: "#DADADA"
                        rotation: 16
                        transformOrigin: Item.Top
                    }

                    // 针头
                    Rectangle {
                        x: 27
                        y: 101
                        width: 13
                        height: 18
                        radius: 4
                        color: "#C4C4C4"
                    }
                }
            }

            // 当前歌词一行（黑胶模式下显示）
            Item {
                width: parent.width
                height: 26
                anchors.top: vinylWrap.bottom
                anchors.topMargin: 22

                Text {
                    width: parent.width - 64
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: playlistmanager.currlyric !== "" ? playlistmanager.currlyric : qsTr("♪ 网狗音乐")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBodyLg
                    color: root.fgStrong
                }
            }

            // 点击黑胶 → 切歌词视图
            MouseArea {
                anchors.fill: parent
                onClicked: root.lyricsMode = true
            }
        }

        // ---- 全屏滚动歌词视图 ----
        Item {
            id: lyricsView

            anchors.fill: parent
            anchors.topMargin: 12
            visible: root.lyricsMode

            ListView {
                id: lyricList

                anchors.fill: parent
                clip: true
                spacing: 18
                interactive: false
                model: playlistmanager ? playlistmanager.m_lyrics : 0
                currentIndex: playlistmanager ? playlistmanager.lyricsindex : -1

                // 当前行锁定屏中（与桌面 PlayingPage 同策略）
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * 0.42
                preferredHighlightEnd: height * 0.52
                highlightMoveDuration: 400
                highlightMoveVelocity: -1

                delegate: Text {
                    id: lyricLine

                    required property int index
                    required property var modelData

                    width: lyricList.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.text !== undefined ? (modelData.text || "") : ""
                    textFormat: Text.PlainText
                    font.family: MTheme.fontFamily
                    font.pixelSize: lyricLine.ListView.isCurrentItem ? MTheme.fontTitle : MTheme.fontBodyLg
                    font.bold: lyricLine.ListView.isCurrentItem
                    color: lyricLine.ListView.isCurrentItem ? root.fgStrong : root.fgMid
                    opacity: {
                        if (!lyricList.currentIndex || lyricList.currentIndex < 0)
                            return 0.85
                        var d = Math.abs(lyricLine.index - lyricList.currentIndex)
                        return Math.max(0.25, 1.0 - d * 0.16)
                    }
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    lineHeight: 1.25

                    Behavior on font.pixelSize { NumberAnimation { duration: MTheme.animFast } }
                }
            }

            // 无歌词兜底
            Text {
                anchors.centerIn: parent
                visible: !playlistmanager || playlistmanager.m_lyrics.length === 0
                text: playlistmanager.currlyric !== "" ? playlistmanager.currlyric : qsTr("♪ 纯音乐，请欣赏")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontTitle
                font.bold: true
                color: root.fgStrong
            }

            // 点击歌词 → 切回黑胶
            MouseArea {
                anchors.fill: parent
                onClicked: root.lyricsMode = false
            }
        }
    }

    // ===== 下区：动作行 + 进度 + 五键 + 辅助行（贴底） =====
    Item {
        id: bottomBlock

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: MTheme.safeBottom + 12
        height: 220

        // ---- 动作行：收藏/评论 ----
        Item {
            id: actionRow

            width: parent.width
            height: 40
            anchors.top: parent.top

            // 红心状态（与桌面 Bottompage 同款通道）
            readonly property bool isFav: playlistmanager
                                          && playlistCollection
                                          && playlistmanager.currentSonghash !== ""
                                          && playlistCollection.favoriteHashes
                                          && playlistCollection.containsHash(playlistmanager.currentSonghash)

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // 收藏（红心点亮表示已收藏）
                Item {
                    width: MTheme.touchMin - 8
                    height: MTheme.touchMin - 8
                    anchors.verticalCenter: parent.verticalCenter

                    MIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: actionRow.isFav ? AppIcon.heartFill : AppIcon.heart
                        color: actionRow.isFav ? MTheme.accent : root.fgStrong
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!playlistmanager || !playlistCollection
                                    || playlistmanager.currentSonghash === "")
                                return
                            playlistCollection.addToFavorite(
                                        playlistmanager.currentTitle,
                                        playlistmanager.currentSonghash,
                                        playlistmanager.currentsingername)
                        }
                    }
                }
            }
        }

        // ---- 进度条 + 两侧时间 + 中下音质标 ----
        Item {
            width: parent.width
            height: 44
            anchors.top: actionRow.bottom

            Item {
                width: parent.width - 44
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    id: track

                    width: parent.width
                    height: 2
                    radius: 1
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -6
                    color: root.fgDim
                }
                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, playlistmanager.percent))
                    height: track.height
                    radius: track.radius
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -6
                    color: root.fgStrong
                }
                Rectangle {
                    width: 9
                    height: 9
                    radius: 4.5
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -6
                    x: track.width * Math.max(0, Math.min(1, playlistmanager.percent)) - width / 2
                    color: root.fgStrong
                    scale: seekMa.pressed ? 1.6 : 1
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                // 点击/拖动调进度（上下各扩 20px 热区）
                MouseArea {
                    id: seekMa

                    anchors.fill: parent
                    anchors.topMargin: -20
                    anchors.bottomMargin: -20
                    onPressed: (mouse) => root.seekTo(mouse.x / width)
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            root.seekTo(mouse.x / width)
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: track.bottom
                    anchors.topMargin: 6
                    text: playlistmanager.percentstr
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption - 1
                    color: root.fgMid
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: track.bottom
                    anchors.topMargin: 6
                    // 真实音质：0自动 / 1标准128 / 2高品320 / 3无损flac
                    text: playlistmanager.quality === 3 ? qsTr("无损音质")
                        : playlistmanager.quality === 2 ? qsTr("高品音质")
                        : playlistmanager.quality === 1 ? qsTr("标准音质")
                        : qsTr("自动音质")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption - 2
                    color: root.fgDim
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: track.bottom
                    anchors.topMargin: 6
                    text: playlistmanager.duration
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption - 1
                    color: root.fgMid
                }
            }
        }

        // ---- 五键控制：模式 / 上一首 / 播放(实心) / 下一首 / 列表 ----
        Item {
            width: parent.width
            height: 74
            anchors.top: parent.top
            anchors.topMargin: 84

            Row {
                anchors.centerIn: parent
                spacing: 24

                Item {
                    width: MTheme.touchMin
                    height: 72

                    MIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: playlistmanager.playMode === 1 ? AppIcon.playModeRepeatOne
                              : playlistmanager.playMode === 2 ? AppIcon.playModeShuffle
                              : AppIcon.playModeOrder
                        color: root.fgMid
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.cyclePlayMode()
                    }
                }

                Item {
                    width: MTheme.touchMin
                    height: 72

                    MIcon {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        source: AppIcon.skipBackFill
                        color: root.fgStrong
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playPrevious()
                    }
                }

                // 主播放键（参考网易云：唯一带磨砂大圆盘的按钮）
                Item {
                    width: 76
                    height: 76

                    GlassCircle { anchors.centerIn: parent; width: 76; height: 76 }

                    MIcon {
                        anchors.centerIn: parent
                        width: 42
                        height: 42
                        source: playlistmanager.isPaused ? AppIcon.playFill : AppIcon.pauseFill
                        color: root.fgStrong
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playstop()
                    }
                }

                Item {
                    width: MTheme.touchMin
                    height: 72

                    MIcon {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        source: AppIcon.skipForwardFill
                        color: root.fgStrong
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playNext()
                    }
                }

                Item {
                    width: MTheme.touchMin
                    height: 72

                    MIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: AppIcon.queue
                        color: root.fgMid
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/PlayingQueuePage.qml")
                    }
                }
            }
        }

        // ---- 底部辅助行（只保留可用的：一起听引导 / 歌词开关） ----
        Row {
            width: parent.width
            height: 44
            anchors.top: parent.top
            anchors.topMargin: 166

            Item { width: parent.width / 2; height: 44
                MIcon { anchors.centerIn: parent; width: 20; height: 20; source: AppIcon.addTogether; color: root.fgMid }
                MouseArea {
                    anchors.fill: parent
                    onClicked: MTheme.toast(qsTr("到「一起听」页加入房间，就能点播这首歌"))
                }
            }
            Item { width: parent.width / 2; height: 44
                MIcon { anchors.centerIn: parent; width: 20; height: 20; source: AppIcon.lyrics; color: root.fgMid }
                MouseArea { anchors.fill: parent; onClicked: root.lyricsMode = !root.lyricsMode }
            }
        }
    }
}
