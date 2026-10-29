import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import NetworkRequest 1.0
import "../BasicConfig"

Row {
    id: root
    spacing: 10

    // 弹层真模糊的抓取源：由 Rightpage 注入「弹层背后那一层」（rightPage 整层）
    property Item blurSource: null

    // 弹层内的行 hover：两端淡出的柔光带（不铺实心块），淡入淡出
    component HoverBand: Rectangle {
        id: hoverBand
        property bool active: false
        anchors.fill: parent
        radius: height / 2
        opacity: hoverBand.active ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.12; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.60; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
        }
        Behavior on opacity { NumberAnimation { duration: AppTheme.animFast; easing.type: Easing.OutCubic } }
    }

    // ── 搜索建议请求（防抖 300ms） ──────────────────────────────
    HttpGetRequester {
        id: suggestRequester
        onDataReceived: function (data) {
            try {
                var json = JSON.parse(data);
                if (json.status === 1 && json.data && json.data.length > 0) {
                    suggestModel.clear();
                    var records = json.data[0].RecordDatas;
                    for (var i = 0; i < Math.min(records.length, 10); i++)
                        suggestModel.append({ "hintInfo": records[i].HintInfo });
                    updateSuggestWidth();
                }
            } catch (e) {
                console.log("解析搜索建议失败:", e);
            }
        }
        onRequestFailed: function (error) {
            console.log("搜索建议请求失败:", error);
        }
    }

    Timer {
        id: debounceTimer
        interval: 300
        repeat: false
        onTriggered: {
            var keyword = searchTextField.text.trim();
            if (keyword.length > 0) {
                suggestRequester.fetchData("https://api.special520.com/search/suggest?keywords=" + encodeURIComponent(keyword));
            } else {
                suggestModel.clear();
                suggestMaxWidth = 0;
            }
        }
    }

    ListModel { id: suggestModel }

    TextMetrics {
        id: suggestMetrics
        font.pixelSize: AppTheme.fontSizeBodyLg
        font.family: AppTheme.fontFamily
    }
    property int suggestMaxWidth: 0
    function updateSuggestWidth() {
        var maxW = 0;
        for (var i = 0; i < suggestModel.count; i++) {
            suggestMetrics.text = suggestModel.get(i).hintInfo || "";
            maxW = Math.max(maxW, suggestMetrics.width);
        }
        suggestMaxWidth = maxW;
    }

    // ── 热搜词宽度测量（驱动下拉框动态宽度） ────────────────────
    TextMetrics {
        id: hotMetrics
        font.pixelSize: AppTheme.fontSizeBody
        font.family: AppTheme.fontFamily
    }
    property int hotMaxWidth: 0
    function updateHotWidth() {
        var maxW = 0;
        var items = hostSearch ? hostSearch.items : [];
        for (var i = 0; i < items.length; i++) {
            hotMetrics.text = items[i].keyword || "";
            maxW = Math.max(maxW, hotMetrics.width);
        }
        hotMaxWidth = maxW;
    }
    Connections {
        target: hostSearch
        function onHostsearchitemsChanged() { updateHotWidth(); }
    }

    // 下拉框目标宽度：取「搜索框宽 / 建议词 / 热搜 2 列所需宽」最大值，上限 600
    readonly property int popupTargetWidth: {
        var w = Math.max(searchContainer.width, suggestMaxWidth + 80);
        if (hotMaxWidth > 0)
            w = Math.max(w, 2 * (hotMaxWidth + 40) + 32);
        return Math.min(w, 600);
    }

    // 统一搜索动作：4 条触发路径（回车/建议/历史/热搜）都走这里，保证一致 + 记录历史
    function doSearch(keyword) {
        var kw = (keyword || "").trim();
        if (kw.length === 0)
            return;
        searchTextField.text = kw;
        BasicConfig.searchKeyword = kw;
        BasicConfig.pushSearchSongPage("qrc:/Src/ComponentPage/SearchresultPage.qml");
        BasicConfig.indexChange(-1);
        searchHistory.addSearch(kw);
        seachPop.close();
        suggestModel.clear();
        suggestMaxWidth = 0;
    }

    // 别处发起的搜索（底栏点歌名/歌手名）：统一走 doSearch，跳转/填框/记历史都一致
    Connections {
        target: BasicConfig
        function onRequestSearch(keyword) { doSearch(keyword) }
    }

    // ── 搜索框 ─────────────────────────────────────────────────
    Rectangle {
        id: searchContainer
        width: 260
        height: 36
        radius: 18
        // 沉浸：背景透明融入渐变，只留细边框（聚焦时边框高亮；渐变时边框随背景对比色）
        color: "transparent"
        border.width: 1
        border.color: searchTextField.activeFocus ? AppTheme.borderFocus : (BasicConfig.playlistCoverColor !== ""
            ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
            : AppTheme.borderDefault)
        Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Image {
                id: searchicon
                source: AppIcon.search
                sourceSize: Qt.size(128, 128)
                mipmap: true
                width: 16; height: 16
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: searchicon
                    // 渐变时图标随背景对比色，保证任何封面下都看得清
                    color: BasicConfig.playlistCoverColor !== ""
                        ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                        : AppTheme.iconSearch
                }
            }

            TextField {
                id: searchTextField
                width: parent.width - searchicon.width - clearBtn.width - parent.spacing * 2
                height: parent.height
                placeholderText: "搜索歌曲、歌手"
                // 渐变激活时按背后颜色自动挑白/深字，保证任何封面下都看得清
                color: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.textPrimary
                palette.placeholderText: BasicConfig.playlistCoverColor !== ""
                    ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                    : AppTheme.textPlaceholder
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: AppTheme.fontSizeBodyLg
                font.family: AppTheme.fontFamily
                background: Rectangle { color: "transparent" }
                onTextChanged: debounceTimer.restart();
                onPressed: seachPop.open();
                onAccepted: doSearch(text);
            }

            // 清空按钮（有文本时显示）
            Item {
                id: clearBtn
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter
                opacity: searchTextField.text.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: AppTheme.animFast } }
                Image {
                    id: clearIcon
                    anchors.fill: parent
                    source: AppIcon.close
                    sourceSize: Qt.size(128, 128)
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        source: clearIcon
                        // 渐变时图标随背景对比色
                        color: BasicConfig.playlistCoverColor !== ""
                            ? BasicConfig.contrastText(BasicConfig.playlistCoverColor, AppTheme.bgContent)
                            : AppTheme.iconSearch
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchTextField.text = "";
                        searchTextField.forceActiveFocus();
                        suggestModel.clear();
                        suggestMaxWidth = 0;
                    }
                }
            }
        }

        // 点击左侧图标区域也能聚焦
        MouseArea {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: searchicon.width + parent.anchors.leftMargin
            cursorShape: Qt.IBeamCursor
            onPressed: { searchTextField.forceActiveFocus(); seachPop.open(); }
        }
    }

    // ── 下拉浮层 ───────────────────────────────────────────────
    Popup {
        id: seachPop
        x: 0
        y: searchContainer.height + 8
        width: root.popupTargetWidth
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        transformOrigin: Item.Top
        // 高度随内容自适应，上限 440，超出滚动
        height: Math.min(contentColumn.height + contentColumn.pad * 2, 440)
        onHeightChanged: console.log(">>> seachPop height =", height, "contentColumn.height =", contentColumn.height)
        // 宽度随内容平滑缩放
        Behavior on width { NumberAnimation { duration: AppTheme.animNormal; easing.type: Easing.OutCubic } }
        onAboutToShow: {
            updateHotWidth()
            console.log(">>> popup show: suggestCount =", suggestModel.count,
                        "historyLen =", searchHistory ? searchHistory.history.length : -1,
                        "hotItems =", hostSearch ? hostSearch.items.length : -1,
                        "contentColumn.h =", contentColumn.height)
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: AppTheme.animFast; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1; to: 0.96; duration: AppTheme.animFast; easing.type: Easing.InCubic }
            }
        }

        // ── 真·背景模糊弹层 ────────────────────────────────────────
        // 抓「弹层背后那一层」离屏渲染成纹理 → 高斯模糊 → 圆角遮罩 → 压暗着色。
        // 抓 rightPage 而不是 Window.contentItem：弹层自己就挂在 rightPage 的父链里，
        // 但 recursive:false 时 Qt 会把「抓取源子树内的这个 effect source」渲染成空白，
        // 递归被掐断 —— 实测出图正常（抓整窗反而会把弹层以外的窗口装饰也糊进来）。
        background: Item {
            // 兜底底板：抓取/模糊万一没渲染出来时，弹层依然是可读的深色面板
            Rectangle {
                anchors.fill: parent
                radius: AppTheme.radiusMedium
                color: Qt.rgba(0.07, 0.07, 0.10, 0.9)
            }

            ShaderEffectSource {
                id: backdropCapture
                anchors.fill: parent
                sourceItem: root.blurSource
                live: true               // 背后星空一直在动，抓活的才不会糊住不动
                recursive: false
                sourceRect: {
                    if (!root.blurSource)
                        return Qt.rect(0, 0, 1, 1);
                    // 用 seachPop.x/y 经父项换算，不走 seachPop 自身变换（避开入场缩放影响）
                    var p = Qt.point(seachPop.x, seachPop.y);
                    if (seachPop.parent)
                        p = seachPop.parent.mapToItem(root.blurSource, p.x, p.y);
                    return Qt.rect(p.x, p.y, seachPop.width, seachPop.height);
                }
                visible: false
            }

            FastBlur {
                id: backdropBlur
                anchors.fill: parent
                source: backdropCapture
                radius: 40                // Retina 按设备像素算，视觉半径约为这里的一半
                transparentBorder: false  // 边缘夹取，避免四周糊出一圈透明边
                visible: false
            }

            // 圆角遮罩：模糊只保留在弹层圆角之内
            Rectangle {
                id: backdropMask
                anchors.fill: parent
                radius: AppTheme.radiusMedium
                color: "black"
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: backdropBlur
                maskSource: backdropMask
            }

            // 压暗 + 亮边：模糊之上还要保证文字清晰
            Rectangle {
                anchors.fill: parent
                radius: AppTheme.radiusMedium
                color: Qt.rgba(0.05, 0.05, 0.09, 0.45)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }
        }

        contentItem: Flickable {
            anchors.fill: parent
            clip: true
            contentHeight: contentColumn.height + contentColumn.pad * 2
            ScrollBar.vertical: ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: 4
                width: 8
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 4; color: AppTheme.scrollbarColor }
            }

            Column {
                id: contentColumn
                readonly property int pad: AppTheme.spacingMedium
                x: pad; y: pad
                width: seachPop.width - pad * 2
                spacing: AppTheme.spacingMedium

                // ═══ 建议区（打字时） ═══
                Column {
                    id: suggestArea
                    width: parent.width
                    spacing: 2
                    visible: suggestModel.count > 0

                    // 直达行：搜索 "<当前词>"
                    Rectangle {
                        width: parent.width; height: 40; radius: AppTheme.radiusSmall
                        color: "transparent"
                        HoverBand { active: directHover.containsMouse }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                            transform: Translate {
                                x: directHover.containsMouse ? 4 : 0
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }
                            Image {
                                id: directIcon; source: AppIcon.search; sourceSize: Qt.size(128,128); mipmap: true
                                width: 16; height: 16; fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                layer.enabled: true
                                layer.effect: ColorOverlay { source: directIcon; color: AppTheme.accent }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - directIcon.width - parent.spacing
                                elide: Text.ElideRight
                                textFormat: Text.RichText
                                font { pixelSize: AppTheme.fontSizeBodyLg; family: AppTheme.fontFamily }
                                color: AppTheme.textPrimary
                                text: '搜索 "<font color="' + AppTheme.accent.toString() + '">' + searchTextField.text.trim() + '</font>"'
                            }
                        }
                        MouseArea { id: directHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: doSearch(searchTextField.text) }
                    }

                    // 建议行
                    Repeater {
                        model: suggestModel
                        delegate: Rectangle {
                            width: contentColumn.width; height: 40; radius: AppTheme.radiusSmall
                            color: "transparent"
                            HoverBand { active: suggestHover.containsMouse }
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                transform: Translate {
                                    x: suggestHover.containsMouse ? 4 : 0
                                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                }
                                Image {
                                    id: suggestIcon; source: AppIcon.search; sourceSize: Qt.size(128,128); mipmap: true
                                    width: 16; height: 16; fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    layer.enabled: true
                                    layer.effect: ColorOverlay { source: suggestIcon; color: AppTheme.iconSearch }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - suggestIcon.width - parent.spacing
                                    elide: Text.ElideRight
                                    textFormat: Text.RichText
                                    font { pixelSize: AppTheme.fontSizeBodyLg; family: AppTheme.fontFamily }
                                    color: AppTheme.textPrimary
                                    text: {
                                        var keyword = searchTextField.text.trim();
                                        var hint = hintInfo || "";
                                        if (keyword.length === 0) return hint;
                                        var idx = hint.toLowerCase().indexOf(keyword.toLowerCase());
                                        if (idx >= 0) {
                                            return hint.substring(0, idx)
                                                + '<font color="' + AppTheme.accent.toString() + '">'
                                                + hint.substring(idx, idx + keyword.length) + '</font>'
                                                + hint.substring(idx + keyword.length);
                                        }
                                        return hint;
                                    }
                                }
                            }
                            MouseArea { id: suggestHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: doSearch(hintInfo) }
                        }
                    }
                }

                // ═══ 空闲区：历史 + 热搜（无建议时） ═══
                Column {
                    width: parent.width
                    spacing: AppTheme.spacingMedium
                    visible: suggestModel.count === 0

                    // 搜索历史（有历史才显示）
                    Column {
                        width: parent.width
                        spacing: AppTheme.spacingSmall
                        visible: searchHistory && searchHistory.history.length > 0

                        // 头部：⏱ 搜索历史  +  🗑 清空
                        Item {
                            width: parent.width; height: 22
                            Row {
                                spacing: 6
                                Image {
                                    id: histIcon; source: AppIcon.clock; sourceSize: Qt.size(128,128); mipmap: true
                                    width: 15; height: 15; fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    layer.enabled: true
                                    layer.effect: ColorOverlay { source: histIcon; color: AppTheme.textSearchKeyword }
                                }
                                Text {
                                    text: "搜索历史"
                                    color: AppTheme.textSearchKeyword
                                    font { pixelSize: AppTheme.fontSizeBodyLg; family: AppTheme.fontFamily; bold: true }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Item {
                                width: clearHistIcn.width; height: clearHistIcn.height
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    id: clearHistIcn; source: AppIcon.deleteIcon; sourceSize: Qt.size(128,128); mipmap: true
                                    width: 15; height: 15; fillMode: Image.PreserveAspectFit
                                    layer.enabled: true
                                    layer.effect: ColorOverlay { source: clearHistIcn; color: AppTheme.iconDefault }
                                }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: searchHistory.clearHistory() }
                            }
                        }

                        // 历史标签
                        Flow {
                            width: parent.width
                            spacing: AppTheme.spacingSmall
                            Repeater {
                                model: searchHistory ? searchHistory.history : []
                                delegate: Rectangle {
                                    id: chip
                                    width: chipLabel.implicitWidth + 22; height: 32; radius: 16
                                    // 玻璃底上不再铺不透明灰块：半透明填充 + hover 提亮 + 轻微放大
                                    color: chipBody.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                                    border.width: 1
                                    border.color: chipBody.containsMouse ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.13)
                                    scale: chipBody.containsMouse ? 1.05 : 1
                                    Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on border.color { ColorAnimation { duration: AppTheme.animFast } }
                                    Behavior on scale {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                    }
                                    Text {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: chipBody.containsMouse ? AppTheme.textPrimary : AppTheme.textSecondary
                                        font { pixelSize: AppTheme.fontSizeBody; family: AppTheme.fontFamily }
                                        Behavior on color { ColorAnimation { duration: AppTheme.animFast } }
                                    }
                                    MouseArea { id: chipBody; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: doSearch(modelData) }
                                }
                            }
                        }
                    }

                    // 热搜榜头部
                    Item {
                        width: parent.width; height: 22
                        visible: hostSearch && hostSearch.items && hostSearch.items.length > 0
                        Row {
                            spacing: 6
                            Image {
                                id: hotIcon; source: AppIcon.fire; sourceSize: Qt.size(128,128); mipmap: true
                                width: 15; height: 15; fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                                layer.enabled: true
                                layer.effect: ColorOverlay { source: hotIcon; color: AppTheme.accent }
                            }
                            Text {
                                text: "热搜榜"
                                color: AppTheme.textSearchKeyword
                                font { pixelSize: AppTheme.fontSizeBodyLg; family: AppTheme.fontFamily; bold: true }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // 热搜榜（2 列：紧凑、信息密度高）
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: AppTheme.spacingTiny
                        visible: hostSearch && hostSearch.items && hostSearch.items.length > 0
                        Repeater {
                            model: hostSearch ? hostSearch.items : []
                            delegate: Rectangle {
                                width: (parent.width - parent.spacing) / 2; height: 36; radius: AppTheme.radiusSmall
                                color: "transparent"
                                HoverBand { active: hotHover.containsMouse }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 8
                                    spacing: 8
                                    transform: Translate {
                                        x: hotHover.containsMouse ? 4 : 0
                                        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    }
                                    Text {
                                        width: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        text: String(index + 1)
                                        color: index < 3 ? AppTheme.textHotIndex : AppTheme.textNormalIndex
                                        font { pixelSize: AppTheme.fontSizeBodyLg; family: AppTheme.fontFamily; bold: true }
                                    }
                                    Text {
                                        // cellWidth(parent.parent) - 排名14 - 间距8 - 左边距8 - 右留白8
                                        width: parent.parent.width - 14 - 8 - 8 - 8
                                        elide: Text.ElideRight
                                        text: modelData.keyword
                                        color: AppTheme.textPrimary
                                        font { pixelSize: AppTheme.fontSizeBody; family: AppTheme.fontFamily }
                                    }
                                }
                                MouseArea { id: hotHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: doSearch(modelData.keyword) }
                            }
                        }
                    }
                }
            }
        }
    }
}
