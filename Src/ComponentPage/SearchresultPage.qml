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

    // 歌手匹配（顶部卡片；搜索词命中歌手时显示）
    property var singerData: ({})

    // 搜索时并行查歌手（type=author 取第一个匹配）
    function searchSinger() {
        if (artistManager && keyword !== "")
            artistManager.searchSinger(keyword)
    }

    Connections {
        target: artistManager
        function onSingerFound(singer) {
            searchResultRoot.singerData = singer
        }
    }

    onKeywordChanged: searchResultRoot.searchSinger()
    Component.onCompleted: searchResultRoot.searchSinger()

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
            font.pixelSize: AppTheme.fontSizeBody
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
                source: AppIcon.back
                sourceSize: Qt.size(128, 128)
                mipmap: true
                width: 14; height: 14; fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: ColorOverlay { source: backIco; color: AppTheme.iconDefault }
            }
            HoverHandler { id: backH }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: BasicConfig.goBack()
            }
            Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
        }
    }

    // ===== 歌手卡片（命中歌手时显示） =====
    Rectangle {
        id: singerCard
        visible: singerData && singerData.name
        anchors.top: headerRow.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 30
        height: 72
        radius: 10
        color: singerHover.hovered ? AppTheme.bgNavHover : AppTheme.bgCard
        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            // 歌手头像
            Rectangle {
                width: 52
                height: 52
                radius: 26
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: AppTheme.bgSidebar

                Image {
                    anchors.fill: parent
                    source: singerData.avatar
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(104, 104)
                }
                Text {
                    visible: !singerData.avatar
                    anchors.centerIn: parent
                    text: singerData.name ? singerData.name.charAt(0) : "?"
                    font.pixelSize: 20
                    font.bold: true
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: singerData.name
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.bold: true
                    color: AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                }
                Text {
                    text: "粉丝 " + (singerData.fans > 0 ? singerData.fans : "—")
                          + "  单曲 " + (singerData.audioCount > 0 ? singerData.audioCount : "—")
                          + "  专辑 " + (singerData.albumCount > 0 ? singerData.albumCount : "—")
                    font.pixelSize: AppTheme.fontSizeCaption
                    color: AppTheme.textMuted
                    font.family: AppTheme.fontFamily
                }
            }

            // 歌手名高亮 tag（区分于歌曲结果）
            Rectangle {
                width: 54
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: AppTheme.accent
                Text {
                    anchors.centerIn: parent
                    text: "歌手"
                    font.pixelSize: AppTheme.fontSizeCaption
                    font.bold: true
                    color: "#ffffff"
                    font.family: AppTheme.fontFamily
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "查看歌手页 →"
                font.pixelSize: AppTheme.fontSizeSmall
                color: AppTheme.accent
                font.family: AppTheme.fontFamily
            }
        }

        HoverHandler { id: singerHover }
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: BasicConfig.openArtist(String(singerData.id), singerData.name)
        }
    }

    // ===== 搜索结果列表 =====
    ComplexPage {
        anchors.top: singerCard.visible ? singerCard.bottom : headerRow.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
