import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// 歌单发现：酷狗歌单馆（分类标签 + 按分类的歌单列表，下拉翻页）
// 数据源 DiscoverManager：/playlist/tags 分类树 + /top/playlist?category_id= 歌单列表
Item {
    id: root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "DiscoverPage"

    // 分类 chips 模型（{tag_id, tag_name}）
    ListModel { id: tagModel }
    // 歌单缓冲模型：playlistsReset/playlistsAppended 增量填充，避免整体替换导致滚动弹跳
    ListModel { id: playlistModel }

    property string currentTagId: ""

    Connections {
        target: discoverManager
        function onTagsChanged() {
            tagModel.clear()
            var tags = discoverManager.tagsQml
            for (var i = 0; i < tags.length; i++) {
                var t = tags[i]
                tagModel.append({ "tag_id": t.tag_id, "tag_name": t.tag_name })
            }
        }
        function onPlaylistsReset(songs) {
            playlistModel.clear()
            for (var i = 0; i < songs.length; i++)
                playlistModel.append(songs[i])
        }
        function onPlaylistsAppended(songs) {
            for (var i = 0; i < songs.length; i++)
                playlistModel.append(songs[i])
        }
    }

    Component.onCompleted: {
        if (discoverManager) {
            discoverManager.fetchTags()
            discoverManager.fetchPlaylists("")
        }
    }

    // ===== 顶部标题 =====
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.leftMargin: 0.025 * root.width
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 12

        Text {
            text: "歌单发现"
            font.pixelSize: 22
            font.bold: true
            color: AppTheme.textPrimary
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "发现好歌单"
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ===== 分类标签（横向滚动） =====
    Row {
        id: tagRow
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.top: headerRow.bottom
        anchors.topMargin: 14
        spacing: 8
        clip: true

        // 全部（默认选中）
        Rectangle {
            id: allTag
            width: allTagText.width + 24
            height: 30
            radius: 15
            color: currentTagId === "" ? AppTheme.accent : (allTagHover.hovered ? AppTheme.iconButtonHover : "transparent")
            Text {
                id: allTagText
                anchors.centerIn: parent
                text: "全部"
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
                font.bold: true
                color: currentTagId === "" ? AppTheme.textPrimary : AppTheme.textSecondary
            }
            HoverHandler { id: allTagHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (currentTagId === "") return
                    currentTagId = ""
                    discoverManager.fetchPlaylists("")
                }
            }
        }

        Repeater {
            model: tagModel
            Rectangle {
                width: tagText.width + 24
                height: 30
                radius: 15
                color: currentTagId === model.tag_id ? AppTheme.accent : (tagChipHover.hovered ? AppTheme.iconButtonHover : "transparent")

                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: model.tag_name
                    font.pixelSize: AppTheme.fontSizeBody
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: currentTagId === model.tag_id ? AppTheme.textPrimary : AppTheme.textSecondary
                }
                HoverHandler { id: tagChipHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (currentTagId === model.tag_id) return
                        currentTagId = model.tag_id
                        // 分类取歌单按分类名搜索（服务端 /playlist/category）
                        discoverManager.fetchPlaylists(model.tag_name)
                    }
                }
            }
        }
    }

    // ===== 歌单网格（下拉翻页） =====
    GridView {
        id: playlistGrid
        anchors.top: tagRow.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30
        anchors.rightMargin: 30
        clip: true
        cellWidth: (playlistGrid.width - 20) / 2
        cellHeight: 118
        model: playlistModel
        cacheBuffer: 400

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

        // 下拉到底加载更多
        onContentYChanged: {
            if (discoverManager && !discoverManager.isLoading && discoverManager.hasMore
                && contentHeight > height && contentY >= contentHeight - height - 200) {
                discoverManager.fetchMorePlaylists()
            }
        }

        // 底部加载动画
        footer: Item {
            width: playlistGrid.width
            height: discoverManager && discoverManager.hasMore ? 44 : 0
            visible: discoverManager && discoverManager.hasMore
            Row {
                anchors.centerIn: parent
                spacing: 8
                Image {
                    id: moreSpinner
                    source: AppIcon.refresh
                    sourceSize: Qt.size(48, 48)
                    width: 14; height: 14
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    visible: discoverManager && discoverManager.isLoading
                    layer.enabled: true
                    layer.effect: ColorOverlay { source: moreSpinner; color: AppTheme.textMuted }
                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                        running: moreSpinner.visible
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (discoverManager && discoverManager.isLoading) ? "加载中..." : "上拉加载更多"
                    color: AppTheme.textMuted
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
            }
        }

        // 首屏加载中（切分类）：居中文字提示，不遮罩
        Text {
            anchors.centerIn: parent
            visible: discoverManager && discoverManager.isLoading && playlistModel.count === 0
            text: "正在加载..."
            font.pixelSize: AppTheme.fontSizeBody
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
        }

        // 空状态
        Column {
            visible: playlistModel.count === 0 && (!discoverManager || !discoverManager.isLoading)
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: AppTheme.accentSubtle
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 28
                    color: AppTheme.accent
                }
            }
            Text {
                text: "这个分类还没有歌单"
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.bold: true
                color: AppTheme.textPrimary
                font.family: AppTheme.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        delegate: Item {
            width: playlistGrid.cellWidth - 10
            height: playlistGrid.cellHeight - 10

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 12

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 12

                    RetryImage {
                        id: plCover
                        width: 88
                        height: 88
                        coverSource: model.imgurl
                        sourceSize.width: 176
                        sourceSize.height: 176
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 88; height: 88; radius: 8 }
                        }
                    }

                    Column {
                        width: parent.width - plCover.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            text: model.specialname
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeBody
                            font.bold: true
                            color: plHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                            font.family: AppTheme.fontFamily
                        }
                        Text {
                            text: model.intro
                            width: parent.width
                            height: 32
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            font.pixelSize: AppTheme.fontSizeCaption
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }
                        Text {
                            text: model.nickname ? (model.nickname + " · ") : "" + (model.play_count / 10000).toFixed(1) + "万播放"
                            font.pixelSize: AppTheme.fontSizeXs
                            color: AppTheme.textMuted
                            font.family: AppTheme.fontFamily
                        }
                    }
                }

                HoverHandler { id: plHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        BasicConfig.openPlaylistDetail(
                            model.global_collection_id,
                            model.specialname,
                            model.imgurl,
                            model.intro
                        )
                    }
                }
            }
        }
    }
}
