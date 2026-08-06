import QtQuick 2.15
import QtQuick.Window 2.15
import QtMultimedia 6.0
import "../BasicConfig"

// MV 播放窗口（独立窗口，由 main.qml 实例化并设 transientParent）
// 数据流：mvHash 变化 → mvManager.fetchVideoUrl → videoUrlReceived(hash 匹配) → 播放
// 主播放器暂停/恢复由 main.qml 的 Connections 处理（打开暂停、关闭恢复）
Window {
    id: mvWindow
    width: 960
    height: 620
    minimumWidth: 480
    minimumHeight: 300
    title: mvTitle
    color: "#111111"

    property string mvHash: ""
    property string mvTitle: "MV"
    property string mvUrl: ""
    property bool isError: false

    MediaPlayer {
        id: mvPlayer
        source: mvWindow.mvUrl
        audioOutput: mvAudio
        videoOutput: mvVideo

        onErrorOccurred: {
            mvWindow.isError = true
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia)
                mvWindow.isError = false
        }
    }
    AudioOutput { id: mvAudio }

    // 黑底视频画面
    VideoOutput {
        id: mvVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    // 加载中/错误提示（视频画面铺满时不可见）
    Text {
        anchors.centerIn: parent
        visible: mvWindow.mvUrl === "" || mvWindow.isError
        text: mvWindow.isError ? "该歌曲暂无 MV 或已下架" : "正在加载 MV..."
        color: "#88FFFFFF"
        font.pixelSize: 15
        font.family: AppTheme.fontFamily

        Rectangle {
            visible: mvWindow.isError
            anchors.top: parent.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 90
            height: 30
            radius: 15
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

    // 切换歌曲：重新拉播放地址并播放
    onMvHashChanged: {
        if (mvHash === "") {
            mvWindow.mvUrl = ""
            mvPlayer.stop()
            return
        }
        mvWindow.mvUrl = ""
        mvWindow.isError = false
        if (mvManager)
            mvManager.fetchVideoUrl(mvHash)
    }

    Connections {
        target: mvManager
        function onVideoUrlReceived(hash, url) {
            if (hash === mvWindow.mvHash && !url.isEmpty) {
                mvWindow.mvUrl = url
                mvPlayer.play()
            }
        }
        function onVideoUrlFailed(hash) {
            if (hash === mvWindow.mvHash)
                mvWindow.isError = true
        }
    }

    onVisibleChanged: {
        if (!visible) {
            // 关闭：停视频清 URL，恢复主播放器由 main.qml 的 Connections 处理
            mvPlayer.stop()
            mvWindow.mvUrl = ""
        }
    }
}
