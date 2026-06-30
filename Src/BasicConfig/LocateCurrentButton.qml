import QtQuick 2.15

// 浮动「定位到正在播放」按钮：列表滚动且当前歌不在视口内时出现，
// 点击把当前歌滚到视口中部。右下角锚定由调用方负责。
Item {
    id: root

    // 目标 ListView
    property var target: null
    // 当前歌在 target 中的下标，-1 = 不在此列表（按钮隐藏）
    property int currentSongIndex: -1
    property bool enabled: true

    // 视口内是否已能看到当前歌：取视口顶/底可见下标，判断当前下标是否落在区间内
    readonly property bool currentInView: {
        if (!target || currentSongIndex < 0) return false
        var top = target.indexAt(target.width / 2, target.contentY + 2)
        var bot = target.indexAt(target.width / 2, target.contentY + target.height - 2)
        if (top < 0 || bot < 0) return false
        return currentSongIndex >= top && currentSongIndex <= bot
    }

    readonly property bool shouldBeVisible: enabled && !!target && currentSongIndex >= 0
                                             && !currentInView && target.contentY > 8
    visible: shouldBeVisible
    opacity: shouldBeVisible ? 1.0 : 0.0
    scale: shouldBeVisible ? 1.0 : 0.6
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    width: 40
    height: 40

    function locate() {
        if (!target || currentSongIndex < 0) return
        target.positionViewAtIndex(currentSongIndex, ListView.Center)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: locateMA.containsMouse ? AppTheme.iconButtonHover : AppTheme.bgCard
        border.width: 1
        border.color: AppTheme.borderDefault

        // 准星图标：外环 + 中心点（无需图片资源，主题色可缩放）
        Item {
            anchors.centerIn: parent
            width: 18
            height: 18

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: AppTheme.accent
            }

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 2.5
                color: AppTheme.accent
            }
        }

        MouseArea {
            id: locateMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.locate()
        }
    }
}
