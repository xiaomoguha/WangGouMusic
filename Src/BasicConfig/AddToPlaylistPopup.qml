import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects

// 添加到歌单弹窗：列出我的歌单，支持新建歌单并自动把当前歌曲加进去
ThemedPopup {
    id: root
    width: 360
    height: 440

    property var song: ({})
    property var playlists: []
    property bool pendingAutoAdd: false

    function refreshPlaylists() {
        var cached = userManager ? userManager.loadCachedPlaylists() : null
        var data = cached ? (cached.data || cached) : null
        playlists = (data && data.info) ? data.info.slice(0) : []
        if (userManager && userManager.isLoggedIn)
            userManager.fetchUserPlaylist(1, 50)
    }

    onOpened: {
        pendingAutoAdd = true
        newNameInput.text = ""
        refreshPlaylists()
    }

    Connections {
        target: userManager
        function onUserPlaylistReceived(data) {
            var d = data["data"] || data
            if (d && d.info)
                root.playlists = d.info.slice(0)
        }
    }

    Connections {
        target: playlistCollection
        function onPlaylistCreated(listid, name) {
            if (!root.visible)
                return
            // 从「添加到歌单」入口新建：创建成功后直接把当前歌曲加进去
            if (root.pendingAutoAdd && root.song && root.song.songhash) {
                root.pendingAutoAdd = false
                playlistCollection.addTracks(
                    listid, [root.song],
                    "已创建并添加: " + (root.song.songname || name), 0
                )
                root.close()
            }
        }
        function onOperationFinished(success, message) {
            if (!root.visible)
                return
            if (success) {
                root.refreshPlaylists()
                if (!root.pendingAutoAdd)
                    root.close()
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Row {
            width: parent.width
            spacing: 6

            Text {
                id: titleText
                text: "添加到歌单"
                font.pixelSize: AppTheme.fontSizeTitleLg
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                width: parent.width - titleText.implicitWidth - closeBtn.width - 12
                height: 1
            }
            IconButton {
                id: closeBtn
                iconSource: AppIcon.close
                iconColor: AppTheme.textMuted
                size: 26
                iconSize: 13
                tooltipText: "关闭"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.close()
            }
        }
        Text {
            text: root.song && root.song.songname ? ("\"" + root.song.songname + "\"") : ""
            width: parent.width
            elide: Text.ElideRight
            font.pixelSize: AppTheme.fontSizeSmall
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }

        // 新建歌单并添加
        Row {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width - 60
                height: 34
                radius: 8
                color: AppTheme.bgCard
                border.color: newNameInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault
                border.width: 1

                TextInput {
                    id: newNameInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    color: AppTheme.textPrimary
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                    selectByMouse: true
                }
            }

            Rectangle {
                width: 52
                height: 34
                radius: 8
                color: createHover.hovered ? AppTheme.accentHover : AppTheme.accent
                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "创建"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    color: "white"
                    font.family: AppTheme.fontFamily
                }
                HoverHandler { id: createHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    enabled: !(playlistCollection && playlistCollection.isWorking)
                    onTapped: {
                        var name = newNameInput.text.trim()
                        if (name === "") {
                            BasicConfig.noticeError("请输入歌单名")
                            return
                        }
                        root.pendingAutoAdd = true
                        playlistCollection.createPlaylist(name)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - 120
            radius: 8
            color: AppTheme.bgCard

            ListView {
                anchors.fill: parent
                clip: true
                model: root.playlists
                spacing: 2

                delegate: Rectangle {
                    width: parent.width
                    height: 42
                    radius: 6
                    color: itemHover.hovered ? AppTheme.bgNavHover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        RetryImage {
                            width: 26
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            coverSource: modelData.pic ? modelData.pic.replace("{size}", "80") : ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle { width: 26; height: 26; radius: 5 }
                            }
                        }
                        Text {
                            text: modelData.name || "未命名歌单"
                            width: parent.width - 26 - 10 - countText.implicitWidth - 10
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeSmall
                            color: AppTheme.textPrimary
                            font.family: AppTheme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: countText
                            text: modelData.count || 0
                            font.pixelSize: AppTheme.fontSizeCaption
                            color: AppTheme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: itemHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        enabled: !(playlistCollection && playlistCollection.isWorking)
                        onTapped: {
                            if (!root.song || !root.song.songhash)
                                return
                            playlistCollection.addTracks(
                                String(modelData.listid), [root.song],
                                "已添加到歌单: " + (root.song.songname || ""),
                                Number(modelData.type || 0)
                            )
                            root.close()
                        }
                    }
                }
            }

            Text {
                visible: root.playlists.length === 0
                anchors.centerIn: parent
                text: "暂无歌单，可先新建"
                color: AppTheme.textMuted
                font.pixelSize: AppTheme.fontSizeSmall
                font.family: AppTheme.fontFamily
            }
        }
    }
}
