import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

/// 左侧导航栏矢量图标（Phosphor SVG）。selected=填充变体，未选中=线框。
/// iconType: discover(精选) | together(一起听) | daily(每日推荐) | rank(排行榜) | playlist(我的歌单) | list(播放列表) | recent(最近播放)
Item {
    id: root

    property string iconType: "discover"
    property bool selected: false
    property color iconColor: "#FFFFFF"

    implicitWidth: 20
    implicitHeight: 20

    // iconType → [线框, 填充]
    readonly property var _icons: ({
        "discover": [AppIcon.star, AppIcon.starFill],
        "together": [AppIcon.headphones, AppIcon.headphonesFill],
        "daily": [AppIcon.sparkle, AppIcon.sparkle],
        "rank": [AppIcon.fire, AppIcon.fire],
        "playlist": [AppIcon.heart, AppIcon.heartFill],
        "list": [AppIcon.list, AppIcon.listFill],
        "recent": [AppIcon.clock, AppIcon.clockFill],
        "history": [AppIcon.clock, AppIcon.clockFill]
    })
    readonly property string _source: {
        var pair = root._icons[root.iconType];
        if (!pair) return "";
        return root.selected ? pair[1] : pair[0];
    }

    Image {
        id: img
        anchors.fill: parent
        source: root._source
        sourceSize: Qt.size(128, 128)
        mipmap: true
        fillMode: Image.PreserveAspectFit
        layer.enabled: true
        layer.effect: ColorOverlay { source: img; color: root.iconColor }
    }
}
