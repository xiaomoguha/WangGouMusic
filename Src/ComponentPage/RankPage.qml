import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

// 排行榜页：榜单列表（GridView）→ 点击进榜单详情（歌曲列表），页内两级切换。
// 数据源 RankList（/api/rank/list + rank/info + rank/audio）。
Item {
    id: root
    objectName: "RankPage"
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

    // 页内状态：false=榜单列表，true=当前榜单歌曲
    property bool showSongs: false
    property string lastRankId: ""

    // 榜单歌曲加载失败后的重试入口
    function retryCurrentRank() {
        if (lastRankId !== "")
            rankList.fetchRankSongs(lastRankId)
    }

    Component.onCompleted: {
        if (rankList.ranks.length === 0 && !rankList.isLoading)
            rankList.fetchRanks()
    }

    function openRank(rankid) {
        if (rankList.isLoading) return
        root.lastRankId = rankid
        contentFlick.contentY = 0
        songsList.contentY = 0
        rankList.fetchRankSongs(rankid)
        root.showSongs = true
    }

    function backToRanks() {
        contentFlick.contentY = 0
        root.showSongs = false
    }

    // 播放全部（榜单歌曲入队播放）
    function playAll() {
        var songs = rankList.songs
        if (songs.length === 0) return
        playlistmanager.clearPlaylist()
        for (var i = 0; i < songs.length; i++) {
            var s = songs[i]
            playlistmanager.addSong({
                "songname": s.songname,
                "songhash": s.songhash,
                "singername": s.singername,
                "union_cover": s.union_cover,
                "album_name": s.album_name,
                "duration": s.duration
            })
        }
        playlistmanager.playSongbyindex(0)
        BasicConfig.emitSongAdded("正在播放: " + rankList.rankName)
    }

    Flickable {
        id: contentFlick
        anchors.fill: parent
        clip: true
        contentHeight: contentColumn.height
        contentWidth: width

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
            spacing: 20
            leftPadding: width * 0.04
            rightPadding: width * 0.04

            Item { width: 1; height: 5 }

            // ========== 榜单列表视图 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 14
                visible: !root.showSongs

                Text {
                    text: "🔥 排行榜"
                    font.pixelSize: AppTheme.fontSizeHeadline
                    font.bold: true
                    color: AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }

                GridView {
                    id: ranksGrid
                    width: parent.width
                    height: contentHeight
                    cellWidth: width / 2
                    cellHeight: 108
                    interactive: false
                    model: rankList ? rankList.ranks : []

                    delegate: Item {
                        width: ranksGrid.cellWidth - 10
                        height: ranksGrid.cellHeight - 10

                        property var rankData: modelData

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: 12

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 10

                                RetryImage {
                                    id: rankCoverImg
                                    width: 88
                                    height: 88
                                    coverSource: rankData.imgurl
                                    sourceSize.width: 200
                                    sourceSize.height: 200
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle { width: 88; height: 88; radius: 10 }
                                    }
                                }

                                Text {
                                    width: parent.width - rankCoverImg.width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: rankData.rankname
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    font.pixelSize: AppTheme.fontSizeBody
                                    font.bold: true
                                    color: rankHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                                    font.family: AppTheme.fontFamily
                                }
                            }

                            HoverHandler { id: rankHover }
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: root.openRank(rankData.rankid)
                            }
                        }
                    }
                }

                // 榜单列表空状态
                EmptyState {
                    visible: !root.showSongs && rankList && rankList.ranks.length === 0
                    width: parent.width
                    height: 200
                    iconText: "🔥"
                    title: rankList && rankList.isLoading ? "正在加载排行榜..." : "排行榜加载失败"
                    subtitle: rankList && rankList.isLoading ? "" : "点击重试"
                    buttonText: rankList && rankList.isLoading ? "" : "重新加载"
                    onButtonClicked: rankList.fetchRanks()
                }
            }

            // ========== 榜单歌曲视图 ==========
            Column {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 14
                visible: root.showSongs

                // 返回榜单
                Rectangle {
                    width: 86
                    height: 30
                    radius: 15
                    color: backHover.hovered ? AppTheme.bgCardHover : AppTheme.bgCard
                    border.color: AppTheme.borderDefault
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "← 返回榜单"
                        font.pixelSize: AppTheme.fontSizeSmall
                        font.bold: true
                        color: AppTheme.textPrimary
                        font.family: AppTheme.fontFamily
                    }
                    HoverHandler { id: backHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: root.backToRanks()
                    }
                }

                // 榜单头部：封面 + 名称 + 播放全部
                Row {
                    width: parent.width
                    spacing: 16

                    Rectangle {
                        width: 96
                        height: 96
                        radius: 12
                        clip: true
                        color: AppTheme.bgCard

                        RetryImage {
                            anchors.fill: parent
                            coverSource: rankList.rankCover
                            sourceSize.width: 200
                            sourceSize.height: 200
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: 240
                            text: rankList.rankName || "排行榜"
                            elide: Text.ElideRight
                            font.pixelSize: AppTheme.fontSizeHeadline
                            font.bold: true
                            color: AppTheme.textPrimary
                            font.family: AppTheme.fontFamily
                        }

                        Row {
                            spacing: 12
                            visible: !isTogetherMode

                            Rectangle {
                                width: 100
                                height: 32
                                radius: 16
                                color: playAllHover.hovered ? "#533483" : "#e94560"
                                Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: (rankList && rankList.isLoading && rankList.songs.length === 0)
                                          ? "加载中..." : "▶ 播放全部"
                                    font.pixelSize: AppTheme.fontSizeSmall
                                    font.bold: true
                                    color: "#ffffff"
                                    font.family: AppTheme.fontFamily
                                }
                                HoverHandler { id: playAllHover }
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: rankList && !rankList.isLoading && rankList.songs.length > 0
                                    onTapped: root.playAll()
                                }
                            }
                        }
                    }
                }

                // 榜单歌曲列表:固定可用高度、自身滚动,恢复虚拟化。
                // 原先 height:contentHeight + interactive:false 嵌在外层
                // Flickable 里,视口=全部内容,100 首歌的 delegate(约 7000 个
                // QML 对象)在数据到达那一帧全部同步创建 —— 点进榜单详情整页
                // 冻住的根因。y 是列表顶部在页面中的位置,高度填满剩余空间,
                // 外层 Flickable 因此不再有可滚内容
                ListView {
                    id: songsList
                    width: parent.width
                    height: root.height - y - 40
                    clip: true
                    interactive: true
                    reuseItems: true
                    cacheBuffer: 320
                    model: rankList ? rankList.songs : []
                    spacing: 2

                    // 滚动时短暂出现的滚动条(不可滚动时彻底隐藏)
                    ScrollBar.vertical: ScrollBar {
                        id: rankScrollBar
                        policy: ScrollBar.AsNeeded
                        visible: size < 1.0
                        implicitWidth: 8
                        opacity: 0
                        contentItem: Rectangle {
                            width: 6
                            radius: 3
                            color: AppTheme.scrollbarColor
                        }
                        background: null
                        onActiveChanged: active ? opacity = 0.9 : hideBar.restart()
                        Timer {
                            id: hideBar
                            interval: 800
                            onTriggered: if (!rankScrollBar.active) rankScrollBar.opacity = 0
                        }
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    delegate: Rectangle {
                        width: songsList.width
                        height: 60
                        radius: 6
                        color: "transparent"

                        readonly property var songData: modelData
                        readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 15

                            Text {
                                width: 25
                                text: (index + 1).toString().padStart(2, "0")
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: AppTheme.fontSizeTitle
                                color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                                font.family: AppTheme.fontFamily
                                visible: !isPlaying
                            }

                            NowPlayingIndicator {
                                visible: isPlaying
                                playing: playlistmanager ? !playlistmanager.isPaused : true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 圆角矩形裁剪替代 layer+OpacityMask(省掉每行一个
                            // shader/FBO);sourceSize 限制解码尺寸 —— 源图是
                            // 400×400 变体,不设则 100 张全尺寸解码约 64MB 显存
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 6
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                RetryImage {
                                    anchors.fill: parent
                                    coverSource: songData.union_cover
                                    sourceSize.width: 80
                                    sourceSize.height: 80
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            Column {
                                width: 0.3 * songsList.width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: songData.songname
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeBody
                                    font.bold: true
                                    color: (isPlaying || songHover.hovered) ? AppTheme.accentPlaying : AppTheme.textSongTitle
                                    font.family: AppTheme.fontFamily
                                }
                                Text {
                                    text: songData.singername
                                    width: parent.width
                                    elide: Text.ElideRight
                                    font.pixelSize: AppTheme.fontSizeCaption
                                    font.bold: true
                                    color: isPlaying ? AppTheme.accentPlaying : AppTheme.textMuted
                                    font.family: AppTheme.fontFamily
                                }
                            }

                            // 操作按钮区（固定占位，悬停时显示；一起听模式只留「加入一起听」）
                            Item {
                                id: actionArea
                                width: isTogetherMode ? 34 : 108
                                height: 30
                                anchors.verticalCenter: parent.verticalCenter
                                HoverHandler { id: actionHover }

                                Row {
                                    anchors.fill: parent
                                    spacing: 4
                                    visible: songHover.hovered && !isPlaying

                                    IconButton {
                                        visible: !isTogetherMode
                                        iconSource: AppIcon.playCircle
                                        size: 30
                                        iconSize: 16
                                        onClicked: {
                                            playlistmanager.playNextAndPlay({
                                                "songname": songData.songname,
                                                "songhash": songData.songhash,
                                                "singername": songData.singername,
                                                "union_cover": songData.union_cover,
                                                "album_name": songData.album_name,
                                                "duration": songData.duration
                                            })
                                            BasicConfig.emitSongAdded("正在播放: " + songData.songname)
                                        }
                                    }

                                    IconButton {
                                        visible: !isTogetherMode
                                        iconSource: AppIcon.addToList
                                        size: 30
                                        iconSize: 16
                                        onClicked: {
                                            playlistmanager.addSongNext({
                                                "songname": songData.songname,
                                                "songhash": songData.songhash,
                                                "singername": songData.singername,
                                                "union_cover": songData.union_cover,
                                                "album_name": songData.album_name,
                                                "duration": songData.duration
                                            })
                                            BasicConfig.emitSongAdded("已添加到下一首: " + songData.songname)
                                        }
                                    }

                                    // 收藏到「我喜欢」
                                    IconButton {
                                        visible: !isTogetherMode
                                        iconSource: AppIcon.heart
                                        iconColor: AppTheme.textSecondary
                                        size: 30
                                        iconSize: 16
                                        onClicked: {
                                            if (!userManager || !userManager.isLoggedIn) {
                                                BasicConfig.noticeError("请先登录")
                                                return
                                            }
                                            playlistCollection.addToFavorite(songData.songname, songData.songhash, songData.singername)
                                        }
                                    }

                                    // 加入一起听
                                    IconButton {
                                        visible: isTogetherMode
                                        iconSource: AppIcon.addTogether
                                        size: 30
                                        iconSize: 16
                                        onClicked: websocket.addSongToTogether(songData.songname, songData.songhash,
                                                                               songData.singername, songData.album_name,
                                                                               songData.duration, songData.union_cover)
                                    }
                                }
                            }

                            // 专辑名（与歌单详情一致的列）
                            Text {
                                text: songData.album_name
                                width: 0.2 * songsList.width
                                elide: Text.ElideRight
                                font.pixelSize: AppTheme.fontSizeBodyLg
                                font.family: AppTheme.fontFamily
                                font.bold: true
                                color: AppTheme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: songData.duration || "--:--"
                                font.pixelSize: AppTheme.fontSizeBodyLg
                                font.family: AppTheme.fontFamily
                                color: AppTheme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: songHover }
                        // 整行点击 = 播放该曲（一起听模式 = 加入一起听）；
                        // 悬停在操作按钮区时不触发，避免与按钮点击重复
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (actionHover.hovered) return
                                if (isTogetherMode) {
                                    if (websocket) {
                                        websocket.addSongToTogether(songData.songname, songData.songhash,
                                            songData.singername, songData.album_name,
                                            songData.duration, songData.union_cover)
                                    }
                                } else {
                                    playlistmanager.playNextAndPlay({
                                        "songname": songData.songname,
                                        "songhash": songData.songhash,
                                        "singername": songData.singername,
                                        "union_cover": songData.union_cover,
                                        "album_name": songData.album_name,
                                        "duration": songData.duration
                                    })
                                    BasicConfig.emitSongAdded("正在播放: " + songData.songname)
                                }
                            }
                        }
                    }
                }

            }

            Item { width: 1; height: 20 }
        }
    }

    // 榜单歌曲空/加载失败状态:覆盖层,不占布局(原先在 Column 里占 200px,
    // 会让外层 Flickable 出现一段可滚动的空白)
    EmptyState {
        anchors.centerIn: parent
        width: parent.width * 0.6
        height: 200
        visible: root.showSongs && rankList && rankList.songs.length === 0
        iconText: "♪"
        title: rankList && rankList.isLoading ? "正在加载榜单歌曲..." : "榜单歌曲加载失败"
        subtitle: rankList && rankList.isLoading ? "" : "点击重试"
        buttonText: rankList && rankList.isLoading ? "" : "重新加载"
        onButtonClicked: {
            if (rankList && !rankList.isLoading)
                root.retryCurrentRank()
        }
    }

    // 切换榜单加载遮罩：旧榜单数据仍在时盖一层半透明遮罩 + 转圈，
    // 新数据就绪后自动消失（首次打开 songs 为空走 EmptyState 的加载文案）
    Rectangle {
        anchors.fill: parent
        visible: root.showSongs && rankList && rankList.isLoading && rankList.songs.length > 0
        color: Qt.rgba(0, 0, 0, 0.35)

        Column {
            anchors.centerIn: parent
            spacing: 12

            Image {
                id: loadingIcon
                anchors.horizontalCenter: parent.horizontalCenter
                source: AppIcon.refresh
                sourceSize: Qt.size(48, 48)
                width: 28
                height: 28
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: loadingIcon
                    color: "#ffffff"
                }
                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.showSongs && rankList && rankList.isLoading && !BasicConfig.uiIdle
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "正在加载榜单歌曲..."
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.family: AppTheme.fontFamily
                font.bold: true
                color: "#ffffff"
            }
        }
    }
}
