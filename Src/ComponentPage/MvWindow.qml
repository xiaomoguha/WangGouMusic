import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtMultimedia 6.0
import "../BasicConfig"

// MV 播放窗口（独立窗口，由 main.qml 实例化并设 transientParent）
// 左：视频区（悬停/暂停时显示控制栏：播放/暂停、进度条、时间）
// 右：歌曲信息面板（封面/歌名/歌手 + 评论列表，滚动到底自动翻页）
// 数据流：mvHash 变化 → mvManager.fetchVideoUrl → videoUrlReceived(hash 匹配) → 播放
Window {
    id: mvWindow
    width: 1120
    height: 660
    minimumWidth: 880
    minimumHeight: 520
    title: mvTitle
    color: "#0B0B0F"

    property string mvHash: ""
    property string mvTitle: "MV"
    property string mvSinger: ""
    property string mvCover: ""
    property string songHash: ""   // 音频 hash：拉评论用（评论接口走歌曲维度）
    property string mvUrl: ""
    property bool isError: false
    property string fetchedHash: ""  // 已在拉取的 mvhash：防 onMvHashChanged 与 onVisibleChanged 双重请求互相取消
    property string commentsLoadedHash: ""  // 评论已按此音频 hash 拉过

    function fmtTime(ms) {
        if (!isFinite(ms) || ms <= 0) return "00:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s -= m * 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // 统一拉取入口：同一 hash 只发一次请求
    function fetchMv() {
        if (mvHash === "" || fetchedHash === mvHash) {
            console.log("[MvWindow] fetchMv 跳过 mvHash=" + mvHash + " fetchedHash=" + fetchedHash)
            return
        }
        console.log("[MvWindow] fetchMv 发起 mvHash=" + mvHash)
        fetchedHash = mvHash
        isError = false
        if (mvManager)
            mvManager.fetchVideoUrl(mvHash)
    }

    // 评论按音频 hash 去重：切歌/重开不重复拉
    function fetchCommentsIfNeed() {
        if (!visible || songHash === "" || commentsLoadedHash === songHash)
            return
        if (!songComments || mvTitle === "")
            return
        commentsLoadedHash = songHash
        songComments.fetchComments(mvTitle, songHash)
    }

    MediaPlayer {
        id: mvPlayer
        source: mvWindow.mvUrl
        audioOutput: mvAudio
        videoOutput: mvVideo

        onErrorOccurred: {
            console.log("[MvWindow] 播放器 error: " + errorString)
            mvWindow.isError = true
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia)
                mvWindow.isError = false
        }
    }
    // 音量跟随主播放器音量（底栏滑条联动）
    AudioOutput {
        id: mvAudio
        volume: playlistmanager ? playlistmanager.volume : 1
    }

    // ===== 左：视频区 =====
    Rectangle {
        id: videoPane
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - infoPanel.width
        color: "#000000"

        VideoOutput {
            id: mvVideo
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }

        // 悬停感知 + 点击切换播放（双击全屏暂不做）
        MouseArea {
            id: videoHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (mvPlayer.playbackState === MediaPlayer.PlayingState)
                    mvPlayer.pause()
                else
                    mvPlayer.play()
            }
        }

        // 中央播放/暂停大按钮（暂停中或悬停且未在播放时显示）
        Rectangle {
            width: 64; height: 64; radius: 32
            anchors.centerIn: parent
            color: "#66000000"
            border.color: "#33FFFFFF"
            border.width: 1
            visible: mvWindow.mvUrl !== "" && !mvWindow.isError
                     && (videoHover.containsMouse || mvPlayer.playbackState !== MediaPlayer.PlayingState)

            Image {
                anchors.centerIn: parent
                width: 28; height: 28
                source: mvPlayer.playbackState === MediaPlayer.PlayingState ? AppIcon.pauseFill : AppIcon.playFill
                sourceSize: Qt.size(56, 56)
                mipmap: true
                fillMode: Image.PreserveAspectFit
            }
            // 点击切换统一由底层 videoHover 处理（按钮纯视觉，避免双重触发）
        }

        // 加载中/错误提示
        Column {
            anchors.centerIn: parent
            spacing: 14
            visible: mvWindow.mvUrl === "" || mvWindow.isError

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mvWindow.isError ? "该歌曲暂无 MV 或已下架" : "正在加载 MV..."
                color: "#88FFFFFF"
                font.pixelSize: 15
                font.family: AppTheme.fontFamily
            }

            Rectangle {
                visible: mvWindow.isError
                anchors.horizontalCenter: parent.horizontalCenter
                width: 90; height: 30; radius: 15
                color: "#33FFFFFF"
                Text {
                    anchors.centerIn: parent
                    text: "关闭"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.family: AppTheme.fontFamily
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: mvWindow.hide() }
            }
        }

        // ===== 底部控制栏（悬停/暂停/拖动时显示）=====
        Rectangle {
            id: controlBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 64
            opacity: {
                if (mvWindow.mvUrl === "" || mvWindow.isError) return 0
                if (videoHover.containsMouse || seekSlider.pressed) return 1
                return mvPlayer.playbackState === MediaPlayer.PlayingState ? 0 : 1
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#CC000000" }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 12
                spacing: 12

                // 播放/暂停
                Item {
                    width: 32; height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: mvPlayer.playbackState === MediaPlayer.PlayingState ? AppIcon.pauseFill : AppIcon.playFill
                        sourceSize: Qt.size(44, 44)
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                    }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (mvPlayer.playbackState === MediaPlayer.PlayingState) mvPlayer.pause()
                            else mvPlayer.play()
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: fmtTime(mvPlayer.position)
                    color: "#CCFFFFFF"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }

                Slider {
                    id: seekSlider
                    width: parent.width - 200
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: mvPlayer.duration > 0 ? mvPlayer.duration : 1
                    value: mvPlayer.position

                    background: Rectangle {
                        y: seekSlider.height / 2 - 2
                        width: seekSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#33FFFFFF"

                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: AppTheme.accent
                        }
                    }
                    handle: Rectangle {
                        x: seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.height / 2 - height / 2
                        width: 12; height: 12; radius: 6
                        color: "#FFFFFF"
                        scale: seekSlider.pressed ? 1.25 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                    onMoved: mvPlayer.setPosition(value)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: fmtTime(mvPlayer.duration)
                    color: "#99FFFFFF"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
            }
        }
    }

    // ===== 右：歌曲信息 + 评论 =====
    Rectangle {
        id: infoPanel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 320
        color: "#141419"

        Rectangle {  // 左侧细分隔线
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#22FFFFFF"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // 封面 + 歌名/歌手
            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 72; height: 72; radius: 8
                    clip: true
                    color: "#1F1F26"

                    Image {
                        anchors.fill: parent
                        source: mvWindow.mvCover
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                Column {
                    width: parent.width - 84
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: mvWindow.mvTitle
                        color: "#F2F2F5"
                        font.pixelSize: 16
                        font.bold: true
                        font.family: AppTheme.fontFamily
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                    Text {
                        width: parent.width
                        text: mvWindow.mvSinger
                        color: "#8A8A93"
                        font.pixelSize: AppTheme.fontSizeBody
                        font.family: AppTheme.fontFamily
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#1C1C22" }

            Text {
                text: songComments ? ("评论 · 共 " + songComments.totalCount + " 条") : "评论"
                color: "#8A8A93"
                font.pixelSize: AppTheme.fontSizeCaption
                font.family: AppTheme.fontFamily
            }

            // 评论列表
            ListView {
                id: commentList
                width: parent.width
                height: parent.height - 190
                clip: true
                spacing: 14
                cacheBuffer: 800
                model: songComments ? songComments.comments : []

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius: 3
                        color: parent.pressed ? "#88FFFFFF" : "#44FFFFFF"
                    }
                }

                // 滚动到底自动加载下一页
                onContentYChanged: {
                    if (songComments && !songComments.isLoading && songComments.hasMore
                        && contentHeight > height && contentY >= contentHeight - height - 200) {
                        songComments.fetchMore()
                    }
                }

                delegate: Row {
                    width: commentList.width - 8
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        clip: true
                        color: "#26262E"

                        Image {
                            anchors.fill: parent
                            source: modelData.user_pic
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(60, 60)
                            fillMode: Image.PreserveAspectCrop
                        }
                        Text {
                            visible: !modelData.user_pic
                            anchors.centerIn: parent
                            text: modelData.user_name ? modelData.user_name.charAt(0) : "?"
                            color: "#AAFFFFFF"
                            font.bold: true
                            font.pixelSize: 13
                            font.family: AppTheme.fontFamily
                        }
                    }

                    Column {
                        width: parent.width - 40
                        spacing: 4

                        Text {
                            text: modelData.user_name
                            color: "#C8C8CE"
                            font.bold: true
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.family: AppTheme.fontFamily
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            width: parent.width
                            text: modelData.content
                            color: "#9A9AA2"
                            font.pixelSize: AppTheme.fontSizeSmall
                            font.family: AppTheme.fontFamily
                            wrapMode: Text.Wrap
                        }
                        Text {
                            text: modelData.addtime
                            color: "#55555E"
                            font.pixelSize: AppTheme.fontSizeCaption
                            font.family: AppTheme.fontFamily
                        }
                    }
                }

                // 空态 / 加载中
                Text {
                    anchors.centerIn: parent
                    visible: songComments && songComments.comments.length === 0
                    text: songComments && songComments.isLoading ? "评论加载中..." : "暂无评论"
                    color: "#55555E"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
            }
        }
    }

    // 切换歌曲：重新拉播放地址并播放
    onMvHashChanged: {
        if (mvHash === "") {
            mvWindow.mvUrl = ""
            mvPlayer.stop()
            return
        }
        mvWindow.mvUrl = ""
        fetchMv()
        fetchCommentsIfNeed()
    }

    Connections {
        target: mvManager
        function onVideoUrlReceived(hash, url) {
            console.log("[MvWindow] onVideoUrlReceived hash=" + hash + " 匹配=" + (hash === mvWindow.mvHash))
            if (hash === mvWindow.mvHash && !url.isEmpty) {
                mvWindow.isError = false  // 清掉取消竞态/旧请求留下的假错误
                mvWindow.mvUrl = url
                mvPlayer.play()
            }
        }
        function onVideoUrlFailed(hash) {
            console.log("[MvWindow] onVideoUrlFailed hash=" + hash + " 匹配=" + (hash === mvWindow.mvHash))
            if (hash === mvWindow.mvHash)
                mvWindow.isError = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            // 重开同一首歌：mvHash 不变不触发 onMvHashChanged，主动重拉
            fetchMv()
            fetchCommentsIfNeed()
        } else {
            // 关闭：停视频清 URL，重置防重入标记（下次打开重新拉）
            mvPlayer.stop()
            mvWindow.mvUrl = ""
            fetchedHash = ""
        }
    }
}
