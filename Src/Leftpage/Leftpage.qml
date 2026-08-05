pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import "../ToolWindow"

Rectangle {
    id: leftpageRectangle
    property int currentIndex: 0

    // “我的歌单”可展开：用户歌单列表、展开态、当前选中的歌单 id
    property var userPlaylists: []
    property bool playlistsExpanded: true
    property string activePlaylistGid: ""

    // 拉取用户歌单：先读缓存即时填充，空则异步请求（与 UserPlaylistPage 同一套数据源）
    function refreshUserPlaylists() {
        var cached = userManager.loadCachedPlaylists();
        var listData = cached ? (cached["data"] || cached) : null;
        var arr = [];
        if (listData && listData.info && listData.info.length > 0)
            arr = listData.info.slice(0);
        userPlaylists = arr;
        if (arr.length === 0 && userManager.isLoggedIn)
            userManager.fetchUserPlaylist(1, 30);
    }

    // 整窗统一渐变：本面板切片（面板根色在 main.qml 改为透明时生效）
    WindowTintGradient {
        baseColor: AppTheme.bgSidebar
        panelTopY: 0
    }

    Connections {
        target: BasicConfig
        function onIndexChange(index) {
            leftpageRectangle.currentIndex = index;
            // 走索引导航（云精选/一起听/最近播放/返回）即离开歌单详情，清掉高亮
            leftpageRectangle.activePlaylistGid = "";
        }
    }

    // 用户歌单数据：接口返回 + 登录态变化时刷新侧边栏子项
    Connections {
        target: userManager
        function onUserPlaylistReceived(data) {
            var listData = data["data"] || data;
            var arr = [];
            if (listData && listData.info && listData.info.length > 0)
                arr = listData.info.slice(0);
            userPlaylists = arr;
        }
        function onLoginStatusChanged() {
            if (userManager.isLoggedIn)
                refreshUserPlaylists();
            else
                userPlaylists = [];
        }
    }

    Component.onCompleted: {
        if (userManager && userManager.isLoggedIn)
            refreshUserPlaylists();
    }

    // Logo 区域
    Item {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // mac 顶部左上角有原生 traffic-light 三按钮，logo 往下让出空间
        anchors.topMargin: Qt.platform.os === "osx" ? 65 : 35
        height: 50

        Row {
            spacing: 8
            anchors.centerIn: parent

            Rectangle {
                width: 44
                height: 44
                radius: 12
                color: "transparent"

                Image {
                    id: wyyicon
                    anchors.centerIn: parent
                    source: "qrc:/image/wyyicon.png"
                    width: 36
                    height: 36
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                        }
                    }
                }
            }

            Text {
                id: titletext
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("网狗音乐")
                font.pixelSize: AppTheme.fontSizeHeadline
                font.family: AppTheme.fontFamily
                font.bold: true
                color: AppTheme.textPrimary
            }
        }

    }

    // 第一组导航（固定，不随歌单列表滚动）
    Column {
        id: navColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: 40
        spacing: 4

        property var navList: [
            {
                iconType: "discover",
                text: "云音乐精选",
                pageurl: "qrc:/Src/ComponentPage/HomePage.qml"
            },
            {
                iconType: "daily",
                text: "每日推荐",
                pageurl: "qrc:/Src/ComponentPage/DailyRecommendPage.qml"
            },
            {
                iconType: "rank",
                text: "排行榜",
                pageurl: "qrc:/Src/ComponentPage/RankPage.qml"
            },
            {
                iconType: "together",
                text: "一起听歌",
                pageurl: "qrc:/Src/ComponentPage/musictogether.qml"
            }
        ]

        Repeater {
            model: navColumn.navList.length

            delegate: Rectangle {
                id: navItemRect
                required property int index
                width: parent.width - 24
                height: 44
                radius: 12
                anchors.horizontalCenter: parent.horizontalCenter
                // hover 改为文字/图标变亮（背景保持透明，渐变下无块状覆盖层）
                color: leftpageRectangle.currentIndex === index ? AppTheme.accent : "transparent"

                property bool isSelected: leftpageRectangle.currentIndex === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    NavIcon {
                        iconType: navColumn.navList[navItemRect.index].iconType
                        selected: navItemRect.isSelected
                        iconColor: navItemRect.isSelected ? AppTheme.iconActive : (navMouseArea.containsMouse ? AppTheme.textPrimary : AppTheme.iconNav)
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: navColumn.navList[navItemRect.index].text
                        font.pixelSize: AppTheme.fontSizeBodyLg
                        font.family: AppTheme.fontFamily
                        font.bold: true
                        color: navItemRect.isSelected ? AppTheme.textPrimary : (navMouseArea.containsMouse ? AppTheme.textPrimary : AppTheme.textSecondary)
                    }
                }

                MouseArea {
                    id: navMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 已选中时不重复切换
                        leftpageRectangle.activePlaylistGid = "";
                        if (leftpageRectangle.currentIndex !== navItemRect.index) {
                            leftpageRectangle.currentIndex = navItemRect.index;
                            BasicConfig.pushPage(navColumn.navList[navItemRect.index].pageurl);
                        }
                    }
                }


                scale: navMouseArea.containsMouse && !isSelected ? 1.03 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: AppTheme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // 分隔线
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 12
        height: 1
        color: AppTheme.borderSubtle

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animThemeTransition
            }
        }
    }

    // 第二组导航（底部锚到窗口底：歌单展开较多时，列表区域滚动，导航项不受影响）
    Column {
        id: navColumn2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 4

        property bool _anyPlaylistActive: leftpageRectangle.activePlaylistGid !== ""

        // “我的歌单”可展开表头（点击只展开/收起，不再跳独立页面）
        Rectangle {
            id: myPlaylistsHeader
            width: parent.width - 24
            height: 44
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            // hover 改为文字/图标变亮（背景保持透明，渐变下无块状覆盖层）
            color: navColumn2._anyPlaylistActive
                   ? AppTheme.accent
                   : "transparent"

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                NavIcon {
                    iconType: "playlist"
                    selected: navColumn2._anyPlaylistActive
                    iconColor: navColumn2._anyPlaylistActive ? AppTheme.iconActive : (headerMA.containsMouse ? AppTheme.textPrimary : AppTheme.iconNav)
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("我的歌单")
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: navColumn2._anyPlaylistActive ? AppTheme.textPrimary : (headerMA.containsMouse ? AppTheme.textPrimary : AppTheme.textSecondary)
                }
            }

            // 展开/收起指示箭头（旋转动画）
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "▸"
                color: AppTheme.textMuted
                font.pixelSize: 18
                font.bold: true
                rotation: leftpageRectangle.playlistsExpanded ? 90 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: headerMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    leftpageRectangle.playlistsExpanded = !leftpageRectangle.playlistsExpanded;
                    // 首次展开若无数据，触发一次拉取
                    if (leftpageRectangle.playlistsExpanded
                            && leftpageRectangle.userPlaylists.length === 0
                            && userManager.isLoggedIn)
                        userManager.fetchUserPlaylist(1, 30);
                }
            }

        }

        // 展开后：用户歌单子项列表（点击直接进详情页）。
        // 歌单较多时列表自身滚动（占满 表头 与 最近播放 之间的空间），导航项保持固定。
        ListView {
            id: playlistList
            width: parent.width
            height: parent.height - 44 - 44 - 8   // 减去 表头 44 + 最近播放 44 + 间距
            clip: true
            spacing: 2
            visible: leftpageRectangle.playlistsExpanded
            model: leftpageRectangle.userPlaylists

            ScrollBar.vertical: ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 5
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    visible: parent.active
                    width: 5
                    radius: 2.5
                    color: AppTheme.scrollbarColor
                }
            }

            delegate: Rectangle {
                id: playlistChild
                required property var modelData
                required property int index
                width: parent.width - 24
                height: 38
                radius: 10
                anchors.horizontalCenter: parent.horizontalCenter
                property bool isActive: leftpageRectangle.activePlaylistGid === playlistChild.modelData.global_collection_id
                // hover/激活改为文字加粗变亮（背景保持透明，渐变下无块状覆盖层）
                color: "transparent"

                Row {
                    spacing: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 38
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 5
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter
                        color: AppTheme.bgCard
                        Image {
                            anchors.fill: parent
                            source: playlistChild.modelData.pic
                                    ? playlistChild.modelData.pic.replace("{size}", "80") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Text {
                        width: 64
                        text: playlistChild.modelData.name || qsTr("未命名歌单")
                        font.pixelSize: AppTheme.fontSizeBody
                        font.family: AppTheme.fontFamily
                        font.bold: playlistChild.isActive
                        color: (playlistChild.isActive || childMA.containsMouse) ? AppTheme.textPrimary : AppTheme.textSecondary
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (playlistChild.modelData.count || 0)
                        font.pixelSize: AppTheme.fontSizeCaption
                        font.family: AppTheme.fontFamily
                        color: AppTheme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: childMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 收藏的歌单是空壳（自己的壳里没有歌曲），
                        // 数据源用原歌单 gid（list_create_gid）；自己创建的歌单没有该字段，退回壳 gid
                        var gid = playlistChild.modelData.list_create_gid
                                  || playlistChild.modelData.global_collection_id
                                  || "";
                        console.log("[Leftpage] open playlist, gid:", gid, "name:", playlistChild.modelData.name)
                        if (gid === "")
                            return;
                        leftpageRectangle.activePlaylistGid = gid;
                        // 打开歌单详情时清掉静态导航高亮（discover/together/recent），
                        // 只高亮当前歌单子项 + "我的歌单"分区头，避免与"最近播放"等同时高亮
                        leftpageRectangle.currentIndex = -1;
                        var pic = (playlistChild.modelData.pic || "").replace("{size}", "200");
                        BasicConfig.openPlaylistDetail(
                            gid,
                            playlistChild.modelData.name || qsTr("歌单"),
                            pic,
                            "");
                    }
                }


                scale: childMA.containsMouse && !playlistChild.isActive ? 1.02 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic }
                }
            }
        }

        // 最近播放（保持普通导航项）
        Rectangle {
            id: recentItem
            width: parent.width - 24
            height: 44
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            property bool isSelected: leftpageRectangle.currentIndex === 4
            // hover 改为文字/图标变亮（背景保持透明，渐变下无块状覆盖层）
            color: recentItem.isSelected ? AppTheme.accent : "transparent"

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                NavIcon {
                    iconType: "recent"
                    selected: recentItem.isSelected
                    iconColor: recentItem.isSelected ? AppTheme.iconActive : (recentMA.containsMouse ? AppTheme.textPrimary : AppTheme.iconNav)
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("最近播放")
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: recentItem.isSelected ? AppTheme.textPrimary : (recentMA.containsMouse ? AppTheme.textPrimary : AppTheme.textSecondary)
                }
            }

            MouseArea {
                id: recentMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    leftpageRectangle.activePlaylistGid = "";
                    if (leftpageRectangle.currentIndex !== 4) {
                        leftpageRectangle.currentIndex = 4;
                        BasicConfig.pushPage("qrc:/Src/ComponentPage/RecentlyPlayed.qml");
                    }
                }
            }


            scale: recentMA.containsMouse && !recentItem.isSelected ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic }
            }
        }

        // 听歌历史（云端同步）
        Rectangle {
            id: historyItem
            width: parent.width - 24
            height: 44
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            property bool isSelected: leftpageRectangle.currentIndex === 5
            color: historyItem.isSelected ? AppTheme.accent : "transparent"

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                NavIcon {
                    iconType: "history"
                    selected: historyItem.isSelected
                    iconColor: historyItem.isSelected ? AppTheme.iconActive : (historyMA.containsMouse ? AppTheme.textPrimary : AppTheme.iconNav)
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("听歌历史")
                    font.pixelSize: AppTheme.fontSizeBodyLg
                    font.family: AppTheme.fontFamily
                    font.bold: true
                    color: historyItem.isSelected ? AppTheme.textPrimary : (historyMA.containsMouse ? AppTheme.textPrimary : AppTheme.textSecondary)
                }
            }

            MouseArea {
                id: historyMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    leftpageRectangle.activePlaylistGid = "";
                    if (leftpageRectangle.currentIndex !== 5) {
                        leftpageRectangle.currentIndex = 5;
                        BasicConfig.pushPage("qrc:/Src/ComponentPage/HistoryPage.qml");
                    }
                }
            }

            scale: historyMA.containsMouse && !historyItem.isSelected ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }
}
