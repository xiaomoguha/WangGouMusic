import QtQuick 2.15
 import QtQuick.Controls
Item {
    objectName: "HomePage"
    id:homePageitem
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    Flickable{
        id: recommandflickView
        anchors.fill: parent
        anchors.topMargin: 5
        clip: true
        contentHeight: recommandpagecolimn.height
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
            id:recommandpagecolimn
            anchors.left:parent.left
            anchors.right:parent.right
            spacing: 15
            // Component.onCompleted: {
            //     console.log("Column initial height:", height)
            // }
            Item{
                width: 1
                height: 15
            }
            Item{
                id: manitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:manText
                    text: "嫚姐专属接口，请立马V我50"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: manText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: manText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: manText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(6);
                            //恢复到普通用户列表
                            playlistmanager.returnplaylistrange();
                        }
                    }
                }
                Grid {
                    id:mangrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: manText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.manitemsqml:[]
                        Item {
                            width: mangrid.width / 3 - (mangrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.fill: parent
                                radius: 8
                                Image {
                                    id: manimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:mancolumn
                                    anchors.left: manimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: manimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13
                                        color: playlistmanager?(playlistmanager.nowplaylistrange === 6 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11
                                        color: playlistmanager?(playlistmanager.nowplaylistrange === 6 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:manrow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 6)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        id: addloveImage
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 6 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#27272e"
                                        if(!(playlistmanager.nowplaylistrange === 6 && playlistmanager.currentIndex === index))
                                        {
                                            manrow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        manrow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(6,index);
                                        manrow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item {
                id: jingxuanhaogeitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:vipText
                    text: "精选好歌随心听"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: vipText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: vipText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: vipText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(0);
                        }
                    }
                }
                Grid {
                    id:recommandsonginfogrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: vipText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.SelectedGoodSongsitemsqml:[]
                        Item {
                            width: recommandsonginfogrid.width / 3 - (recommandsonginfogrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.fill: parent
                                radius: 8
                                Image {
                                    id: songcoverimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:recommandcolumn
                                    anchors.left: songcoverimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: songcoverimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 0 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 0 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:recommandadditemsrow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 0)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 0 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#27272e"
                                        if(!(playlistmanager.nowplaylistrange === 0 && playlistmanager.currentIndex === index))
                                        {
                                            recommandadditemsrow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        recommandadditemsrow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(0,index);
                                        recommandadditemsrow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item{
                id: recommanddataitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:jingdianhuanjiuText
                    text: "经典怀旧金曲"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: jingdianhuanjiuText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: jingdianhuanjiuText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: jingdianhuanjiuText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(1);
                        }
                    }
                }
                Grid {
                    id:jingdianhuaijiugrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: jingdianhuanjiuText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.Classicnostalgicgoldenoldiesitemsqml:[]
                        Item {
                            width: jingdianhuaijiugrid.width / 3 - (jingdianhuaijiugrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.centerIn: parent
                                radius: 8
                                Image {
                                    id: jingdianhuaijiuimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:jingdianhuaijiucolumn
                                    anchors.left: jingdianhuaijiuimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: jingdianhuaijiuimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 1 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 1 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:jingdianhuaijiuadditemsrow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 1)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 1 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#212127"
                                        if(!(playlistmanager.nowplaylistrange === 1 && playlistmanager.currentIndex === index))
                                        {
                                            jingdianhuaijiuadditemsrow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        jingdianhuaijiuadditemsrow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(1,index);
                                        jingdianhuaijiuadditemsrow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item{
                id: remenhaogeitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:remenhaogeText
                    text: "热门好歌精选"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: remenhaogeText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: remenhaogeText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: remenhaogeText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(2);
                        }
                    }
                }
                Grid {
                    id:remenhaogegrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: remenhaogeText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.SelectedPopularHitsitemsqml:[]
                        Item {
                            width: remenhaogegrid.width / 3 - (remenhaogegrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.centerIn: parent
                                radius: 8
                                Image {
                                    id: remenhaogeimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:remenhaogecolumn
                                    anchors.left: remenhaogeimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: remenhaogeimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 2 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 2 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:remenhaogerow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 2)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 2 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#212127"
                                        if(!(playlistmanager.nowplaylistrange === 2 && playlistmanager.currentIndex === index))
                                        {
                                            remenhaogerow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        remenhaogerow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(2,index);
                                        remenhaogerow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item{
                id: xiaozongitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:xiaozongText
                    text: "小众宝藏佳作"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: xiaozongText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: xiaozongText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: xiaozongText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(3);
                        }
                    }
                }
                Grid {
                    id:xiaozonggrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: xiaozongText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.Rareandexquisitemasterpiecesitemsqml:[]
                        Item {
                            width: xiaozonggrid.width / 3 - (xiaozonggrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.centerIn: parent
                                radius: 8
                                Image {
                                    id: xiaozongimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:xiaozongcolumn
                                    anchors.left: xiaozongimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: xiaozongimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 3 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 3 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:xiaozongrow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 3)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 3 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#212127"
                                        if(!(playlistmanager.nowplaylistrange === 3 && playlistmanager.currentIndex === index))
                                        {
                                            xiaozongrow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        xiaozongrow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(3,index);
                                        xiaozongrow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item{
                id: caoliuitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:caoliuText
                    text: "潮流尝鲜"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: caoliuText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: caoliuText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: caoliuText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(4);
                        }
                    }
                }
                Grid {
                    id:caoliugrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: caoliuText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.Keepingupwiththelatesttrendsitemsqml:[]
                        Item {
                            width: caoliugrid.width / 3 - (caoliugrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.centerIn: parent
                                radius: 8
                                Image {
                                    id: caoliuimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:caoliucolumn
                                    anchors.left: caoliuimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: caoliuimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 4 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 4 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:caoliurow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 4)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 4 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#212127"
                                        if(!(playlistmanager.nowplaylistrange === 4 && playlistmanager.currentIndex === index))
                                        {
                                            caoliurow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        caoliurow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(4,index);
                                        caoliurow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item{
                id: vipitems
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 0.03*root.width
                anchors.rightMargin: 0.03*root.width
                height: childrenRect.height
                Text{
                    id:viprecommandText
                    text: "VIP歌曲专属推荐"
                    font.family: "黑体"
                    font.pixelSize: 18
                    color: "white"
                }
                Rectangle{
                    width: 22
                    height: width
                    radius: height/2
                    anchors.left: viprecommandText.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: viprecommandText.verticalCenter
                    color: "#7d7d7d"
                    Image {
                        anchors.fill: parent
                        scale: 0.6
                        source: "qrc:/image/play.png"
                    }
                }
                Rectangle{
                    width: 34
                    height: 34
                    radius: 5
                    color: "#212127"
                    anchors.right: parent.right
                    anchors.verticalCenter: viprecommandText.verticalCenter
                    Image {
                        width: 20
                        height: 20
                        anchors.centerIn: parent
                        source: "qrc:/image/shuaxin.png"
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            parent.color = "#2b2b31"
                        }
                        onExited: {
                            parent.color = "#212127"
                        }
                        onClicked: {
                            recommendation.getdatabygetdatarange(5);
                        }
                    }
                }
                Grid {
                    id:vipgrid
                    width: parent.width
                    columns: 3
                    spacing: 10
                    anchors.left:parent.left
                    anchors.right: parent.right
                    anchors.top: viprecommandText.bottom
                    anchors.topMargin: 20
                    Repeater {
                        model: recommendation?recommendation.ExclusiverecommendationforVIPsongsitemsqml:[]
                        Item {
                            width: vipgrid.width / 3 - (vipgrid.spacing * 2 / 3)
                            height: 60
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                anchors.centerIn: parent
                                radius: 8
                                Image {
                                    id: vipimg
                                    source: modelData.union_cover
                                    height: parent.height-10
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                }
                                Column{
                                    id:vipcolumn
                                    anchors.left: vipimg.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: vipimg.verticalCenter
                                    spacing: 20
                                    Text {
                                        text: modelData.songname
                                        font.pixelSize: 13; color: playlistmanager?(playlistmanager.nowplaylistrange === 5 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                    }
                                    Text {
                                        text: modelData.singername
                                        elide: Text.ElideRight
                                        width: 0.12*root.width
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: 11; color: playlistmanager?(playlistmanager.nowplaylistrange === 5 && playlistmanager.currentIndex === index ? "#e74f50":"white"):"white"
                                        font.family: "黑体"
                                    }
                                }
                                Row{
                                    id:viprow
                                    visible: false
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/playnow.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if(playlistmanager.nowplaylistrange === 5)
                                                {
                                                    playlistmanager.playSongbyindex(index);
                                                }
                                                else
                                                {
                                                    playlistmanager.addandplay(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                                }
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        scale: 0.8
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addplaylist.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                //添加到列表
                                                playlistmanager.addSong(modelData.songname,modelData.songhash,modelData.singername,modelData.union_cover,modelData.album_name,modelData.duration)
                                            }
                                        }
                                    }
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 23
                                        height: 23
                                        source: "qrc:/image/addlove.png"
                                        MouseArea{
                                            hoverEnabled: false
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                AnimatedImage {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    height: 25
                                    source: "qrc:/image/isplaying.gif"
                                    playing: true  // 确保动画自动播放
                                    visible: playlistmanager ? (playlistmanager.nowplaylistrange === 5 && playlistmanager.currentIndex === index) : false
                                }
                                MouseArea{
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    onEntered: {
                                        parent.color = "#212127"
                                        if(!(playlistmanager.nowplaylistrange === 5 && playlistmanager.currentIndex === index))
                                        {
                                            viprow.visible = true
                                        }
                                    }
                                    onExited: {
                                        parent.color = "transparent"
                                        viprow.visible = false
                                    }
                                    onClicked: function(mouse){
                                        mouse.accepted = false // 不截获点击
                                    }
                                    onDoubleClicked: {
                                        playlistmanager.changeplaylistbyrecommandindex(5,index);
                                        viprow.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
