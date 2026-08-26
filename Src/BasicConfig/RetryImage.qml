pragma ComponentBehavior: Bound
import QtQuick 2.15

// 带失败重试的网络封面图：页面打开时几十张封面并发请求，网络一抖个别
// 请求超时变 Image.Error，而 QML Image 不会自动重试——封面从此空白到
// 页面销毁（播放路径走 C++ 独立下载所以"播放时又有封面"）。
// 用法：绑定 coverSource（不是 source），其余属性同 Image。
// 失败后递增退避重试（默认 3 次：1.2s/2.4s/3.6s），成功即止；
// 失败的图不会进 QML 图片缓存，清空 source 再赋同 URL 即触发重新加载。
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
