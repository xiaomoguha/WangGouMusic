import QtQuick 2.15

// 进度条上的高潮开始小圆点：切歌/打开时触发 playlistmanager.fetchClimax（内部按 hash 去重），
// 显示读 playlistmanager.climaxPercent。多个 ClimaxDot 实例（底栏 + 播放页）共享，整首歌只请求一次。
// 用法：放进进度条容器内，设 dotColor 与已播放进度色一致即可
Rectangle {
    id: root
    width: 8
    height: 8
    radius: 4
    color: dotColor
    visible: playlistmanager && playlistmanager.climaxPercent > 0
    anchors.verticalCenter: parent.verticalCenter
    x: playlistmanager ? Math.min(Math.max(parent.width * playlistmanager.climaxPercent - width / 2, 0), parent.width - width)
                       : 0

    property color dotColor: "#FFFFFF"

    // 切歌触发请求（playlistmanager 内部按 hash 去重：两个 ClimaxDot 各触发一次只产生一次请求）
    Connections {
        target: playlistmanager
        function onCurrentSongChanged() {
            if (playlistmanager)
                playlistmanager.fetchClimax(playlistmanager.currentSonghash)
        }
    }

    Component.onCompleted: if (playlistmanager) playlistmanager.fetchClimax(playlistmanager.currentSonghash)

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (playlistmanager && playlistmanager.climaxPercent > 0)
                playlistmanager.setposistion(playlistmanager.climaxPercent)
        }
    }
}
