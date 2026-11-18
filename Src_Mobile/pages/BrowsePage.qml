import QtQuick
import ".."
import "../../Src/BasicConfig"

// 音乐馆 Tab（默认首页）—— 汇聚桌面端发现内容：
// Banner → 个人FM(personalFM，可刷新) → 每日推荐行(dailyRecommend)
Item
{
    id: root

    property int tabIndex: 0

    // 歌单发现当前分类
    property string currentTag: ""

    // 是否已加入一起听房间（进房后歌曲行出现点播按钮）
    readonly property bool inRoom: websocket && websocket.connectionState !== 0

    // 暴露给 main_mobile 的 --tour 巡览滚动
    property alias contentFlick: contentFlick

    Component.onCompleted: {
        if (recommendation && recommendation.topPlaylistsQml.length === 0)
            recommendation.fetchTopPlaylists()
        if (recommendation && recommendation.topSongsQml.length === 0)
            recommendation.fetchTopSongs()
        if (rankList && rankList.ranks.length === 0)
            rankList.fetchRanks()
        if (discoverManager && discoverManager.tagsQml.length === 0) {
            discoverManager.fetchTags()
            dailyRecommend.fetch()
            personalFM.fetch()
        }
    }

    // tags 就绪后默认选第一个分类
    Connections {
        target: discoverManager

        function onTagsChanged() {
            if (root.currentTag === "" && discoverManager.tagsQml.length > 0) {
                root.currentTag = discoverManager.tagsQml[0].tag_name || ""
                discoverManager.fetchPlaylists(root.currentTag)
            }
        }
    }

    // ===== Banner 取色：用每日推荐第一首的封面主色做背景主题 =====
    readonly property string dailyFirstCover:
        dailyRecommend && dailyRecommend.songs.length > 0 ? dailyRecommend.songs[0].union_cover : ""
    property string bannerColor: "#A32424"

    onDailyFirstCoverChanged: {
        if (dailyFirstCover !== "" && playlistColorExtractor)
            playlistColorExtractor.extract(dailyFirstCover)
    }

    Connections {
        target: playlistColorExtractor

        function onDominantColorReady(imageUrl, hexColor) {
            if (imageUrl !== root.dailyFirstCover || hexColor === "")
                return
            // 亮色压暗，保证白字可读
            var col = Qt.color(hexColor)
            var lum = 0.299 * col.r + 0.587 * col.g + 0.114 * col.b
            root.bannerColor = lum > 0.65 ? Qt.darker(hexColor, 1.7).toString() : hexColor
        }
    }

    // ===== 排行榜 top3 预览缓存（顺序抓取前 8 个榜单） =====
    property var rankTopCache: ({})
    property var rankQueue: []
    property bool rankPumping: false

    // fetchRanks 完成时 isLoading 尚未复位，立即 fetchRankSongs 会被
    // C++ 的 m_isLoading 守卫静默拒绝 —— 延迟 120ms 再泵
    Timer {
        id: rankPumpTimer

        interval: 120
        onTriggered: {
            if (rankList && root.rankQueue.length > 0) {
                root.rankPumping = true
                rankList.fetchRankSongs(root.rankQueue[0])
            }
        }
    }

    function pumpRankQueue()
    {
        rankPumpTimer.restart()
    }

    function cacheCurrentRankSongs()
    {
        if (!rankPumping || rankQueue.length === 0 || !rankList)
            return
        var rid = rankQueue[0]
        var top = []
        var s = rankList.songs
        for (var i = 0; i < Math.min(3, s.length); i++)
            top.push(s[i].songname || "")
        var copy = {}
        for (var k in rankTopCache)
            copy[k] = rankTopCache[k]
        copy[rid] = top
        rankTopCache = copy
        rankQueue = rankQueue.slice(1)
        if (rankQueue.length === 0)
            rankPumping = false
        pumpRankQueue()
    }

    Connections {
        target: rankList

        function onRanksChanged() {
            var r = rankList.ranks
            root.rankQueue = []
            for (var i = 0; i < Math.min(8, r.length); i++)
                root.rankQueue.push(r[i].rankid)
            root.pumpRankQueue()
        }

        function onSongsChanged() {
            root.cacheCurrentRankSongs()
        }
    }

    // ===== 顶栏（参考 QQ 音乐：通栏大圆角搜索框） =====
    Item {
        id: topNav

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52

        // 搜索框（点击进搜索页）
        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 38
            radius: 19
            color: searchBoxMa.pressed ? MTheme.bgCard : MTheme.bgInput
            border.width: searchBoxMa.pressed ? 1 : 0
            border.color: MTheme.accent

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                MIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    source: AppIcon.search
                    color: MTheme.textMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("搜索歌曲、歌手")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textPlaceholder
                }
            }
            MouseArea {
                id: searchBoxMa

                anchors.fill: parent
                onPressed: {
                    console.log("[browse] search box pressed")
                    MTheme.pushPage("qrc:/Src_Mobile/pages/SearchPage.qml")
                }
            }
        }
    }

    // ===== 内容 =====
    Flickable {
        id: contentFlick

        anchors.top: topNav.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentHeight: contentColumn.height + 16
        boundsBehavior: Flickable.StopAtBounds

        onAtYEndChanged: {
            if (atYEnd && discoverManager && discoverManager.hasMore
                    && !discoverManager.isLoading && root.currentTag !== "")
                discoverManager.fetchMorePlaylists()
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            // ---- Banner ----
            Item {
                width: parent.width
                height: 166

                Rectangle {
                    id: banner

                    anchors.fill: parent
                    anchors.margins: MTheme.pageHPadding
                    radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.darker(root.bannerColor, 1.25) }
                        GradientStop { position: 1.0; color: root.bannerColor }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        spacing: 7
                        width: parent.width - 18 - 116 - 16

                        Text {
                            width: parent.width
                            text: qsTr("网狗音乐 · 新歌速递")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption + 1
                            color: "#B3FFFFFF"
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: qsTr("每日推荐上新")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontHeadline - 2
                            font.bold: true
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: qsTr("热门新歌第一时间送达，支持无损试听")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: "#80FFFFFF"
                            elide: Text.ElideRight
                            wrapMode: Text.WrapAnywhere
                        }

                        Row {
                            spacing: 10

                            Rectangle {
                                width: 88
                                height: 30
                                radius: 15
                                color: "#FFFFFF"

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("立即畅听")
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption + 1
                                    font.bold: true
                                    color: "#B02A2A"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (recommendation && recommendation.topSongsQml.length > 0)
                                            playlistmanager.playSongbyhasg(recommendation.topSongsQml[0].songhash)
                                    }
                                }
                            }
                            Rectangle {
                                width: 88
                                height: 30
                                radius: 15
                                color: "transparent"
                                border.width: 1
                                border.color: "#99FFFFFF"

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("查看榜单")
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption + 1
                                    color: "#FFFFFF"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/RankPage.qml")
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 100
                        height: 100
                        radius: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.top: parent.top
                        anchors.topMargin: 18
                        color: "#33FFFFFF"
                        clip: true

                        // 每日推荐第一首的封面（无则回退应用图标）
                        RetryImage {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: root.dailyFirstCover !== ""
                            coverSource: root.dailyFirstCover
                            fillMode: Image.PreserveAspectCrop
                        }
                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: root.dailyFirstCover === ""
                            source: "qrc:/image/wyyicon.png"
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }

            // ---- 个人FM（可刷新，一行一首） ----
            Item {
                width: parent.width
                height: fmHead.height + 8 + (personalFM && personalFM.songs.length > 0 ? fmCol.height : 40) + 8

                Row {
                    id: fmHead

                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.top: parent.top
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("私人FM")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontTitle
                        font.bold: true
                        color: MTheme.textPrimary
                    }

                    // 刷新按钮
                    Item {
                        width: MTheme.touchMin - 10
                        height: MTheme.touchMin - 10
                        anchors.verticalCenter: parent.verticalCenter

                        MIcon {
                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            source: AppIcon.refresh
                            color: MTheme.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (personalFM.songs.length > 0)
                                    personalFM.fetchNext()
                                else
                                    personalFM.fetch()
                            }
                        }
                    }
                }

                Column {
                    id: fmCol

                    anchors.top: fmHead.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.right: parent.right
                    anchors.rightMargin: MTheme.pageHPadding
                    spacing: 2

                    Text {
                        width: parent.width
                        height: personalFM && personalFM.songs.length > 0 ? 0 : 32
                        visible: personalFM && personalFM.songs.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("点击右上角刷新，为你随机放歌")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textMuted
                    }

                    Repeater {
                        model: personalFM ? personalFM.songs : []

                        delegate: Item {
                            id: fmRow

                            required property int index
                            required property var modelData

                            width: fmCol.width
                            height: 60

                            readonly property bool playing: playlistmanager.currentSonghash === fmRow.modelData.songhash

                            Rectangle {
                                anchors.fill: parent
                                radius: MTheme.coverRadius
                                color: MTheme.bgInput
                                visible: fmRowMa.pressed || fmRow.playing
                                opacity: fmRow.playing ? 0.6 : 1
                            }

                            MCover {
                                width: 46
                                height: 46
                                radius: MTheme.coverRadius
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                source: fmRow.modelData.union_cover
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 62
                                anchors.right: parent.right
                                anchors.rightMargin: root.inRoom ? 58 : 44
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: fmRow.modelData.songname
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontBody
                                    font.bold: fmRow.playing
                                    color: fmRow.playing ? MTheme.accent : MTheme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: fmRow.modelData.singername
                                          + (fmRow.modelData.album_name !== "" ? " - " + fmRow.modelData.album_name : "")
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontCaption
                                    color: MTheme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            MTogetherButton {
                                anchors.right: parent.right
                                anchors.rightMargin: 34
                                anchors.verticalCenter: parent.verticalCenter
                                songname: fmRow.modelData.songname
                                songhash: fmRow.modelData.songhash
                                singername: fmRow.modelData.singername
                                albumname: fmRow.modelData.album_name
                                duration: fmRow.modelData.duration || ""
                                coverurl: fmRow.modelData.union_cover || ""
                            }

                            MEqBars {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: fmRow.playing
                            }

                            MIcon {
                                width: 18
                                height: 18
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !fmRow.playing
                                source: AppIcon.playFill
                                color: MTheme.textPrimary
                            }

                            MouseArea {
                                id: fmRowMa

                                anchors.fill: parent
                                onClicked: playlistmanager.playSongbyhasg(fmRow.modelData.songhash)
                            }
                        }
                    }
                }
            }

            // ---- 每日推荐（行样式：左封面 + 右前三首预览，与排行榜一致） ----
            Item {
                width: parent.width
                height: 78

                // 按压高亮（与排行榜行同宽：两侧 pageHPadding）
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.rightMargin: MTheme.pageHPadding
                    radius: MTheme.coverRadius
                    color: dailyMa.pressed ? MTheme.bgInput : "transparent"
                }

                MCover {
                    width: 64
                    height: 64
                    radius: MTheme.coverRadius
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding + 4
                    anchors.verticalCenter: parent.verticalCenter
                    source: dailyRecommend ? dailyRecommend.coverUrl : ""
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding + 82
                    anchors.right: parent.right
                    anchors.rightMargin: MTheme.pageHPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: qsTr("每日推荐")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBodyLg
                        font.bold: true
                        color: MTheme.textPrimary
                    }

                    Repeater {
                        model: 3

                        delegate: Row {
                            required property int index

                            width: parent.width
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (index + 1) + ""
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption
                                font.bold: true
                                color: MTheme.accent
                            }
                            Text {
                                width: parent.width - 20 - 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: dailyRecommend && index < dailyRecommend.songs.length
                                      ? (dailyRecommend.songs[index].songname || "") : " "
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption
                                color: MTheme.textMuted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                MouseArea {
                    id: dailyMa

                    anchors.fill: parent
                    onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/DailyRecommendPage.qml")
                }
            }

            // ---- 排行榜（一行一个：封面 + 榜名 + 前三首预览） ----
            Item {
                width: parent.width
                height: rankHead.height + 10 + rankListCol.height + 8

                Row {
                    id: rankHead

                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.top: parent.top
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("排行榜")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontTitle
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                    MIcon {
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppIcon.caretRight
                        color: MTheme.textPrimary
                    }
                }
                MouseArea {
                    anchors.fill: rankHead
                    onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/RankPage.qml")
                }

                Column {
                    id: rankListCol

                    anchors.top: rankHead.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.right: parent.right
                    anchors.rightMargin: MTheme.pageHPadding
                    spacing: 6

                    Repeater {
                        model: {
                            var r = rankList ? rankList.ranks : []
                            return r.slice(0, 8)
                        }

                        delegate: Item {
                            id: rankRowItem

                            required property int index
                            required property var modelData

                            width: rankListCol.width
                            height: 78

                            readonly property var top3: root.rankTopCache[rankRowItem.modelData.rankid || ""]

                            // 按压高亮
                            Rectangle {
                                anchors.fill: parent
                                radius: MTheme.coverRadius
                                color: MTheme.bgInput
                                visible: rankRowMa.pressed
                            }

                            MCover {
                                width: 64
                                height: 64
                                radius: MTheme.coverRadius
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                source: rankRowItem.modelData.imgurl || ""
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 82
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: rankRowItem.modelData.rankname || ""
                                    font.family: MTheme.fontFamily
                                    font.pixelSize: MTheme.fontBodyLg
                                    font.bold: true
                                    color: MTheme.textPrimary
                                    elide: Text.ElideRight
                                }

                                // 前三首预览（顺序抓取缓存）
                                Repeater {
                                    model: 3

                                    delegate: Row {
                                        required property int index

                                        spacing: 6

                                        Text {
                                            text: (index + 1) + ""
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontCaption
                                            font.bold: true
                                            color: index < 3 ? MTheme.accent : MTheme.textPlaceholder
                                        }
                                        Text {
                                            width: rankListCol.width - 82 - 8 - 20 - 6
                                            text: {
                                                var t = rankRowItem.top3
                                                return t && index < t.length ? t[index] : " "
                                            }
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontCaption
                                            color: MTheme.textMuted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rankRowMa

                                anchors.fill: parent
                                onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/RankPage.qml",
                                                            { startRankid: rankRowItem.modelData.rankid || "" })
                            }
                        }
                    }
                }
            }

            // ---- 云音乐精选（横滑歌单） ----
            Item {
                width: parent.width
                height: 168

                Text {
                    id: plTitle

                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.top: parent.top
                    text: qsTr("云音乐精选")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontTitle
                    font.bold: true
                    color: MTheme.textPrimary
                }

                ListView {
                    id: plRow

                    anchors.top: plTitle.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    spacing: 10
                    leftMargin: MTheme.pageHPadding
                    rightMargin: MTheme.pageHPadding
                    orientation: ListView.Horizontal

                    model: recommendation ? recommendation.topPlaylistsQml : []

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: plRow.count === 0

                        MLoading { size: 30; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("加载中…")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBody
                            color: MTheme.textMuted
                        }
                    }

                    delegate: Item {
                        id: plCard

                        required property int index
                        required property var modelData

                        width: 104
                        height: plRow.height

                        Column {
                            anchors.fill: parent
                            spacing: 6

                            Item {
                                width: 104
                                height: 104

                                MCover {
                                    anchors.fill: parent
                                    radius: MTheme.coverRadius
                                    source: plCard.modelData.imgurl
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 5
                                    width: playRow.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: "#59000000"

                                    Row {
                                        id: playRow

                                        anchors.centerIn: parent
                                        spacing: 3

                                        MIcon {
                                            width: 9
                                            height: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: AppIcon.headphones
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: BasicConfig.formatCount(plCard.modelData.play_count)
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontCaption - 2
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }

                            Text {
                                width: 104
                                height: 32
                                text: plCard.modelData.specialname
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontCaption
                                color: MTheme.textSecondary
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/PlaylistDetailPage.qml",
                                                        { playlist: plCard.modelData })
                        }
                    }
                }
            }

            // ---- 歌单发现（分类 tag + 双列宫格） ----
            Item {
                width: parent.width
                height: discTitle.height + 10 + tagRow.height + 8 + discoverListWrap.height + 12

                Text {
                    id: discTitle

                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.top: parent.top
                    text: qsTr("歌单发现")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontTitle
                    font.bold: true
                    color: MTheme.textPrimary
                }

                // 分类 chips
                ListView {
                    id: tagRow

                    anchors.top: discTitle.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 30
                    clip: true
                    spacing: 8
                    leftMargin: MTheme.pageHPadding
                    rightMargin: MTheme.pageHPadding
                    orientation: ListView.Horizontal

                    model: discoverManager ? discoverManager.tagsQml : []

                    delegate: Rectangle {
                        id: tagChip

                        required property int index
                        required property var modelData

                        width: tagText.implicitWidth + 26
                        height: 30
                        radius: 15
                        color: root.currentTag === (modelData.tag_name || "") ? MTheme.accent : MTheme.bgInput

                        Text {
                            id: tagText

                            anchors.centerIn: parent
                            text: tagChip.modelData.tag_name || ""
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption + 1
                            color: root.currentTag === (tagChip.modelData.tag_name || "") ? "#FFFFFF" : MTheme.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var t = tagChip.modelData.tag_name || ""
                                if (t === "" || t === root.currentTag)
                                    return
                                root.currentTag = t
                                discoverManager.fetchPlaylists(t)
                            }
                        }
                    }
                }

                // 单列列表（左封面 + 右文字介绍，参考桌面客户端）
                Item {
                    id: discoverListWrap

                    anchors.top: tagRow.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(discoverListCol.height, 56)

                    Text {
                        anchors.centerIn: parent
                        visible: !discoverManager || (discoverManager.playlistsQml.length === 0 && !discoverManager.isLoading)
                        text: qsTr("暂无歌单")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textMuted
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: discoverManager && discoverManager.playlistsQml.length === 0 && discoverManager.isLoading

                        MLoading { size: 30; anchors.horizontalCenter: parent.horizontalCenter }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("加载中…")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBody
                            color: MTheme.textMuted
                        }
                    }

                    Column {
                        id: discoverListCol

                        anchors.left: parent.left
                        anchors.leftMargin: MTheme.pageHPadding
                        anchors.right: parent.right
                        anchors.rightMargin: MTheme.pageHPadding
                        anchors.top: parent.top
                        spacing: 2

                        Repeater {
                            model: discoverManager ? discoverManager.playlistsQml : []

                            delegate: Item {
                                id: discRow

                                required property int index
                                required property var modelData

                                width: discoverListCol.width
                                height: 76

                                Rectangle {
                                    anchors.fill: parent
                                    radius: MTheme.coverRadius
                                    color: MTheme.bgInput
                                    visible: discRowMa.pressed
                                }

                                MCover {
                                    width: 64
                                    height: 64
                                    radius: MTheme.coverRadius
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: discRow.modelData.imgurl || ""
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 80
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: discRow.modelData.specialname || ""
                                        font.family: MTheme.fontFamily
                                        font.pixelSize: MTheme.fontBodyLg
                                        font.bold: true
                                        color: MTheme.textPrimary
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: discRow.modelData.nickname || ""
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontCaption
                                            color: MTheme.textMuted
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, parent.width / 2)
                                        }
                                        Row {
                                            spacing: 3

                                            MIcon {
                                                width: 10
                                                height: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: AppIcon.headphones
                                                color: MTheme.textMuted
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: BasicConfig.formatCount(discRow.modelData.play_count) + qsTr("次播放")
                                                font.family: MTheme.fontFamily
                                                font.pixelSize: MTheme.fontCaption
                                                color: MTheme.textMuted
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: discRowMa

                                    anchors.fill: parent
                                    onClicked: MTheme.pushPage("qrc:/Src_Mobile/pages/PlaylistDetailPage.qml",
                                                                { playlist: discRow.modelData })
                                }
                            }
                        }
                    }
                }
            }

            // ---- 新歌新碟 ----
            Item {
                width: parent.width
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("新歌新碟")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontTitle
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                    MIcon {
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppIcon.caretRight
                        color: MTheme.textPrimary
                    }
                }
            }

            Item {
                width: parent.width
                height: songPager.count > 0 ? 3 * 64 + 30 : 72

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 22
                    spacing: 10
                    visible: songPager.count === 0

                    MLoading { size: 30; anchors.horizontalCenter: parent.horizontalCenter }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("加载中…")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textMuted
                    }
                }

                // 横向分页（一页 3 行，右缘露出下一页，参考 QQ 音乐）
                ListView {
                    id: songPager

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3 * 64
                    clip: true
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 220
                    spacing: 12
                    leftMargin: MTheme.pageHPadding
                    rightMargin: MTheme.pageHPadding
                    boundsBehavior: Flickable.StopAtBounds

                    // 页宽留 24px 给下一页露边
                    readonly property real pageW: width - MTheme.pageHPadding * 2 - 24

                    model: {
                        var arr = recommendation ? recommendation.topSongsQml : []
                        var pages = []
                        for (var i = 0; i < arr.length; i += 3)
                            pages.push(arr.slice(i, i + 3))
                        return pages
                    }

                    delegate: Item {
                        id: songPage

                        required property int index
                        required property var modelData

                        width: songPager.pageW
                        height: songPager.height

                        Column {
                            anchors.fill: parent

                            Repeater {
                                model: songPage.modelData

                                delegate: Item {
                                    id: nsRow

                                    required property int index
                                    required property var modelData

                                    width: songPage.width
                                    height: 64

                                    readonly property bool playing:
                                        playlistmanager.currentSonghash === nsRow.modelData.songhash

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: MTheme.pageHPadding / 2
                                        anchors.rightMargin: MTheme.pageHPadding / 2
                                        radius: MTheme.coverRadius
                                        color: MTheme.bgInput
                                        visible: nsRowMa.pressed
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: MTheme.pageHPadding
                                        anchors.rightMargin: MTheme.pageHPadding
                                        spacing: 12

                                        MCover {
                                            width: 46
                                            height: 46
                                            radius: MTheme.coverRadius
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: nsRow.modelData.union_cover
                                        }

                                        Column {
                                            width: parent.width - 46 - 44 - (root.inRoom ? 18 : 0)
                                                   - parent.spacing * (root.inRoom ? 3 : 2)
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: nsRow.modelData.songname
                                                font.family: MTheme.fontFamily
                                                font.pixelSize: MTheme.fontBodyLg
                                                color: nsRow.playing ? MTheme.accent : MTheme.textPrimary
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                width: parent.width
                                                text: nsRow.modelData.singername
                                                  + (nsRow.modelData.album_name !== "" ? " - " + nsRow.modelData.album_name : "")
                                                font.family: MTheme.fontFamily
                                                font.pixelSize: MTheme.fontCaption
                                                color: MTheme.textMuted
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MTogetherButton {
                                            anchors.verticalCenter: parent.verticalCenter
                                            songname: nsRow.modelData.songname
                                            songhash: nsRow.modelData.songhash
                                            singername: nsRow.modelData.singername
                                            albumname: nsRow.modelData.album_name
                                            coverurl: nsRow.modelData.union_cover || ""
                                        }

                                        Item {
                                            width: 44
                                            height: 44
                                            anchors.verticalCenter: parent.verticalCenter

                                            MEqBars {
                                                anchors.centerIn: parent
                                                visible: nsRow.playing
                                            }
                                            MIcon {
                                                anchors.centerIn: parent
                                                width: 20
                                                height: 20
                                                visible: !nsRow.playing
                                                source: AppIcon.play
                                                color: MTheme.textPrimary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: playlistmanager.playSongbyhasg(nsRow.modelData.songhash)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: nsRowMa

                                        anchors.fill: parent
                                        onClicked: playlistmanager.playSongbyhasg(nsRow.modelData.songhash)
                                    }
                                }
                            }
                        }
                    }
                }

                // 页码圆点
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 3 * 64 + 12
                    spacing: 6
                    visible: songPager.count > 1

                    Repeater {
                        model: Math.ceil((recommendation ? recommendation.topSongsQml.length : 0) / 3)

                        delegate: Rectangle {
                            required property int index

                            width: 5
                            height: 5
                            radius: 2.5
                            color: songPager.currentIndex === index ? MTheme.accent : MTheme.bgInput
                        }
                    }
                }
            }
        }
    }
}
