import QtQuick 2.15
import QtQuick.Controls
import "../BasicConfig"

Page {
    id: complexPage
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    background: Rectangle { color: "transparent" }

    Connections {
        target: BasicConfig
        function onSearchKeywordChange() {
            flick.contentY = 0;
            complexsearch.fetchComplexData(BasicConfig.searchKeyword);
        }
    }

    // ===== 加载骨架屏（首次搜索） =====
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: AppTheme.bgLoadingOverlay
        visible: complexsearch && complexsearch.isLoading && complexsearch.page === 1
        z: 9999

        Column {
            anchors.fill: parent
            anchors.topMargin: 30
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 10

            Repeater {
                model: 8
                delegate: Rectangle {
                    width: loadingOverlay.width - 40
                    height: 56
                    radius: 8
                    color: AppTheme.bgCard
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        Rectangle {
                            width: 40; height: 40; radius: 8
                            color: AppTheme.progressTrack
                        }
                        Column {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 100 + index * 18; height: 12; radius: 4
                                color: AppTheme.progressTrack
                            }
                            Rectangle {
                                width: 70 + index * 12; height: 10; radius: 4
                                color: AppTheme.progressTrack
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.4; color: "transparent" }
                            GradientStop { position: 0.5; color: AppTheme.isDark ? "#15FFFFFF" : "#10FF8A80" }
                            GradientStop { position: 0.6; color: "transparent" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        NumberAnimation on x {
                            from: -parent.width; to: parent.width
                            duration: 1500; loops: Animation.Infinite
                            running: loadingOverlay.visible
                        }
                    }
                }
            }
        }
    }

    // ===== 结果列表 =====
    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentHeight: listCol.height + bottomLoader.height + 20
        onContentYChanged: {
            if (!complexsearch || complexsearch.isLoading) return;
            if (!complexsearch.hasMore) return;
            if (contentY + height >= contentHeight - 200) {
                complexsearch.fetchMore();
            }
        }

        Column {
            id: listCol
            width: flick.width
            spacing: 2

            Repeater {
                model: complexsearch ? complexsearch.items : []

                delegate: Rectangle {
                    id: songItem
                    required property int index
                    required property var modelData
                    width: listCol.width
                    height: 56
                    radius: 8
                    color: itemHover.hovered ? AppTheme.bgCardHover : "transparent"

                    property bool showActions: itemHover.hovered

                    HoverHandler { id: itemHover }

                    // 入场动画
                    opacity: 0
                    Component.onCompleted: enterAnim.start()
                    NumberAnimation on opacity {
                        id: enterAnim
                        from: 0; to: 1
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                    // 左侧：序号 + 封面 + 歌名/歌手
                    Row {
                        x: 0.025 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            width: 28
                            text: (songItem.index + 1).toString().padStart(2, "0")
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: AppTheme.fontSizeBodyLg
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }

                        Rectangle {
                            width: 40; height: 40; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            color: AppTheme.bgCard

                            Image {
                                anchors.fill: parent
                                source: modelData.union_cover || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 80
                                sourceSize.height: 80
                            }
                        }

                        Column {
                            width: 0.2 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            // 歌名：超出列宽时连续向左滚动（贪吃蛇穿墙式：滚出左边从右边接上，间隔若干空格），
                            // 列宽即最大长度限制；不超出则静止显示一份。
                            Item {
                                id: songNameClip
                                width: parent.width
                                height: songNameText.implicitHeight
                                clip: true
                                property real gap: 28                                   // 重复之间的间隔（约几个空格）
                                property bool overflow: songNameText.implicitWidth > width
                                property real unitWidth: songNameText.implicitWidth + gap // 一个「文字+间隔」周期
                                Row {
                                    id: songNameRow
                                    spacing: songNameClip.gap
                                    Text {
                                        id: songNameText
                                        text: modelData.songname
                                        font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily
                                        color: AppTheme.textPrimary
                                    }
                                    // 第二份副本：仅超出时显示，配合 x 滚到 -unitWidth 实现无缝循环
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily
                                        color: AppTheme.textPrimary
                                        visible: songNameClip.overflow
                                    }
                                    NumberAnimation on x {
                                        running: songNameClip.overflow
                                        from: 0; to: -songNameClip.unitWidth
                                        duration: Math.max(3000, songNameClip.unitWidth * 20)
                                        loops: Animation.Infinite
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                            Text {
                                text: modelData.singername
                                font.pixelSize: AppTheme.fontSizeCaption; font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                                elide: Text.ElideRight; width: parent.width; wrapMode: Text.NoWrap
                            }
                        }
                    }

                    // 操作按钮（悬停显示，固定位置，不影响布局）
                    Row {
                        visible: songItem.showActions
                        x: 0.35 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        z: 1

                        // 播放
                        IconButton {
                            visible: !isTogetherMode
                            iconSource: "qrc:/image/playnow.png"
                            onClicked: {
                                playlistmanager.playNextAndPlay({
                                    "songname": modelData.songname,
                                    "songhash": modelData.songhash,
                                    "singername": modelData.singername,
                                    "union_cover": modelData.union_cover,
                                    "album_name": modelData.album_name,
                                    "duration": modelData.duration
                                });
                                BasicConfig.emitSongAdded("正在播放: " + modelData.songname);
                            }
                        }

                        // 添加到列表
                        IconButton {
                            visible: !isTogetherMode
                            iconSource: "qrc:/image/addplaylist.png"
                            onClicked: {
                                playlistmanager.addSong({
                                    "songname": modelData.songname,
                                    "songhash": modelData.songhash,
                                    "singername": modelData.singername,
                                    "union_cover": modelData.union_cover,
                                    "album_name": modelData.album_name,
                                    "duration": modelData.duration
                                });
                                BasicConfig.emitSongAdded();
                            }
                        }

                        // 一起听
                        IconButton {
                            id: togetherBtn
                            visible: (websocket && websocket.connected) || isTogetherMode
                            iconSource: "qrc:/image/yinle.png"
                            iconColor: AppTheme.isDark ? (togetherBtn.hovered ? AppTheme.accent : AppTheme.iconDefault) : AppTheme.accent
                            onClicked: websocket.addSongToTogether(modelData.songname, modelData.songhash, modelData.singername, modelData.album_name, modelData.duration, modelData.union_cover)
                        }

                    }

                    // 专辑（固定位置）
                    Text {
                        x: 0.48 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight; width: 0.28 * root.width; wrapMode: Text.NoWrap
                        text: modelData.album_name
                        font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; color: AppTheme.textMuted
                    }

                    // 时长（固定位置）
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 0.04 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var d = modelData.duration;
                            if (!d) return "--:--";
                            if (d.indexOf(":") !== -1) return d;
                            var sec = parseInt(d);
                            if (isNaN(sec)) return d;
                            var m = Math.floor(sec / 60);
                            var s = sec % 60;
                            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                        }
                        font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; color: AppTheme.textMuted
                    }
                }
            }
        }

        // ===== 底部加载指示器 =====
        Column {
            id: bottomLoader
            width: flick.width
            y: listCol.height + 10
            spacing: 8

            // 加载中旋转
            Row {
                visible: complexsearch && complexsearch.isLoading && complexsearch.page > 1
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: 2; border.color: AppTheme.accent
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: AppTheme.accent
                        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    }
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                        running: parent.parent.visible
                    }
                }

                Text {
                    text: "加载更多..."
                    font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily
                    color: AppTheme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 没有更多
            Text {
                visible: complexsearch && !complexsearch.hasMore && complexsearch.items.length > 0
                text: "— 没有更多了 —"
                font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily
                color: AppTheme.textDim
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ===== 无结果状态 =====
    Column {
        visible: complexsearch && !complexsearch.isLoading && complexsearch.items.length === 0 && BasicConfig.searchKeyword !== ""
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            width: 64; height: 64; radius: 32
            color: AppTheme.accentSubtle
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 28; color: AppTheme.accent
            }
        }
        Text {
            text: "没有找到相关歌曲"
            font.pixelSize: AppTheme.fontSizeBodyLg; font.family: AppTheme.fontFamily; color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "换个关键词试试吧"
            font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily; color: AppTheme.textDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
