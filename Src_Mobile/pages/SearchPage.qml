import QtQuick
import ".."
import "../../Src/BasicConfig"

// 搜索页（移动版，真实功能，仿网易云搜索两页）：
// 未搜索：猜你喜欢（两列词格，hostSearch）+ 热搜榜卡（rankList 真实榜单 top10）。
// 已搜索：播放全部 + 紧凑结果行（关键词红色高亮，complexsearch 分页）。
Item
{
    id: root

    property string keyword: ""
    property string hotRankid: ""
    property string firstHash: ""   // 结果第一首（播放全部用，由首个 delegate 上报）

    // 是否已加入一起听房间（进房后搜索结果行出现点播按钮）
    readonly property bool inRoom: websocket && websocket.connectionState !== 0

    Component.onCompleted: {
        if (hostSearch && hostSearch.items.length === 0)
            hostSearch.fetchhostserachData("https://api.special520.com/search/hot")
        if (rankList && rankList.ranks.length === 0)
            rankList.fetchRanks()
        else
            pickHotRank()
        input.forceActiveFocus()
    }

    // 榜单就绪后挑选"热搜榜"
    Connections {
        target: rankList

        function onRanksChanged() { root.pickHotRank() }
    }

    function pickHotRank()
    {
        if (hotRankid !== "" || !rankList)
            return
        var ranks = rankList.ranks
        for (var i = 0; i < ranks.length; i++) {
            var n = ranks[i].rankname || ""
            if (n.indexOf("热") >= 0) {
                hotRankid = ranks[i].rankid
                rankList.fetchRankSongs(hotRankid)
                return
            }
        }
        if (ranks.length > 0) {
            hotRankid = ranks[0].rankid
            rankList.fetchRankSongs(hotRankid)
        }
    }

    // 关键词红色高亮（HTML 转义后替换）
    function highlight(text, kw)
    {
        var t = (text || "")
        if (kw === "")
            return t
        var esc = t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        var ekw = kw.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        try {
            return esc.replace(new RegExp(ekw, "gi"), function(m) {
                return "<font color=\"#EC4141\"><b>" + m + "</b></font>"
            })
        } catch (e) {
            return esc
        }
    }

    function doSearch(kw)
    {
        kw = (kw || "").trim()
        if (kw.length === 0)
            return
        root.keyword = kw
        input.text = kw
        input.focus = false
        searchHistory.addSearch(kw)
        complexsearch.fetchComplexData(kw)
    }

    // ===== 头部：返回 + 搜索框 + 搜索按钮 =====
    Item {
        id: head

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52

        Item {
            width: MTheme.touchMin
            height: MTheme.touchMin
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter

            MIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: AppIcon.back
                color: MTheme.textPrimary
            }
            MouseArea {
                anchors.fill: parent
                onClicked: MTheme.popPage()
            }
        }

        // 搜索胶囊
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 52
            anchors.right: parent.right
            anchors.rightMargin: 62
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            radius: 18
            color: MTheme.bgInput

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MIcon {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    source: AppIcon.search
                    color: MTheme.textPlaceholder
                }

                TextInput {
                    id: input

                    width: parent.parent.width - 12 - 14 - 6 - 30
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textPrimary
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === "" && !input.activeFocus
                        text: qsTr("搜索歌曲、歌手")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBody
                        color: MTheme.textPlaceholder
                    }

                    onAccepted: root.doSearch(input.text)
                }
            }

            // 清空按钮
            Item {
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text !== ""

                MIcon {
                    anchors.centerIn: parent
                    width: 13
                    height: 13
                    source: AppIcon.close
                    color: MTheme.textPlaceholder
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        input.text = ""
                        input.forceActiveFocus()
                    }
                }
            }
        }

        // 搜索按钮（未搜索时显示；搜索后由胶囊内 × 接管，与截图一致）
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.keyword === ""
            text: qsTr("搜索")
            font.family: MTheme.fontFamily
            font.pixelSize: MTheme.fontBodyLg
            color: MTheme.accent

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: root.doSearch(input.text)
            }
        }
    }

    // ===== 内容区 =====
    Item {
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // ---- 未搜索态 ----
        Flickable {
            anchors.fill: parent
            visible: root.keyword === ""
            clip: true
            contentHeight: idleColumn.height + 16
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: idleColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                // ---- 猜你喜欢（两列词格，只展示前 8 个） ----
                Item {
                    width: parent.width
                    height: 40

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: MTheme.pageHPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("猜你喜欢")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBodyLg
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                }

                Grid {
                    x: MTheme.pageHPadding
                    width: parent.width - MTheme.pageHPadding * 2
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 0

                    Repeater {
                        model: Math.min(8, hostSearch ? hostSearch.items.length : 0)

                        delegate: Item {
                            id: guessWord

                            required property int index

                            width: (parent.width - 12) / 2
                            height: 40

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 12
                                text: hostSearch && guessWord.index < hostSearch.items.length
                                      ? (hostSearch.items[guessWord.index].keyword || "") : ""
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontBody + 1
                                color: MTheme.textPrimary
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (hostSearch && guessWord.index < hostSearch.items.length)
                                        root.doSearch(hostSearch.items[guessWord.index].keyword || "")
                                }
                            }
                        }
                    }
                }

                // ---- 热搜榜卡 ----
                Item {
                    width: parent.width
                    height: 14
                }

                Rectangle {
                    width: parent.width - MTheme.pageHPadding * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: hotCardColumn.height + 20
                    radius: MTheme.cardRadius
                    color: MTheme.bgCard

                    Column {
                        id: hotCardColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14

                        // 标题行：热搜榜 + ▶播放
                        Item {
                            width: parent.width
                            height: 34

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var r = rankList ? rankList.ranks : []
                                    for (var i = 0; i < r.length; i++) {
                                        if (r[i].rankid === root.hotRankid)
                                            return r[i].rankname
                                    }
                                    return qsTr("热搜榜")
                                }
                                font.family: MTheme.fontFamily
                                font.pixelSize: MTheme.fontBodyLg
                                font.bold: true
                                color: MTheme.textPrimary
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: playHot.implicitWidth + 24
                                height: 26
                                radius: 13
                                color: MTheme.bgInput

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    MIcon {
                                        width: 11
                                        height: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: AppIcon.playFill
                                        color: MTheme.accent
                                    }
                                    Text {
                                        id: playHot

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("播放")
                                        font.family: MTheme.fontFamily
                                        font.pixelSize: MTheme.fontCaption + 1
                                        font.bold: true
                                        color: MTheme.textPrimary
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var s = rankList ? rankList.songs : []
                                        if (s.length > 0)
                                            playlistmanager.playSongbyhasg(s[0].songhash)
                                    }
                                }
                            }
                        }

                        // Top10 编号列表
                        Column {
                            width: parent.width

                            Repeater {
                                model: 10

                                delegate: Item {
                                    id: hotRow

                                    required property int index

                                    width: parent.width
                                    height: rankList && index < rankList.songs.length ? 38 : 0
                                    visible: rankList && index < rankList.songs.length

                                    Row {
                                        anchors.fill: parent
                                        spacing: 12

                                        Text {
                                            width: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            text: hotRow.index + 1
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontBody
                                            font.bold: true
                                            color: hotRow.index < 3 ? MTheme.accent : MTheme.textMuted
                                        }

                                        Text {
                                            width: parent.width - 20 - 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: rankList && hotRow.index < rankList.songs.length
                                                  ? (rankList.songs[hotRow.index].songname || "")
                                                  : ""
                                            font.family: MTheme.fontFamily
                                            font.pixelSize: MTheme.fontBody
                                            color: MTheme.textPrimary
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (rankList && hotRow.index < rankList.songs.length)
                                                playlistmanager.playSongbyhasg(rankList.songs[hotRow.index].songhash)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- 结果列表 ----
        ListView {
            id: resultList

            anchors.fill: parent
            visible: root.keyword !== ""
            clip: true
            spacing: 0

            model: complexsearch

            Text {
                anchors.centerIn: parent
                visible: root.keyword !== "" && complexsearch && complexsearch.count === 0
                         && !complexsearch.isLoading
                text: qsTr("没有找到相关歌曲")
                font.family: MTheme.fontFamily
                font.pixelSize: MTheme.fontBody
                color: MTheme.textMuted
            }

            // 搜索中动画
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: root.keyword !== "" && complexsearch && complexsearch.count === 0
                         && complexsearch.isLoading

                MLoading { size: 30; anchors.horizontalCenter: parent.horizontalCenter; color: MTheme.accent }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("正在搜索…")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontBody
                    color: MTheme.textMuted
                }
            }

            // ===== 播放全部头 =====
            header: Item {
                width: resultList.width
                height: 54

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        anchors.verticalCenter: parent.verticalCenter
                        color: MTheme.accent

                        MIcon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: AppIcon.playFill
                            color: "#FFFFFF"
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("播放全部 ") + (complexsearch ? complexsearch.count : 0)
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontBodyLg
                        font.bold: true
                        color: MTheme.textPrimary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (complexsearch && complexsearch.count > 0 && root.firstHash !== "")
                            playlistmanager.playSongbyhasg(root.firstHash)
                    }
                }
            }

            delegate: Item {
                id: searchRow

                required property int index
                required property string songname
                required property string singername
                required property string album_name
                required property string songhash
                required property string union_cover

                width: resultList.width
                height: 58

                readonly property bool playing: playlistmanager.currentSonghash === songhash

                Component.onCompleted: if (index === 0) root.firstHash = songhash
                onSonghashChanged: if (index === 0) root.firstHash = songhash

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: MTheme.pageHPadding / 2
                    anchors.rightMargin: MTheme.pageHPadding / 2
                    radius: MTheme.coverRadius
                    color: MTheme.bgInput
                    visible: searchRow.playing
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: MTheme.pageHPadding
                    anchors.rightMargin: MTheme.pageHPadding
                    spacing: 10

                    MCover {
                        width: 46
                        height: 46
                        radius: MTheme.coverRadius
                        anchors.verticalCenter: parent.verticalCenter
                        source: searchRow.union_cover ? searchRow.union_cover : ""
                    }

                    Column {
                        width: parent.width - 46 - parent.spacing - (root.inRoom ? 18 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            textFormat: Text.RichText
                            text: root.highlight(searchRow.songname, root.keyword)
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontBody
                            color: searchRow.playing ? MTheme.accent : MTheme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: searchRow.singername
                                  + (searchRow.album_name !== "" ? " - " + searchRow.album_name : "")
                            font.family: MTheme.fontFamily
                            font.pixelSize: MTheme.fontCaption
                            color: MTheme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }

                    MTogetherButton {
                        anchors.verticalCenter: parent.verticalCenter
                        songname: searchRow.songname
                        songhash: searchRow.songhash
                        singername: searchRow.singername
                        albumname: searchRow.album_name
                        coverurl: searchRow.union_cover || ""
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: playlistmanager.playSongbyhasg(searchRow.songhash)
                    }
                }

            onAtYEndChanged: {
                if (atYEnd && complexsearch && complexsearch.hasMore && !complexsearch.isLoading)
                    complexsearch.fetchMore()
            }

            footer: Item {
                width: resultList.width
                height: 48
                visible: complexsearch && complexsearch.count > 0

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: complexsearch && complexsearch.isLoading

                    MLoading { width: 18; height: 18 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("加载中…")
                        font.family: MTheme.fontFamily
                        font.pixelSize: MTheme.fontCaption
                        color: MTheme.textMuted
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: complexsearch && !complexsearch.isLoading && complexsearch.hasMore
                    text: qsTr("上滑加载更多")
                    font.family: MTheme.fontFamily
                    font.pixelSize: MTheme.fontCaption
                    color: MTheme.textMuted
                }
            }
        }
    }
}
