import QtQuick 2.15
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../BasicConfig"
Row {
    Rectangle{
        id:backforword
        width: 22
        height: 30
        color: "transparent"
        radius: 4
        border.width: 2
        border.color: "#2b2b31"
        Image {
            id: leftline
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            scale: 1.1
            source: "qrc:/image/left_line.png"
            layer.effect: ColorOverlay{
                source:leftline
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
                onClicked: {
                    BasicConfig.popPage()
                }
            }
        }
    }
    TextField{
        id:searchTextField
        width: 240
        height: backforword.height
        placeholderText:"周杰伦"
        color: "white"
        palette.placeholderText: "gray"
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: 16
        font.family: "黑体"
        leftPadding:35
        onPressed:
        {
            seachPop.open()
            ineer.gradientStopPos = 0
        }
        onAccepted:
        {
            BasicConfig.searchKeyword = text
            BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml")
            BasicConfig.indexchange(-1)
            seachPop.close()
            var isExist = false
            for (var i = 0; i < searchsingmodel.count; i++) {
                if (searchsingmodel.get(i).songName === text) {
                    isExist = true
                    break
                }
            }
            if (!isExist) {
                searchsingmodel.append({"songName": text})
            }
        }
        onTextChanged: {
            console.log("文本已修改:", text)
        }
        Connections{
            target:BasicConfig
            function onBkanAreaClicked()
            {
                ineer.gradientStopPos = 1
            }
        }
        background: Rectangle{//外部矩形
            anchors.fill: parent
            radius:8
            gradient: Gradient{
                orientation: Gradient.Horizontal
                GradientStop{color: "#21283d";position: 0}
                GradientStop{color: "#382635";position: 1}
            }
            Rectangle{//内部矩形（套娃出边框渐变）
                id:ineer
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                property real gradientStopPos: 1
                gradient: Gradient{
                    orientation: Gradient.Horizontal
                    GradientStop{color: "#1a1d29";position: 0}
                    GradientStop{color: "#241c26";position: ineer.gradientStopPos}
                }
            }
        }
        Image {
            id: searchicon
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            width:18
            height: 18
            fillMode: Image.PreserveAspectFit
            source: "qrc:/image/search_line.png"
            layer.effect: ColorOverlay{
                source:searchicon
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
                onClicked: {
                    const keyword = searchTextField.text === "" ? searchTextField.placeholderText : searchTextField.text
                    BasicConfig.searchKeyword = keyword
                    BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml")
                    BasicConfig.indexchange(-1)
                    var isExist = false
                    for (var i = 0; i < searchsingmodel.count; i++) {
                        if (searchsingmodel.get(i).songName === keyword) {
                            isExist = true
                            break
                        }
                    }
                    if (!isExist) {
                        searchsingmodel.append({"songName": keyword})
                    }
                }
            }
        }
    }
    ListModel{
        id:searchsingmodel
    }
    Popup{
        id:seachPop
        width: parent.width
        height: 500
        y:searchTextField.height + 10
        background: Rectangle {
            color: "#2d2d37"
            border.width: 0
            radius:10
        }
        contentItem:Flickable{
                id: flickView
                anchors.fill: parent
                clip: true
                contentHeight: contentColumn.height
                ScrollBar.vertical: ScrollBar{
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    width: 10
                    contentItem: Rectangle{
                        visible: parent.active
                        width: 10
                        radius: 4
                        color: "#42424b"
                    }
                }
                Column{
                    id: contentColumn
                    spacing: 20
                    padding: 30
                    width:seachPop.width
                    Item {
                        id: historyitem
                        width: parent.width - 60
                        height: Math.max(searchtext.implicitHeight, deleteicn.height)
                        visible: searchsingmodel.count === 0 ? false : true
                        Text {
                            id: searchtext
                            text: qsTr("搜索历史")
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#7f7f85"
                            font.family: "黑体"
                            font.pixelSize: 15
                        }
                        Image {
                            id: deleteicn
                            fillMode: Image.PreserveAspectFit
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: "qrc:/image/delete_line.png"
                            layer.effect: ColorOverlay{
                                source:deleteicn
                                color:"white"
                            }
                            MouseArea{
                                hoverEnabled: true
                                anchors.fill: parent
                                onEntered: {
                                    parent.layer.enabled = true
                                }
                                onExited: {
                                    parent.layer.enabled = false
                                }
                                onClicked: {
                                    searchsingmodel.clear()
                                }
                            }
                        }
                    }
                    Flow{
                        id:songflow
                        width: parent.width - 60
                        spacing: 10
                        Repeater{
                            id:historyRep
                            model: searchsingmodel
                            property bool showall: false
                            delegate:Rectangle{
                                width: datalabel.implicitWidth+20
                                height: 40
                                border.width: 1
                                border.color: "#45454e"
                                color: "#2d2d37"
                                radius: 15
                                visible: index < (historyRep.showall?10:7)
                                Label{
                                    id:datalabel
                                    text: songName === undefined?"":(historyRep.showall?(index === 9?">":songName):(index === 6?">":songName))
                                    rotation: historyRep.showall?(index === 9?-90:0):(index === 6?90:0)
                                    font.pixelSize: 16
                                    anchors.centerIn: parent
                                    color: "#ddd"
                                    font.family: "黑体"
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        datalabel.color = "white"
                                        parent.color = "#393943"
                                        cursorShape = Qt.PointingHandCursor
                                    }
                                    onExited: {
                                        datalabel.color = "#ddd"
                                        parent.color = "#2d2d37"
                                        cursorShape = Qt.ArrowCursor
                                    }
                                    onClicked: {
                                        if(historyRep.showall && index === 9)
                                        {
                                            historyRep.showall = false
                                        }
                                        else if(!historyRep.showall && index === 6)
                                        {
                                            historyRep.showall = true
                                        }
                                        else
                                        {
                                            searchTextField.text = songName
                                            BasicConfig.searchKeyword = songName
                                            BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml")
                                            seachPop.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text{
                        id:hotsearchtext
                        text: "热搜榜"
                        font.family: "黑体"
                        font.pixelSize: 15
                        color: "#7f7f85"
                    }
                    Rectangle {
                        width: parent.width
                        height: -35
                    }
                    Column {
                        id: hostsearchColumn
                        spacing: 5
                        width: parent.width - 60
                        Repeater{
                            model: hostSearch ? hostSearch.items : []
                            delegate: Rectangle{
                                color: "transparent"
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 38
                                radius: 5
                                Label{
                                    id:hotsearchindexLabel
                                    anchors.left: parent.left
                                    width: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 16
                                    font.family: "黑体"
                                    color: index<3?"#eb4d44":"#818187"
                                    text: String(index + 1)
                                }
                                Label{
                                    id:hotsearchLabel
                                    anchors.left:hotsearchindexLabel.right
                                    anchors.leftMargin: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 16
                                    font.family: "黑体"
                                    color: "#818187"
                                    text: modelData.keyword
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        parent.color = "#393943"
                                        cursorShape = Qt.PointingHandCursor
                                    }
                                    onExited: {
                                        parent.color = "#2d2d37"
                                        cursorShape = Qt.ArrowCursor
                                    }
                                    onClicked: {
                                        searchTextField.text = modelData.keyword
                                        BasicConfig.searchKeyword = modelData.keyword
                                        BasicConfig.pushsearchsongPage("qrc:/Src/ComponentPage/SearchresultPage.qml")
                                        var isExist = false
                                        for (var i = 0; i < searchsingmodel.count; i++) {
                                            if (searchsingmodel.get(i).songName === modelData.keyword) {
                                                isExist = true
                                                break
                                            }
                                        }
                                        if (!isExist) {
                                            searchsingmodel.append({"songName": modelData.keyword})
                                        }
                                        seachPop.close()
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
    Rectangle{
        id:audiobuttom
        height: backforword.height
        width: height
        radius: 8
        color: "#241c26"
        border.width: 1
        border.color: "#36262f"
        Image {
            id: audioline
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            scale: 0.8
            source: "qrc:/image/audio _line.png"
            layer.effect: ColorOverlay{
                source:audioline
                color:"white"
            }
            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: {
                    parent.layer.enabled = true
                }
                onExited: {
                    parent.layer.enabled = false
                }
            }
        }
    }
}
