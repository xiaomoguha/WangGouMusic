import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
import NetworkRequest 1.0

Row {
    id: root
    spacing: 10

    // 搜索建议请求器
    HttpGetRequester {
        id: suggestRequester
        onDataReceived: function (data) {
            try {
                var json = JSON.parse(data);
                if (json.status === 1 && json.data && json.data.length > 0) {
                    suggestModel.clear();
                    var records = json.data[0].RecordDatas;
                    for (var i = 0; i < Math.min(records.length, 10); i++) {
                        suggestModel.append({
                            "hintInfo": records[i].HintInfo,
                            "hot": records[i].Hot
                        });
                    }
                }
            } catch (e) {
                console.log("解析搜索建议失败:", e);
            }
        }
        onRequestFailed: function (error) {
            console.log("搜索建议请求失败:", error);
        }
    }

    // 防抖定时器
    Timer {
        id: debounceTimer
        interval: 300
        repeat: false
        onTriggered: {
            var keyword = searchTextField.text.trim();
            if (keyword.length > 0) {
                var encodedKeyword = encodeURIComponent(keyword);
                suggestRequester.fetchData("https://xjt-togethertracks.top/api/search/suggest?keywords=" + encodedKeyword);
            } else {
                suggestModel.clear();
            }
        }
    }

    // 搜索建议数据模型
    ListModel {
        id: suggestModel
    }

    // 搜索框
    Rectangle {
        id: searchContainer
        width: 260
        height: 36
        radius: 18
        color: AppTheme.bgInput
        border.width: 1
        border.color: searchTextField.activeFocus ? AppTheme.borderFocus : AppTheme.borderDefault

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            // 搜索图标
            Image {
                id: searchicon
                source: "qrc:/image/search_line.png"
                width: 16
                height: 16
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                layer.enabled: true
                layer.effect: ColorOverlay {
                    source: searchicon
                    color: AppTheme.iconSearch
                }
            }

            TextField {
                id: searchTextField
                width: parent.width - searchicon.width - parent.spacing
                height: parent.height
                placeholderText: "搜索歌曲、歌手"
                color: AppTheme.textPrimary
                palette.placeholderText: AppTheme.textPlaceholder
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                font.family: "黑体"
                background: Rectangle {
                    color: "transparent"
                }
                onTextChanged: {
                    // 文本变化时触发防抖请求
                    debounceTimer.restart();
                }
                onPressed: {
                    seachPop.open();
                }
                onAccepted: {
                    BasicConfig.searchKeyword = text;
                    BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml");
                    BasicConfig.indexchange(-1);
                    seachPop.close();
                    suggestModel.clear();
                    var isExist = false;
                    for (var i = 0; i < searchsingmodel.count; i++) {
                        if (searchsingmodel.get(i).songName === text) {
                            isExist = true;
                            break;
                        }
                    }
                    if (!isExist) {
                        searchsingmodel.append({
                            "songName": text
                        });
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onPressed: {
                searchTextField.forceActiveFocus();
                seachPop.open();
            }
        }
    }
    ListModel {
        id: searchsingmodel
    }
    Popup {
        id: seachPop
        width: parent.width
        height: 500
        y: searchTextField.height + 10
        background: Rectangle {
            color: AppTheme.bgSearchPopup
            border.width: 1
            border.color: AppTheme.borderDefault
            radius: 10
        }
        contentItem: Flickable {
            id: flickView
            anchors.fill: parent
            clip: true
            contentHeight: contentColumn.height
            ScrollBar.vertical: ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: 5
                width: 10
                contentItem: Rectangle {
                    visible: parent.active
                    width: 10
                    radius: 4
                    color: AppTheme.scrollbarColor
                }
            }
            Column {
                id: contentColumn
                spacing: 20
                padding: 30
                width: seachPop.width

                // 搜索建议列表（输入文字时显示）
                Column {
                    id: suggestColumn
                    width: parent.width - 60
                    spacing: 5
                    visible: suggestModel.count > 0

                    Repeater {
                        model: suggestModel
                        delegate: Rectangle {
                            width: suggestColumn.width
                            height: 40
                            radius: 8
                            color: suggestMouseArea.containsMouse ? AppTheme.bgSuggestionHover : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                // 搜索图标
                                Image {
                                    id: suggestIcon
                                    source: "qrc:/image/search_line.png"
                                    width: 16
                                    height: 16
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        source: suggestIcon
                                        color: AppTheme.iconSearch
                                    }
                                }

                                // 高亮文本组件
                                Text {
                                    id: suggestText
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.RichText
                                    font.pixelSize: 15
                                    font.family: "黑体"
                                    color: AppTheme.textPrimary
                                    text: {
                                        var keyword = searchTextField.text;
                                        var hint = hintInfo || "";
                                        if (keyword.length === 0)
                                            return hint;
                                        var idx = hint.toLowerCase().indexOf(keyword.toLowerCase());
                                        if (idx >= 0) {
                                            var before = hint.substring(0, idx);
                                            var match = hint.substring(idx, idx + keyword.length);
                                            var after = hint.substring(idx + keyword.length);
                                            return before + '<font color="' + AppTheme.accent.toString() + '">' + match + '</font>' + after;
                                        }
                                        return hint;
                                    }
                                }
                            }

                            MouseArea {
                                id: suggestMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchTextField.text = hintInfo;
                                    BasicConfig.searchKeyword = hintInfo;
                                    BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml");
                                    seachPop.close();
                                    suggestModel.clear();
                                    // 添加到搜索历史
                                    var isExist = false;
                                    for (var i = 0; i < searchsingmodel.count; i++) {
                                        if (searchsingmodel.get(i).songName === hintInfo) {
                                            isExist = true;
                                            break;
                                        }
                                    }
                                    if (!isExist) {
                                        searchsingmodel.append({
                                            "songName": hintInfo
                                        });
                                    }
                                }
                            }
                        }
                    }
                }

                // 分隔线（有搜索建议时显示）
                Rectangle {
                    width: parent.width - 60
                    height: 1
                    color: AppTheme.borderDefault
                    visible: suggestModel.count > 0 && searchsingmodel.count > 0
                }

                Item {
                    id: historyitem
                    width: parent.width - 60
                    height: Math.max(searchtext.implicitHeight, deleteicn.height)
                    visible: searchsingmodel.count > 0 && suggestModel.count === 0
                    Text {
                        id: searchtext
                        text: qsTr("搜索历史")
                        anchors.verticalCenter: parent.verticalCenter
                        color: AppTheme.textSearchKeyword
                        font.family: "黑体"
                        font.pixelSize: 15
                    }
                    // 清除历史按钮
                    Rectangle {
                        id: deleteBtn
                        width: 26
                        height: 26
                        radius: 13
                        color: deleteMouseArea.containsMouse ? AppTheme.iconButtonHover : "transparent"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: deleteicn
                            anchors.centerIn: parent
                            source: "qrc:/image/delete_line.png"
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: deleteicn
                                color: AppTheme.iconDefault
                            }
                        }

                        MouseArea {
                            id: deleteMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchsingmodel.clear();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }
                Flow {
                    id: songflow
                    width: parent.width - 60
                    spacing: 10
                    visible: suggestModel.count === 0
                    Repeater {
                        id: historyRep
                        model: searchsingmodel
                        property bool showall: false
                        delegate: Rectangle {
                            width: datalabel.implicitWidth + 20
                            height: 40
                            border.width: 1
                            border.color: AppTheme.borderDefault
                            color: AppTheme.bgSearchPopup
                            radius: 15
                            visible: index < (historyRep.showall ? 10 : 7)
                            Label {
                                id: datalabel
                                text: songName === undefined ? "" : (historyRep.showall ? (index === 9 ? ">" : songName) : (index === 6 ? ">" : songName))
                                rotation: historyRep.showall ? (index === 9 ? -90 : 0) : (index === 6 ? 90 : 0)
                                font.pixelSize: 16
                                anchors.centerIn: parent
                                color: AppTheme.textSecondary
                                font.family: "黑体"
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    datalabel.color = AppTheme.textPrimary;
                                    parent.color = AppTheme.bgHistoryTagHover;
                                    cursorShape = Qt.PointingHandCursor;
                                }
                                onExited: {
                                    datalabel.color = AppTheme.textSecondary;
                                    parent.color = AppTheme.bgHistoryTag;
                                    cursorShape = Qt.ArrowCursor;
                                }
                                onClicked: {
                                    if (historyRep.showall && index === 9) {
                                        historyRep.showall = false;
                                    } else if (!historyRep.showall && index === 6) {
                                        historyRep.showall = true;
                                    } else {
                                        searchTextField.text = songName;
                                        BasicConfig.searchKeyword = songName;
                                        BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml");
                                        seachPop.close();
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    id: hotsearchtext
                    text: "热搜榜"
                    font.family: "黑体"
                    font.pixelSize: 15
                    color: AppTheme.textSearchKeyword
                    visible: suggestModel.count === 0
                }
                Rectangle {
                    width: parent.width
                    height: -35
                    visible: suggestModel.count === 0
                }
                Column {
                    id: hostsearchColumn
                    spacing: 5
                    width: parent.width - 60
                    visible: suggestModel.count === 0
                    Repeater {
                        model: hostSearch ? hostSearch.items : []
                        delegate: Rectangle {
                            color: "transparent"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            radius: 5
                            Label {
                                id: hotsearchindexLabel
                                anchors.left: parent.left
                                width: 12
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                font.family: "黑体"
                                color: index < 3 ? AppTheme.textHotIndex : AppTheme.textNormalIndex
                                text: String(index + 1)
                            }
                            Label {
                                id: hotsearchLabel
                                anchors.left: hotsearchindexLabel.right
                                anchors.leftMargin: 15
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                font.family: "黑体"
                                color: AppTheme.textNormalIndex
                                text: modelData.keyword
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    parent.color = AppTheme.bgSuggestionHover;
                                    cursorShape = Qt.PointingHandCursor;
                                }
                                onExited: {
                                    parent.color = AppTheme.bgSearchPopup;
                                    cursorShape = Qt.ArrowCursor;
                                }
                                onClicked: {
                                    searchTextField.text = modelData.keyword;
                                    BasicConfig.searchKeyword = modelData.keyword;
                                    BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml");
                                    var isExist = false;
                                    for (var i = 0; i < searchsingmodel.count; i++) {
                                        if (searchsingmodel.get(i).songName === modelData.keyword) {
                                            isExist = true;
                                            break;
                                        }
                                    }
                                    if (!isExist) {
                                        searchsingmodel.append({
                                            "songName": modelData.keyword
                                        });
                                    }
                                    seachPop.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
