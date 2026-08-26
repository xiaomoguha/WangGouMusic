import QtQuick 2.15
import QtQuick.Controls
import "../BasicConfig"
import "../ToolWindow"

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
        // 沉浸：背景透明露出整窗渐变，骨架条用半透明白在任意渐变上都清晰
        color: "transparent"
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
                    // 半透明白：任何渐变下都隐约可见又不显块状
                    color: "#12FFFFFF"
                    clip: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        Rectangle {
                            width: 40; height: 40; radius: 8
                            color: "#1EFFFFFF"
                        }
                        Column {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 100 + index * 18; height: 12; radius: 4
                                color: "#1EFFFFFF"
                            }
                            Rectangle {
                                width: 70 + index * 12; height: 10; radius: 4
                                color: "#1EFFFFFF"
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

    // ===== 结果列表（ListView 虚拟化：只创建可见 delegate，滚动时回收，
    // 避免长结果列表全量实例化导致堆随结果数线性增长）=====
    ListView {
        id: flick
        anchors.fill: parent
        clip: true
        spacing: 2
        model: complexsearch

        // 接近底部自动加载更多（原 Flickable.onContentYChanged 逻辑平移）
        onContentYChanged: {
            if (!complexsearch || complexsearch.isLoading) return;
            if (!complexsearch.hasMore) return;
            if (contentY + height >= contentHeight - 200) {
                complexsearch.fetchMore();
            }
        }

        delegate: Rectangle {
            id: songItem
            width: flick.width
            height: 56 + aiExpand.expandedHeight
            radius: 8
            // hover 改为歌曲名高亮（背景透明，渐变下无块状覆盖层）
            color: "transparent"

            property bool showActions: itemHover.hovered

            // 当前播放行（hash 相等）：序号换成动态图 + 歌名高亮
            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === model.songhash

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

            // 行内容固定在 56 高，下方让位给 AI 展开
            Item {
                width: parent.width
                height: 56

            // 左侧：序号 + 封面 + 歌名/歌手
            Row {
                x: 0.025 * root.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    width: 28
                    text: (index + 1).toString().padStart(2, "0")
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                    visible: !songItem.isPlaying
                }

                NowPlayingIndicator {
                    width: 20
                    height: 20
                    visible: songItem.isPlaying
                    playing: playlistmanager ? !playlistmanager.isPaused : true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 40; height: 40; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    color: AppTheme.bgCard

                    RetryImage {
                        anchors.fill: parent
                        coverSource: model.union_cover || ""
                        fillMode: Image.PreserveAspectCrop
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
                                text: model.songname
                                font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily
                                font.bold: true
                                // 当前播放行 / hover 歌曲名高亮（网易云风格）
                                color: (songItem.isPlaying || itemHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                            }
                            // 第二份副本：仅超出时显示，配合 x 滚到 -unitWidth 实现无缝循环
                            Text {
                                text: model.songname
                                font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily
                                font.bold: true
                                color: (songItem.isPlaying || itemHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
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
                        text: model.singername
                        font.pixelSize: AppTheme.fontSizeCaption; font.family: AppTheme.fontFamily
                        font.bold: true
                        color: songItem.isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                        elide: Text.ElideRight; width: parent.width; wrapMode: Text.NoWrap
                    }
                }
            }

            // 操作按钮（悬停显示，固定位置，不影响布局）
            Row {
                visible: songItem.showActions
                x: 0.33 * root.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                z: 1

                // 播放
                IconButton {
                    visible: !isTogetherMode
                    iconSource: AppIcon.playCircle
                    size: 30
                    iconSize: 16
                    onClicked: {
                        playlistmanager.playNextAndPlay({
                            "songname": model.songname,
                            "songhash": model.songhash,
                            "singername": model.singername,
                            "union_cover": model.union_cover,
                            "album_name": model.album_name,
                            "duration": model.duration
                        });
                        BasicConfig.emitSongAdded("正在播放: " + model.songname);
                    }
                }

                // MV 播放（仅含 MV 的歌曲显示；点击弹独立视频窗口）
                // 注意传 mvhash（MV 专用 hash），不是 songhash——音频 hash 在 /video/url 会 502
                IconButton {
                    visible: !isTogetherMode && model.mvhash !== ""
                    iconSource: AppIcon.video
                    iconColor: AppTheme.textSecondary
                    size: 30
                    iconSize: 16
                    onClicked: {
                        BasicConfig.requestMvPlay({ mvhash: model.mvhash, title: model.songname,
                                                    singername: model.singername, songhash: model.songhash,
                                                    cover: model.union_cover })
                    }
                }

                // AI 推荐（点击展开/收回生成的 AI 歌单；有数据时切换为箭头）
                IconButton {

                    iconSource: aiExpand.expanded ? AppIcon.caretDown

                        : (aiExpand.aiSongs.length > 0 ? AppIcon.caretRight : AppIcon.sparkle)
                    size: 30
                    iconSize: 16
                    onClicked: {
                        aiExpand.toggle(model.songhash, model.songname)
                    }
                }

                // 添加到下一首播放（已有则移动到下一首）
                IconButton {
                    visible: !isTogetherMode
                    iconSource: AppIcon.addToList
                    size: 30
                    iconSize: 16
                    onClicked: {
                        playlistmanager.addSongNext({
                            "songname": model.songname,
                            "songhash": model.songhash,
                            "singername": model.singername,
                            "union_cover": model.union_cover,
                            "album_name": model.album_name,
                            "duration": model.duration
                        });
                        BasicConfig.emitSongAdded("已添加到下一首: " + model.songname);
                    }
                }

                // 一起听
                IconButton {
                    id: togetherBtn
                    visible: (websocket && websocket.connected) || isTogetherMode
                    iconSource: AppIcon.addTogether
                    size: 30
                    iconSize: 16
                    iconColor: AppTheme.isDark ? (togetherBtn.hovered ? AppTheme.accent : AppTheme.iconDefault) : AppTheme.iconDefault
                    onClicked: websocket.addSongToTogether(model.songname, model.songhash, model.singername, model.album_name, model.duration, model.union_cover)
                }

            }

            // 专辑（固定位置）
            Text {
                x: 0.48 * root.width
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight; width: 0.28 * root.width; wrapMode: Text.NoWrap
                text: model.album_name
                font.pixelSize: AppTheme.fontSizeBody; font.family: AppTheme.fontFamily; color: AppTheme.textMuted
                font.bold: true
            }

            // 时长（固定位置）
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 0.04 * root.width
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var d = model.duration;
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

            // AI 推荐展开（点 ✨ 后在行下方撑开几小行）
            AiRecommendExpand {
                id: aiExpand
                anchors.top: parent.top
                anchors.topMargin: 56
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 44
                anchors.rightMargin: 14
            }
        }

        // ===== 底部加载指示器（作为 footer，随列表滚动）=====
        footer: Column {
            width: flick.width
            spacing: 8

            // 顶部留白
            Item { width: 1; height: 10 }

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
                visible: complexsearch && !complexsearch.hasMore && complexsearch.count > 0
                text: "— 没有更多了 —"
                font.pixelSize: AppTheme.fontSizeSmall; font.family: AppTheme.fontFamily
                color: AppTheme.textDim
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ===== 无结果状态 =====
    Column {
        visible: complexsearch && !complexsearch.isLoading && complexsearch.count === 0 && BasicConfig.searchKeyword !== ""
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
