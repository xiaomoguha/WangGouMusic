import QtQuick 2.15
import "."
import "../Src/BasicConfig"

// 底部导航栏（网易云浅色风格）：白底 + 顶部发丝线，激活红/未激活灰。
Rectangle
{
    id: root

    property int currentIndex: 0
    signal tabSelected(int index)

    readonly property var tabs: [
        { icon: AppIcon.compass,     label: qsTr("音乐馆") },
        { icon: AppIcon.headphones,  label: qsTr("一起听") },
        { icon: AppIcon.user,        label: qsTr("我的") }
    ]

    // 高度含底部安全区：背景延伸到手势条下方（沉浸式），内容仍在安全区内
    width: parent ? parent.width : 0
    height: MTheme.tabBarHeight + MTheme.safeBottom
    color: MTheme.bgCard

    // 顶部发丝分隔线
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: MTheme.separator
    }

    Row {
        id: tabRow

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: MTheme.tabBarHeight

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tabDelegate

                required property int index
                required property var modelData

                width: root.width / root.tabs.length
                height: tabRow.height

                readonly property bool active: root.currentIndex === index

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    MIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22
                        height: 22
                        source: tabDelegate.modelData.icon
                        color: tabDelegate.active ? MTheme.iconActive : MTheme.iconInactive
                        Behavior on color { ColorAnimation { duration: MTheme.animFast } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tabDelegate.modelData.label
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        font.bold: tabDelegate.active
                        color: tabDelegate.active ? MTheme.iconActive : MTheme.iconInactive
                        Behavior on color { ColorAnimation { duration: MTheme.animFast } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // 只发信号，不直接写 currentIndex——
                        // 命令式赋值会永久破坏外部绑定（currentIndex: root.currentTab），
                        if (root.currentIndex !== tabDelegate.index)
                            root.tabSelected(tabDelegate.index)
                    }
                }
            }
        }
    }
}
