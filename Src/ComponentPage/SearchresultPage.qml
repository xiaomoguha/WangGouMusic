import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    id: searchResultRoot

    // 页面入场：淡入 + 轻微上浮（切页时内容"落"下来而不是硬切）；空闲门控下直接落终态。
    opacity: 0
    transform: Translate { id: searchResultRootEnterShift; y: 14 }

    // 入场触发用 0ms Timer：页面自身可能已有 Component.onCompleted，
    // 直接再写一个会触发"属性重复赋值"导致整页加载失败（踩过）
    Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: {
            if (BasicConfig.uiIdle) {
                searchResultRoot.opacity = 1
                searchResultRootEnterShift.y = 0
            } else {
                searchResultRootEnterAnim.start()
            }
        }
    }

    ParallelAnimation {
        id: searchResultRootEnterAnim
        NumberAnimation {
            target: searchResultRoot; property: "opacity"
            from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: searchResultRootEnterShift; property: "y"
            from: 14; to: 0; duration: 420; easing.type: Easing.OutCubic
        }
    }

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

    // 歌手卡片主色 → 整窗渐变（命中歌手时沉浸，机制同歌手页）
    property string coverColor: ""
    property string requestedCoverUrl: ""   // 本次请求的封面 URL：回调核对防串扰

    function syncWindowTint() {
        // 隐藏时不操作 BasicConfig：多个详情页同色时隐藏页误关会杀掉显示页的渐变；
        // 回首页由 Rightpage.hideOverlay 统一关闭。
        if (!searchResultRoot.visible)
            return
        if (searchResultRoot.coverColor !== "") {
            BasicConfig.playlistPageActive = true
            BasicConfig.playlistPageCoverColor = searchResultRoot.coverColor
        }
    }

    function requestCoverColor() {
        var avatar = searchResultRoot.singerData ? searchResultRoot.singerData.avatar : ""
        if (!avatar || avatar === "") {
            requestedCoverUrl = ""
            coverColor = ""
            syncWindowTint()
            return
        }
        requestedCoverUrl = avatar
        playlistColorExtractor.extract(avatar)
    }

    onVisibleChanged: syncWindowTint()

    Connections {
        target: artistManager
        function onSingerFound(singer) {
            searchResultRoot.singerData = singer
            searchResultRoot.requestCoverColor()
        }
    }

    Connections {
        target: playlistColorExtractor
        // 只接受自己发起的请求结果（imageUrl 匹配），其他页面的结果不污染本页
        function onDominantColorReady(imageUrl, color) {
            if (imageUrl !== searchResultRoot.requestedCoverUrl)
                return
            searchResultRoot.coverColor = color
            searchResultRoot.syncWindowTint()
        }
    }

    onKeywordChanged: {
        searchResultRoot.singerData = ({})
        searchResultRoot.requestCoverColor()
        searchResultRoot.searchSinger()
    }
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

    }

    // ===== 歌手卡片（命中歌手时显示） =====
    Rectangle {
        id: singerCard
        visible: !!(singerData && singerData.name)
        anchors.top: headerRow.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 30
        height: 72
        radius: 10
        // 透明融入渐变；hover 只文字高亮（同歌曲行，无黑色遮罩）
        color: "transparent"

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            // 歌手头像（图片未就绪时透明，不露占位灰圆）
            Rectangle {
                width: 52
                height: 52
                radius: 26
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: singerAvatarImg.status === Image.Ready ? AppTheme.bgSidebar : "transparent"

                RetryImage {
                    id: singerAvatarImg
                    anchors.fill: parent
                    coverSource: singerData.avatar || ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(104, 104)
                    // 加载完成才淡入，避免露出深色占位圆
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                Text {
                    visible: singerAvatarImg.status !== Image.Ready
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
                    text: singerData.name || ""
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.bold: true
                    color: singerHover.hovered ? AppTheme.accentPlaying : AppTheme.textPrimary
                    font.family: AppTheme.fontFamily
                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
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
