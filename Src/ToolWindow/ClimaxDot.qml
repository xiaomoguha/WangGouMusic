import QtQuick 2.15
import NetworkRequest 1.0

// 进度条上的高潮开始小圆点：切歌/打开时自动请求 /song/climax，点击直接跳到高潮位置
// 用法：放进进度条容器内，设 dotColor 与已播放进度色一致即可
Rectangle {
    id: root
    width: 8
    height: 8
    radius: 4
    color: dotColor
    visible: climaxPercent > 0
    anchors.verticalCenter: parent.verticalCenter
    x: Math.min(Math.max(parent.width * climaxPercent - width / 2, 0), parent.width - width)

    property color dotColor: "#FFFFFF"

    property real climaxPercent: 0
    property string climaxHash: ""

    function parseDurationMs(str) {
        if (!str) return 0
        if (str.indexOf(":") !== -1) {
            var parts = str.split(":")
            return (parseInt(parts[0]) * 60 + parseInt(parts[1])) * 1000
        }
        return parseInt(str) * 1000
    }
    function fetchClimax() {
        var hash = playlistmanager ? playlistmanager.currentSonghash : ""
        climaxPercent = 0
        if (hash === "") return
        climaxHash = hash
        climaxRequester.fetchData("https://xjt-togethertracks.top/api/song/climax?hash=" + hash)
    }

    HttpGetRequester {
        id: climaxRequester
        onDataReceived: function (data) {
            try {
                // 迟到响应核对：期间已切歌则丢弃
                if (climaxHash !== (playlistmanager ? playlistmanager.currentSonghash : "")) return
                var json = JSON.parse(data)
                if (json.status === 1 && json.data && json.data.length > 0 && json.data[0].start_time) {
                    var totalMs = parseDurationMs(playlistmanager ? playlistmanager.duration : "")
                    var startMs = parseInt(json.data[0].start_time)
                    climaxPercent = totalMs > 0 ? Math.min(startMs / totalMs, 1) : 0
                } else {
                    climaxPercent = 0
                }
            } catch (e) {
                climaxPercent = 0
            }
        }
        onRequestFailed: function (error) {
            climaxPercent = 0
        }
    }

    // 切歌自动更新；打开时（onCompleted）也拉一次当前歌
    Connections {
        target: playlistmanager
        function onCurrentSongChanged() {
            root.fetchClimax()
        }
    }

    Component.onCompleted: fetchClimax()

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (playlistmanager && climaxPercent > 0)
                playlistmanager.setposistion(climaxPercent)
        }
    }
}
