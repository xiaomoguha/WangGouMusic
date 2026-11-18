pragma ComponentBehavior: Bound
import QtQuick 2.15

// 带失败重试的网络封面图：页面打开时几十张封面并发请求，网络一抖个别
// 请求超时变 Image.Error，而 QML Image 不会自动重试——封面从此空白到
Image {
    id: root

    property string coverSource: ""
    property int maxRetries: 3
    property int retryCount: 0

    asynchronous: true
    cache: true

    onCoverSourceChanged: {
        retryCount = 0
        source = coverSource
    }

    onStatusChanged: {
        if (status === Image.Error && coverSource != "" && retryCount < maxRetries) {
            retryCount++
            retryTimer.interval = 1200 * retryCount
            retryTimer.restart()
        }
    }

    Timer {
        id: retryTimer
        onTriggered: {
            root.source = ""
            root.source = root.coverSource
        }
    }
}
