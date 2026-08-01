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
    property color iconColor: AppTheme.iconDefault

    // 背景统一：默认透明（无圆底，浅色不再有红圈），hover 用主题统一的 iconButtonHover；
    // 窗口按钮由调用方覆盖为 #30FFFFFF / 关闭键 #FF5252。
    property color hoverColor: AppTheme.iconButtonHover
    property color normalColor: "transparent"

    readonly property bool hovered: hoverHandler.hovered

    // 悬停/按压缩放动画（现代反馈）；个别不希望缩放的位置可设 animated: false
    property bool animated: true
    property real hoverScale: 1.12
    property real pressScale: 0.9

    signal clicked()

    width: root.size
    height: root.size

    scale: !root.animated ? 1.0
           : (tapHandler.pressed ? root.pressScale
                                 : (hoverHandler.hovered ? root.hoverScale : 1.0))
    Behavior on scale { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }

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
            // 按 iconSize×4 自适应栅格化（≈设备像素 2×）：曲线无锯齿，下采样比仅 2:1。
            sourceSize: Qt.size(root.iconSize * 4, root.iconSize * 4)
            smooth: true
            mipmap: true
            rotation: root.iconRotation
            layer.enabled: true
            // 着色离屏通道同分辨率，消除 ColorOverlay 按 item 逻辑尺寸低清栅格化导致的二次模糊；
            // 2:1 比例下 smooth 双线性即可（Qt6 Layer 无 mips 属性）。
            layer.textureSize: Qt.size(root.iconSize * 4, root.iconSize * 4)
            layer.effect: ColorOverlay { source: icon; color: root.iconColor }
        }
    }

    HoverHandler { id: hoverHandler }
    TapHandler {
        id: tapHandler
        cursorShape: Qt.PointingHandCursor
        onTapped: root.clicked()
    }
}
