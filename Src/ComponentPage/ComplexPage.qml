import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Page {
    id: complexPage
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1
    background: Rectangle { color: "transparent" }

    Connections {
        target: BasicConfig
        function onSearchKeywordchange() {
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

                        // 序号
                        Text {
                            width: 28
                            text: songItem.index + 1 <= 9 ? "0" + String(songItem.index + 1) : songItem.index + 1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            color: AppTheme.textMuted
                            font.family: "黑体"
                        }

                        // 封面
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

                        // 歌名 + 歌手
                        Column {
                            width: 0.2 * root.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: modelData.songname
                                font.pixelSize: 13; font.family: "黑体"
                                color: AppTheme.textPrimary
                                elide: Text.ElideRight; width: parent.width; wrapMode: Text.NoWrap
                            }
                            Text {
                                text: modelData.singername
                                font.pixelSize: 11; font.family: "黑体"
                                color: AppTheme.textMuted
                                elide: Text.ElideRight; width: parent.width; wrapMode: Text.NoWrap
                            }
                        }
                    }

                    // 操作按钮（悬停显示，固定位置，不影响布局）
                    Row {
                        visible: songItem.showActions
                        x: 0.28 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        z: 1

                        // 播放
                        Rectangle {
                            visible: !isTogetherMode
                            width: 28; height: 28; radius: 14
                            color: AppTheme.isDark
                                   ? (playH.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (playH.hovered ? "#FFCCCC" : "#FFD8D8")
                            Image {
                                id: playIco
                                anchors.centerIn: parent
                                source: "qrc:/image/playnow.png"
                                width: 12; height: 12; fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay { source: playIco; color: AppTheme.isDark ? AppTheme.iconDefault : AppTheme.accent }
                            }
                            HoverHandler { id: playH }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    playlistmanager.addandplay(modelData.songname, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                    BasicConfig.emitSongAdded("正在播放: " + modelData.songname);
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // 添加到列表
                        Rectangle {
                            visible: !isTogetherMode
                            width: 28; height: 28; radius: 14
                            color: AppTheme.isDark
                                   ? (addH.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (addH.hovered ? "#FFCCCC" : "#FFD8D8")
                            Image {
                                id: addIco
                                anchors.centerIn: parent
                                source: "qrc:/image/addplaylist.png"
                                width: 12; height: 12; fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay { source: addIco; color: AppTheme.isDark ? AppTheme.iconDefault : AppTheme.accent }
                            }
                            HoverHandler { id: addH }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    playlistmanager.addSong(modelData.songname, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                    BasicConfig.emitSongAdded();
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // 一起听
                        Rectangle {
                            visible: (websocket && websocket.connected) || isTogetherMode
                            width: 28; height: 28; radius: 14
                            color: AppTheme.isDark
                                   ? (togetherH.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (togetherH.hovered ? "#FFCCCC" : "#FFD8D8")
                            Image {
                                id: togetherIco
                                anchors.centerIn: parent
                                source: "qrc:/image/yinle.png"
                                width: 12; height: 12; fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: togetherIco
                                    color: AppTheme.isDark ? (togetherH.hovered ? AppTheme.accent : AppTheme.iconDefault) : AppTheme.accent
                                }
                            }
                            HoverHandler { id: togetherH }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    websocket.addSongToTogether(modelData.songname, modelData.songhash, modelData.singername, modelData.album_name, modelData.duration, modelData.union_cover);
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // 喜欢
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: AppTheme.isDark
                                   ? (loveH.hovered ? AppTheme.iconButtonHover : "transparent")
                                   : (loveH.hovered ? "#FFCCCC" : "#FFD8D8")
                            Image {
                                id: loveIco
                                anchors.centerIn: parent
                                source: "qrc:/image/addlove.png"
                                width: 12; height: 12; fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: loveIco
                                    color: AppTheme.isDark ? (loveH.hovered ? AppTheme.accent : AppTheme.iconDefault) : AppTheme.accent
                                }
                            }
                            HoverHandler { id: loveH }
                            TapHandler { cursorShape: Qt.PointingHandCursor }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    // 专辑（固定位置）
                    Text {
                        x: 0.48 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight; width: 0.28 * root.width; wrapMode: Text.NoWrap
                        text: modelData.album_name
                        font.pixelSize: 13; font.family: "黑体"; color: AppTheme.textMuted
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
                        font.pixelSize: 13; font.family: "黑体"; color: AppTheme.textMuted
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
                    font.pixelSize: 12; font.family: "黑体"
                    color: AppTheme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 没有更多
            Text {
                visible: complexsearch && !complexsearch.hasMore && complexsearch.items.length > 0
                text: "— 没有更多了 —"
                font.pixelSize: 12; font.family: "黑体"
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
            color: AppTheme.isDark ? AppTheme.accentDim : "#10FF8A80"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 28; color: AppTheme.accent
            }
        }
        Text {
            text: "没有找到相关歌曲"
            font.pixelSize: 14; font.family: "黑体"; color: AppTheme.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "换个关键词试试吧"
            font.pixelSize: 12; font.family: "黑体"; color: AppTheme.textDim
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
