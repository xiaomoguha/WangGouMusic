import QtQuick 2.15
import QtQuick.Controls 2.15

// 歌曲行内高潮试听按钮：小椭圆描边 + 文字，点击开始/结束试听
Item {
    id: root

    property string songHash: ""
    property string songTitle: ""
    property string songSinger: ""
    property string songCover: ""
    property bool rowHovered: false
    property bool compact: false  // 紧凑行（搜索页 24px 操作按钮）

    readonly property bool active: playlistmanager
                                    && playlistmanager.climaxPreviewing
                                    && String(playlistmanager.climaxPreviewHash).toLowerCase()
                                       === String(songHash).toLowerCase()

    visible: active || rowHovered
    width: 52
    height: compact ? 24 : 30

    Rectangle {
        id: pill
        width: parent.width
        height: 24
        anchors.centerIn: parent
        radius: height / 2
        color: root.active ? "#26FF6B6B"
                            : (hoverHandler.hovered ? "#1FFFFFFF" : "transparent")
        border.width: 1
        border.color: root.active ? AppTheme.accent
                                  : (hoverHandler.hovered ? AppTheme.accent : "#55FFFFFF")

        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }

        Text {
            anchors.centerIn: parent
            text: root.active ? "结束试听" : "试听"
            font.pixelSize: 11
            font.family: AppTheme.fontFamily
            color: root.active ? "#FFFFFF"
                               : (hoverHandler.hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }
    }

    HoverHandler { id: hoverHandler }

    ToolTip {
        id: previewTip
        parent: root
        visible: hoverHandler.hovered
        delay: 700
        text: root.active ? "结束高潮试听，回到之前的播放" : "试听这首歌的高潮片段"
        padding: 6
        x: (root.width - implicitWidth) / 2
        y: root.height + 4
        background: Rectangle {
            color: "#F21E1E2A"
            radius: 4
            border.width: 1
            border.color: "#33FFFFFF"
        }
        contentItem: Text {
            text: previewTip.text
            color: "#FFFFFF"
            font.pixelSize: 10
            font.family: AppTheme.fontFamily
        }
    }

    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: {
            if (playlistmanager && root.songHash)
                playlistmanager.toggleClimaxPreview(
                    root.songHash, root.songTitle, root.songSinger, root.songCover
                )
        }
    }
}
