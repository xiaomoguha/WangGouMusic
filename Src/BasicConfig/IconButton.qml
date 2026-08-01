import QtQuick 2.15
import Qt5Compat.GraphicalEffects

// 通用图标按钮：圆形底 + 可着色图标 + hover 反馈 + clicked() 信号。
// 取代各列表行(播放/添加/一起听)与窗口控制(最小/最大/关闭/收起)里重复的
// Rectangle{ Image + ColorOverlay + HoverHandler + TapHandler + Behavior } 模板。
Item {
    id: root

    property string iconSource: ""
    property int size: 28
    property int iconSize: 12
    property real iconRotation: 0
    property color iconColor: AppTheme.isDark ? AppTheme.iconDefault : AppTheme.accent

    // 背景双色：默认=列表行动作按钮配色；窗口按钮由调用方覆盖为 #30FFFFFF / 关闭键 #FF5252
    property color hoverColor: AppTheme.isDark ? AppTheme.iconButtonHover : "#FFCCCC"
    property color normalColor: AppTheme.isDark ? "transparent" : "#FFD8D8"

    readonly property bool hovered: hoverHandler.hovered

    signal clicked()

    width: root.size
    height: root.size

    Rectangle {
        anchors.fill: parent
        radius: root.size / 2
        color: root.hovered ? root.hoverColor : root.normalColor
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

        Image {
            id: icon
            anchors.centerIn: parent
            source: root.iconSource
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
            rotation: root.iconRotation
            layer.enabled: true
            layer.effect: ColorOverlay { source: icon; color: root.iconColor }
        }
    }

    HoverHandler { id: hoverHandler }
    TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.clicked()
    }
}
