import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

// AI 推荐内联展开：点歌曲行 ✨ 后在行下方撑开几小行（缩进一格，样式同主行但小一号）
// 父行把 height 绑定到 (基础行高 + expandedHeight) 即可撑开列表；
// 每小行带小号操作按钮：立即播放 / 加下一首 / 我喜欢 / 一起听
Item {
    id: root
    width: parent.width

    property bool expanded: false           // 展开/收回（有数据时点 ✨ 只切换，不重新请求）
    property var aiSongs: []
    property string aiError: ""
    property string seedName: ""
    property string seedHash: ""            // 本次请求的种子 hash：结果只匹配自己，避免行间串扰

    // 展开高度（驱动父行高度）：未展开 0；加载/失败 = 头部 24 + 行 30；列表 = 头部 24 + 每行 40 + 底距 6
    property real expandedHeight: {
        if (!expanded) return 0
        if (aiSongs.length > 0) return 24 + aiSongs.length * 40 + 6
        return 24 + 30
    }

    // 点击 ✨：已展开 → 收回；有数据未展开 → 展开（不重新请求）；无数据 → 请求生成
    function toggle(hash, name) {
        if (expanded) {
            expanded = false
            return
        }
        expanded = true
        seedHash = hash.toUpperCase()
        if (aiSongs.length === 0) {
            aiError = ""
            seedName = name
            if (aiRecommendManager)
                aiRecommendManager.recommend(hash, name)
        }
    }

    Connections {
        target: aiRecommendManager
        // 只接收自己发起的请求结果（seedHash 匹配），其他行展开互不影响
        function onRecommendDone(seedHash, songs) {
            if (root.seedHash === seedHash)
                root.aiSongs = songs
        }
        function onRecommendFailed(seedHash, reason) {
            if (root.seedHash === seedHash) {
                root.aiSongs = []
                root.aiError = reason
            }
        }
    }

    Column {
        width: root.width
        visible: root.expanded

        // 头部：AI 歌单 · 种子歌曲
        Item {
            width: parent.width
            height: 24
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                text: "AI 歌单 · " + root.seedName
                font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily; bold: true }
                color: AppTheme.textMuted
            }
        }

        // 加载中 / 失败（头部下方居中）
        Row {
            visible: root.aiSongs.length === 0
            height: 30
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: aiLoadingIcon
                anchors.verticalCenter: parent.verticalCenter
                source: AppIcon.refresh
                sourceSize: Qt.size(48, 48)
                width: 14
                height: 14
                fillMode: Image.PreserveAspectFit
                visible: root.aiError === ""
                layer.enabled: true
                layer.effect: ColorOverlay { source: aiLoadingIcon; color: AppTheme.textMuted }
                NumberAnimation on rotation {
                    from: 0; to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.expanded && root.aiError === ""
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.aiError !== "" ? "AI 推荐失败: " + root.aiError : "AI 生成中..."
                font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily }
                color: AppTheme.textMuted
            }
        }

        // 推荐歌曲小行：缩进一格、格式对齐歌单主行（序号/封面/歌名歌手/操作区/专辑/时长），
        // 只是小一号；操作按钮行为与主行一致（一起听按钮仅一起听模式显示）
        Repeater {
            model: root.aiSongs
            delegate: Rectangle {
                id: aiRow
                width: parent.width
                height: 40
                radius: 6
                // hover 只文字高亮（同歌曲行，无背景遮罩）
                color: "transparent"

                readonly property bool isTogetherMode: playlistmanager && playlistmanager.type === 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 6

                    // 序号（小号）
                    Text {
                        width: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: (index + 1).toString().padStart(2, "0")
                        font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily; bold: true }
                        color: aiRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textMuted
                    }

                    // 封面
                    RetryImage {
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        coverSource: modelData.union_cover
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: 28; height: 28; radius: 6 }
                        }
                    }

                    // 歌名/歌手
                    Column {
                        width: parent.width - 14 - 28 - 6 - (aiRowHover.hovered ? 100 : 0) - 100 - 44 - 6 * 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            text: modelData.songname
                            width: parent.width
                            elide: Text.ElideRight
                            font { pixelSize: AppTheme.fontSizeSmall; family: AppTheme.fontFamily; bold: true }
                            color: aiRowHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                        }
                        Text {
                            text: modelData.singername
                            width: parent.width
                            elide: Text.ElideRight
                            font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily }
                            color: AppTheme.textMuted
                        }
                    }

                    // 小号操作按钮（hover 显示，同主行：播放/下一首/我喜欢；一起听模式只留加入一起听）
                    Row {
                        width: 100
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: aiRowHover.hovered

                        IconButton {
                            visible: !aiRow.isTogetherMode
                            iconSource: AppIcon.playCircle
                            size: 24
                            iconSize: 13
                            onClicked: root.playSong(modelData)
                        }
                        IconButton {
                            visible: !aiRow.isTogetherMode
                            iconSource: AppIcon.addToList
                            size: 24
                            iconSize: 13
                            onClicked: root.addToNext(modelData)
                        }
                        IconButton {
                            visible: !aiRow.isTogetherMode
                            iconSource: AppIcon.heart
                            iconColor: AppTheme.textSecondary
                            size: 24
                            iconSize: 13
                            onClicked: root.favorite(modelData)
                        }
                        IconButton {
                            visible: aiRow.isTogetherMode
                            iconSource: AppIcon.addTogether
                            size: 24
                            iconSize: 13
                            onClicked: root.addTogether(modelData)
                        }
                    }

                    // 专辑名（AI 接口不带专辑名时为占位列，保持格式对齐）
                    Text {
                        width: 100
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: modelData.album_name || ""
                        font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily }
                        color: AppTheme.textMuted
                    }

                    // 时长（右侧）
                    Text {
                        width: 44
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData.duration || "--:--"
                        font { pixelSize: AppTheme.fontSizeCaption; family: AppTheme.fontFamily }
                        color: AppTheme.textMuted
                    }
                }

                HoverHandler { id: aiRowHover; cursorShape: Qt.PointingHandCursor }
                // 整行点击 = 立即播放（同主行）
                TapHandler {
                    onTapped: root.playSong(modelData)
                }
            }
        }
    }

    function playSong(song) {
        // 一起听模式：整行点击 = 加入一起听（同主行行为）
        if (playlistmanager && playlistmanager.type === 1) {
            addTogether(song)
            return
        }
        playlistmanager.playNextAndPlay({
            "songname": song.songname,
            "songhash": song.songhash,
            "singername": song.singername,
            "union_cover": song.union_cover,
            "album_name": song.album_name,
            "duration": song.duration
        })
        BasicConfig.emitSongAdded("正在播放: " + song.songname)
    }

    // 加入下一首播放（addSongNext 自带去重：已有则移动到下一首；当前歌跳过）
    function addToNext(song) {
        playlistmanager.addSongNext({
            "songname": song.songname,
            "songhash": song.songhash,
            "singername": song.singername,
            "union_cover": song.union_cover,
            "album_name": song.album_name,
            "duration": song.duration
        })
        BasicConfig.emitSongAdded("已添加到下一首: " + song.songname)
    }

    function favorite(song) {
        if (!userManager || !userManager.isLoggedIn) {
            BasicConfig.noticeError("请先登录")
            return
        }
        playlistCollection.addToFavorite(song.songname, song.songhash, song.singername)
    }

    function addTogether(song) {
        if (websocket)
            websocket.addSongToTogether(song.songname, song.songhash, song.singername,
                                        song.album_name, song.duration, song.union_cover)
    }
}
