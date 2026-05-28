import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    objectName: "PlaylistDetailPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property string playlistId: BasicConfig.playlistDetailId
    property string playlistName: BasicConfig.playlistDetailName
    property string playlistCover: BasicConfig.playlistDetailCover
    property string playlistIntro: BasicConfig.playlistDetailIntro
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    Component.onCompleted: {
        if (recommendation && playlistId !== "")
            recommendation.fetchPlaylistTracks(playlistId)
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // 顶部：返回按钮 + 歌单信息
        Rectangle {
            width: parent.width
            height: 150
            color: "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 30
                anchors.topMargin: 10
                spacing: 15

                // 返回按钮
                Rectangle {
                    id: backBtn
                    width: 36
                    height: 36
                    radius: 18
                    color: backHover.hovered ? AppTheme.bgCard : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: backIcon
                        anchors.centerIn: parent
                        source: "qrc:/image/left_line.png"
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            source: backIcon
                            color: AppTheme.textPrimary
                        }
                    }

                    HoverHandler { id: backHover }
                    TapHandler {
                        cursorShape: Qt.PointingCursor
                        onTapped: BasicConfig.goBack()
                    }
                }

                Image {
                    id: coverImg
                    width: 110
                    height: 110
                    source: playlistCover
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize.width: 220
                    sourceSize.height: 220
                    fillMode: Image.PreserveAspectCrop
                    anchors.verticalCenter: parent.verticalCenter
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 110
                            height: 110
                            radius: 12
                        }
                    }
                }

                Column {
                    width: parent.width - coverImg.width - backBtn.width - 65
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: playlistName
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 20
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: "黑体"
                    }

                    Text {
                        text: playlistIntro
                        width: parent.width
                        height: 40
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        font.pixelSize: 12
                        color: AppTheme.textMuted
                        font.family: "黑体"
                    }

                    Row {
                        spacing: 12
                        visible: !isTogetherMode

                        Rectangle {
                            width: 100
                            height: 32
                            radius: 16
                            color: playAllHover.hovered ? "#533483" : "#e94560"

                            Text {
                                anchors.centerIn: parent
                                text: "▶ 播放全部"
                                font.pixelSize: 12
                                color: "#ffffff"
                                font.family: "黑体"
                                font.bold: true
                            }

                            HoverHandler { id: playAllHover }
                            TapHandler {
                                cursorShape: Qt.PointingCursor
                                onTapped: {
                                    var songs = recommendation ? recommendation.playlistTracksQml : []
                                    if (songs.length > 0) {
                                        playlistmanager.clearPlaylist()
                                        for (var i = 0; i < songs.length; i++) {
                                            var s = songs[i]
                                            playlistmanager.addSong(s.songname, s.songhash, s.singername, s.union_cover, s.album_name, s.duration)
                                        }
                                        playlistmanager.playSongbyindex(0)
                                        BasicConfig.emitSongAdded("正在播放: " + playlistName)
                                    }
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }

        // 分隔线
        Rectangle {
            width: parent.width - 60
            height: 1
            color: AppTheme.bgNavHover
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // 歌曲列表
    Flickable {
        id: flickable
        anchors.top: parent.top
        anchors.topMargin: 170
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        contentHeight: contentColumn.height

        ScrollBar.vertical: ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 5
            width: 10
            contentItem: Rectangle {
                visible: parent.active
                width: 10
                radius: 4
                color: AppTheme.scrollbarColor
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 2
            anchors.leftMargin: 30
            anchors.rightMargin: 30

            Repeater {
                model: recommendation ? recommendation.playlistTracksQml : []

                delegate: Rectangle {
                    width: contentColumn.width - 60
                    height: 55
                    x: 30
                    radius: 8
                    color: songHover.hovered ? AppTheme.bgCard : "transparent"

                    readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === modelData.songhash

                    Row {
                        id: mainRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Text {
                            width: 30
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 13
                            color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                            font.family: "黑体"
                            text: isPlaying ? "♪" : (index + 1)
                        }

                        Image {
                            width: 40
                            height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.union_cover
                            asynchronous: true
                            cache: true
                            sourceSize.width: 80
                            sourceSize.height: 80
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 6
                                }
                            }
                        }

                        Column {
                            width: parent.width - 260
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: modelData.songname
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: isPlaying ? AppTheme.accentPlaying : AppTheme.textPrimary
                                font.family: "黑体"
                            }

                            Text {
                                text: modelData.singername
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                color: AppTheme.textMuted
                                font.family: "黑体"
                            }
                        }

                        // 操作按钮
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            visible: songHover.hovered

                            // 普通模式：立即播放 + 下一首播放
                            Row {
                                visible: !isTogetherMode
                                spacing: 6

                                Rectangle {
                                    width: 66
                                    height: 26
                                    radius: 13
                                    color: playBtnHover.hovered ? "#533483" : "#e94560"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "立即播放"
                                        font.pixelSize: 10
                                        color: "#ffffff"
                                        font.family: "黑体"
                                    }

                                    HoverHandler { id: playBtnHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingCursor
                                        onTapped: {
                                            playlistmanager.addandplay(modelData.songname, modelData.songhash,
                                                                       modelData.singername, modelData.union_cover,
                                                                       modelData.album_name, modelData.duration)
                                            BasicConfig.emitSongAdded("正在播放: " + modelData.songname)
                                        }
                                    }
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Rectangle {
                                    width: 76
                                    height: 26
                                    radius: 13
                                    color: nextBtnHover.hovered ? AppTheme.bgNavHover : "transparent"
                                    border.color: AppTheme.textMuted
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "下一首播放"
                                        font.pixelSize: 10
                                        color: AppTheme.textPrimary
                                        font.family: "黑体"
                                    }

                                    HoverHandler { id: nextBtnHover }
                                    TapHandler {
                                        cursorShape: Qt.PointingCursor
                                        onTapped: {
                                            playlistmanager.addSongNext(modelData.songname, modelData.songhash,
                                                                        modelData.singername, modelData.union_cover,
                                                                        modelData.album_name, modelData.duration)
                                            BasicConfig.emitSongAdded("已添加到下一首: " + modelData.songname)
                                        }
                                    }
                                }
                            }

                            // 一起听模式：添加到一起听列表
                            Rectangle {
                                visible: isTogetherMode
                                width: 80
                                height: 26
                                radius: 13
                                color: togetherBtnHover.hovered ? "#533483" : "#e94560"

                                Text {
                                    anchors.centerIn: parent
                                    text: "添加到一起听"
                                    font.pixelSize: 10
                                    color: "#ffffff"
                                    font.family: "黑体"
                                }

                                HoverHandler { id: togetherBtnHover }
                                TapHandler {
                                    cursorShape: Qt.PointingCursor
                                    onTapped: {
                                        websocket.addSongToTogether(modelData.songname, modelData.songhash,
                                                                    modelData.singername, modelData.album_name,
                                                                    modelData.duration, modelData.union_cover)
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        Text {
                            id: durationText
                            text: modelData.duration
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 11
                            color: AppTheme.textMuted
                            font.family: "黑体"
                            visible: !songHover.hovered
                        }
                    }

                    HoverHandler { id: songHover }

                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            Item { width: 1; height: 20 }
        }
    }
}
