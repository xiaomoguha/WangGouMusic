import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects

// 通用图标按钮：圆形底 + 可着色图标 + hover 反馈 + clicked() 信号。
Item {
    id: root

    property string iconSource: ""
    property int size: 28
    property int iconSize: 12
    property real iconRotation: 0
    property color iconColor: AppTheme.iconDefault

    // 背景统一：默认透明（无圆底，浅色不再有红圈），hover 用主题统一的 iconButtonHover；
    property color hoverColor: AppTheme.iconButtonHover
    property color normalColor: "transparent"

    // 悬停提示：默认按图标给出功能说明，个别位置可显式覆盖；空字符串 = 不显示
    property string tooltipText: {
        if (iconSource === AppIcon.playCircle) return "播放"
        if (iconSource === AppIcon.addToList) return "添加到下一首"
        if (iconSource === AppIcon.addTogether) return "加入一起听"
        if (iconSource === AppIcon.video) return "播放 MV"
        if (iconSource === AppIcon.heart) return "收藏到我喜欢"
        if (iconSource === AppIcon.heartFill) return "取消收藏"
        if (iconSource === AppIcon.deleteIcon) return "移除"
        if (iconSource === AppIcon.sparkle) return "AI 推荐"
        if (iconSource === AppIcon.caretRight) return "展开"
        if (iconSource === AppIcon.caretDown) return "收起"
        if (iconSource === AppIcon.queue) return "播放列表"
        if (iconSource === AppIcon.prev) return "上一首"
        if (iconSource === AppIcon.next) return "下一首"
        if (iconSource === AppIcon.play || iconSource === AppIcon.playFill) return "播放"
        if (iconSource === AppIcon.pause || iconSource === AppIcon.pauseFill) return "暂停"
        if (iconSource === AppIcon.playModeOrder) return "播放模式：顺序"
        if (iconSource === AppIcon.playModeRepeatOne) return "播放模式：单曲循环"
        if (iconSource === AppIcon.playModeShuffle) return "播放模式：随机"
        return ""
    }

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
            layer.textureSize: Qt.size(root.iconSize * 4, root.iconSize * 4)
            layer.effect: ColorOverlay { source: icon; color: root.iconColor }
        }
    }

    ToolTip {
        id: iconTip
        parent: root
        visible: root.tooltipText !== "" && hoverHandler.hovered
        delay: 700
        text: root.tooltipText
        padding: 6
        x: (root.width - implicitWidth) / 2
        y: root.height + 4
        background: Rectangle {
            color: "#F21E1E2A"
            radius: 4
            border.width: 1
            border.color: "#33FFFFFF"
        }
        contentItem: Text {
            text: iconTip.text
            color: "#FFFFFF"
            font.pixelSize: 10
            font.family: AppTheme.fontFamily
        }
    }

    HoverHandler { id: hoverHandler }
    TapHandler {
        id: tapHandler
        cursorShape: Qt.PointingHandCursor
        onTapped: root.clicked()
    }
}
