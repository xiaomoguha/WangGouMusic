import QtQuick
import QtQuick.Effects
import "."
import "../Src/BasicConfig"

// 底部迷你播放条（网易云浅色风格）：悬浮胶囊浮条，不贴满屏宽。
// 封面为黑胶小碟：深色圆盘 + MultiEffect 圆形遮罩的专辑图（图片严格裁进圆形）。
// 点击胶囊任意空白处展开全屏播放页；播放/切歌按钮就地拦截不冒泡。
Item
{
    id: root

    signal openNowPlaying

    // 胶囊高 52 + 上下留白 5 = 62；MTheme.miniPlayerHeight 仍为 56（布局高度近似即可）
    height: 62
    visible: playlistmanager.currentSonghash !== ""
    clip: false

    // ===== 胶囊本体 =====
    Rectangle {
        id: pill

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: (parent.height - 10) / 2
        color: MTheme.bgCard
        border.width: 1
        border.color: MTheme.separator

        // 整条点击 → 展开播放页（声明在前，按钮自然盖在其上优先响应）
        MouseArea {
            anchors.fill: parent
            onClicked: root.openNowPlaying()
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: MTheme.safeLeft + 8
            anchors.rightMargin: MTheme.safeRight + 8

            // ===== 黑胶小碟封面（播放时旋转） =====
            Item {
                id: disc

                width: 42
                height: 42
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 8000
                    loops: Animation.Infinite
                    running: !playlistmanager.isPaused && playlistmanager.currentSonghash !== ""
                }

                // 深色盘体
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#1A1A1A"

                    // 细纹
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#2E2E2E"
                    }
                }

                // 圆形专辑图（MCover 遮罩：图片严格裁进圆内）
                Item {
                    id: coverArt

                    width: 30
                    height: 30
                    anchors.centerIn: parent

                    MCover {
                        anchors.fill: parent
                        radius: width / 2
                        source: playlistmanager.union_cover
                    }

                    // 无封面兜底
                    MIcon {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: playlistmanager.union_cover === ""
                        source: AppIcon.musicNotes
                        color: "#777777"
                    }
                }

                // 中心孔
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: "#0D0D0D"
                    border.width: 1
                    border.color: "#3A3A3A"
                    z: 2
                }

                // 点击封面也展开播放页（盖在 MouseArea 之上自然冒泡到胶囊点击亦可，这里显式处理）
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.openNowPlaying()
                }
            }

            // ===== 歌名/歌手 =====
            Column {
                anchors.left: disc.right
                anchors.leftMargin: 10
                anchors.right: controlsRow.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: playlistmanager.currentTitle
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    font.bold: true
                    color: MTheme.textPrimary
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: playlistmanager.currentsingername
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption
                    color: MTheme.textMuted
                    elide: Text.ElideRight
                }
            }

            // ===== 播放控制 =====
            Row {
                id: controlsRow

                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // 播放时间
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (playlistmanager ? playlistmanager.percentstr : "")
                          + "/" + (playlistmanager ? playlistmanager.duration : "")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption - 1
                    color: MTheme.textMuted
                }

                Item {
                    width: MTheme.touchMin - 4
                    height: MTheme.touchMin

                    MIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: AppIcon.skipBackFill
                        color: MTheme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playPrevious()
                    }
                }

                Item {
                    width: MTheme.touchMin - 4
                    height: MTheme.touchMin

                    MIcon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: playlistmanager.isPaused ? AppIcon.playCircle : AppIcon.pause
                        color: MTheme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playstop()
                    }
                }

                Item {
                    width: MTheme.touchMin - 4
                    height: MTheme.touchMin

                    MIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: AppIcon.skipForwardFill
                        color: MTheme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playNext()
                    }
                }

                Item {
                    width: MTheme.touchMin - 4
                    height: MTheme.touchMin

                    MIcon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: AppIcon.queue
                        color: MTheme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/PlayingQueuePage.qml")
                    }
                }
            }
        }
    }
}
