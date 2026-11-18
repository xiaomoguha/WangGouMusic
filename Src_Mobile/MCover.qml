import QtQuick
import QtQuick.Effects
import "."
import "../Src/BasicConfig"

// 圆角/圆形遮罩封面：Qt 的 Rectangle.clip 是矩形裁剪，圆角外的图片角
// 会露出来——本组件用 MultiEffect 的 alpha 遮罩把图片严格裁进圆角内。
Item
{
    id: root

    property string source: ""
    property real radius: 10

    width: 100
    height: 100

    // 加载/空图时的底色垫片（与图片同圆角）
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: MTheme.bgInput
    }

    RetryImage {
        id: img

        anchors.fill: parent
        visible: false
        coverSource: root.source
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: root.radius
        // Qt 6.12 MultiEffect 的 maskSource 不渲染 visible:false 的项：
        // 必须可见，但用 layer.enabled 让它只进纹理不上屏
        visible: true
        layer.enabled: true
        color: "#FFFFFF"
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: root.source !== ""
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
