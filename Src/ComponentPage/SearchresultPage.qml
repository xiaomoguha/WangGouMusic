import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    id: searchResultRoot
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    objectName: "SearchresultPage"

    property string keyword: BasicConfig.searchKeyword

    // ===== 顶部信息栏 =====
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.leftMargin: 0.025 * parent.width
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 10
        height: 36

        Text {
            text: keyword
            font.pixelSize: 22
            font.bold: true
            color: AppTheme.textPrimary
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: {
                var total = complexsearch ? complexsearch.total : 0;
                if (total > 10000) return (total / 10000).toFixed(1) + "万首";
                return total + "首";
            }
            font.pixelSize: 13
            color: AppTheme.textMuted
            font.family: AppTheme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }

        // 返回按钮
        Rectangle {
            width: 28; height: 28; radius: 14
            color: backH.hovered ? AppTheme.iconButtonHover : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: backIco
                anchors.centerIn: parent
                source: "qrc:/image/fanhui.png"
                width: 14; height: 14; fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay { source: backIco; color: AppTheme.iconDefault }
            }
            HoverHandler { id: backH }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: BasicConfig.goBack()
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ===== 搜索结果列表 =====
    ComplexPage {
        anchors.top: headerRow.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
