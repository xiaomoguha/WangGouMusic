pragma ComponentBehavior: Bound
import QtQuick 2.15
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

    // 第一组导航
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
                color: leftpageRectangle.currentIndex === index ? AppTheme.accent : (navMouseArea.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

                property bool isSelected: leftpageRectangle.currentIndex === index

                Row {
                    spacing: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    NavIcon {
                        iconType: navColumn.navList[navItemRect.index].iconType
                        selected: navItemRect.isSelected
                        iconColor: navItemRect.isSelected ? AppTheme.iconActive : AppTheme.iconNav
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
                        color: AppTheme.textPrimary
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

                Behavior on color {
                    ColorAnimation {
                        duration: AppTheme.animFast
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

    // 第二组导航
    Column {
        id: navColumn2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: navColumn.bottom
        anchors.topMargin: 20
        spacing: 4

        property bool _anyPlaylistActive: leftpageRectangle.activePlaylistGid !== ""

        // “我的歌单”可展开表头（点击只展开/收起，不再跳独立页面）
        Rectangle {
            id: myPlaylistsHeader
            width: parent.width - 24
            height: 44
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            color: navColumn2._anyPlaylistActive
                   ? AppTheme.accent
                   : (headerMA.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                NavIcon {
                    iconType: "playlist"
                    selected: navColumn2._anyPlaylistActive
                    iconColor: navColumn2._anyPlaylistActive ? AppTheme.iconActive : AppTheme.iconNav
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
                    color: AppTheme.textPrimary
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

            Behavior on color {
                ColorAnimation { duration: AppTheme.animFast }
            }
        }

        // 展开后：用户歌单子项列表，点击直接进详情页（复用主页推荐歌单详情样式）
        Repeater {
            model: leftpageRectangle.playlistsExpanded ? leftpageRectangle.userPlaylists : []

            delegate: Rectangle {
                id: playlistChild
                required property var modelData
                required property int index
                width: parent.width - 24
                height: 38
                radius: 10
                anchors.horizontalCenter: parent.horizontalCenter
                property bool isActive: leftpageRectangle.activePlaylistGid === playlistChild.modelData.global_collection_id
                color: playlistChild.isActive
                       ? AppTheme.bgNavHover
                       : (childMA.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

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
                        color: playlistChild.isActive ? AppTheme.textPrimary : AppTheme.textSecondary
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
                        var gid = playlistChild.modelData.global_collection_id || "";
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

                Behavior on color {
                    ColorAnimation { duration: AppTheme.animFast }
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
            property bool isSelected: leftpageRectangle.currentIndex === 3
            color: recentItem.isSelected ? AppTheme.accent : (recentMA.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar)

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                NavIcon {
                    iconType: "recent"
                    selected: recentItem.isSelected
                    iconColor: recentItem.isSelected ? AppTheme.iconActive : AppTheme.iconNav
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
                    color: AppTheme.textPrimary
                }
            }

            MouseArea {
                id: recentMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    leftpageRectangle.activePlaylistGid = "";
                    if (leftpageRectangle.currentIndex !== 3) {
                        leftpageRectangle.currentIndex = 3;
                        BasicConfig.pushPage("qrc:/Src/ComponentPage/RecentlyPlayed.qml");
                    }
                }
            }

            Behavior on color {
                ColorAnimation { duration: AppTheme.animFast }
            }

            scale: recentMA.containsMouse && !recentItem.isSelected ? 1.03 : 1.0
            Behavior on scale {
                NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }

    // 检查更新按钮（底部）
    Rectangle {
        id: updateBtn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        anchors.bottomMargin: 32
        height: 40
        radius: 10
        color: updateMouseArea.containsMouse ? AppTheme.bgNavHover : AppTheme.bgSidebar

        Row {
            spacing: 8
            anchors.centerIn: parent

            Text {
                text: "\u21BB"
                color: AppTheme.textMuted
                font.pixelSize: AppTheme.fontSizeTitle
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "检查更新"
                color: AppTheme.textMuted
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: appUpdater ? "v" + appUpdater.currentVersion : ""
                color: AppTheme.textDim
                font.pixelSize: AppTheme.fontSizeCaption
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: updateMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (appUpdater) {
                    root.autoCheckUpdate = false;
                    appUpdater.checkForUpdate();
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: AppTheme.animFast
            }
        }
    }
}
