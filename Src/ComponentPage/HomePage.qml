import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Item {
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    /* ===================== 区块配置数据 ===================== */
    // 安全获取推荐数据，避免退出时访问已销毁的 C++ 对象
    function getRecommendModel(getter) {
        return recommendation ? getter() : [];
    }

    property var sectionModel: [
        {
            title: "嫚姐专属接口，请立马V我50",
            range: 6,
            model: getRecommendModel(function () {
                return recommendation.manitemsqml;
            })
        },
        {
            title: "精选好歌随心听",
            range: 0,
            model: getRecommendModel(function () {
                return recommendation.SelectedGoodSongsitemsqml;
            })
        },
        {
            title: "经典怀旧金曲",
            range: 1,
            model: getRecommendModel(function () {
                return recommendation.Classicnostalgicgoldenoldiesitemsqml;
            })
        },
        {
            title: "热门好歌精选",
            range: 2,
            model: getRecommendModel(function () {
                return recommendation.SelectedPopularHitsitemsqml;
            })
        },
        {
            title: "小众宝藏佳作",
            range: 3,
            model: getRecommendModel(function () {
                return recommendation.Rareandexquisitemasterpiecesitemsqml;
            })
        },
        {
            title: "潮流尝鲜",
            range: 4,
            model: getRecommendModel(function () {
                return recommendation.Keepingupwiththelatesttrendsitemsqml;
            })
        },
        {
            title: "VIP歌曲专属推荐",
            range: 5,
            model: getRecommendModel(function () {
                return recommendation.ExclusiverecommendationforVIPsongsitemsqml;
            })
        }
    ]

    /* ===================== 歌曲 delegate ===================== */
    Component {
        id: songDelegate

        Item {
            id: songItem
            width: parent ? parent.width : 0
            height: 60

            property var songData: modelData
            readonly property bool isPlaying: playlistmanager && playlistmanager.currentSonghash === songData.songhash

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: (mouse.hovered || isPlaying) ? "#27272e" : "transparent"

                Image {
                    id: cover
                    source: songData.union_cover
                    width: height
                    height: parent.height - 10
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    asynchronous: true
                    cache: true
                    mipmap: true
                    sourceSize.width: 100
                    sourceSize.height: 100
                }

                Column {
                    id: songInfoColumn
                    anchors.left: cover.right
                    anchors.leftMargin: 10
                    anchors.right: manrow.visible ? manrow.left : parent.right
                    anchors.rightMargin: manrow.visible ? 10 : 50
                    anchors.verticalCenter: cover.verticalCenter
                    spacing: 4

                    Text {
                        text: songData.songname
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: isPlaying ? "#e74f50" : "white"
                    }

                    Text {
                        text: songData.singername
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: isPlaying ? "#e74f50" : "white"
                    }
                }
                Row {
                    id: manrow
                    visible: false
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // 播放按钮
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: playNowHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                        Image {
                            id: playNowIcon
                            anchors.centerIn: parent
                            source: "qrc:/image/playnow.png"
                            width: 15
                            height: 15
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: playNowIcon
                                color: "#FFFFFF"
                            }
                        }

                        HoverHandler {
                            id: playNowHoverHandler
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (playlistmanager.nowplaylistrange === 6) {
                                    playlistmanager.playSongbyindex(index);
                                } else {
                                    playlistmanager.addandplay(songData.songname, songData.songhash, songData.singername, songData.union_cover, songData.album_name, songData.duration);
                                    BasicConfig.emitSongAdded("正在播放: " + songData.songname);
                                }
                                manrow.visible = false;
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // 添加到列表按钮
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: addListHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                        Image {
                            id: addListIcon
                            anchors.centerIn: parent
                            source: "qrc:/image/addplaylist.png"
                            width: 15
                            height: 15
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: addListIcon
                                color: "#FFFFFF"
                            }
                        }

                        HoverHandler {
                            id: addListHoverHandler
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                playlistmanager.addSong(songData.songname, songData.songhash, songData.singername, songData.union_cover, songData.album_name, songData.duration);
                                BasicConfig.emitSongAdded();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // 收藏按钮
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: addLoveHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                        Image {
                            id: addloveImage
                            anchors.centerIn: parent
                            source: "qrc:/image/addlove.png"
                            width: 15
                            height: 15
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: addloveImage
                                color: addLoveHoverHandler.hovered ? "#FF6B6B" : "#FFFFFF"
                            }
                        }

                        HoverHandler {
                            id: addLoveHoverHandler
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                AnimatedImage {
                    source: "qrc:/image/isplaying.gif"
                    width: 25
                    height: 25
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: isPlaying
                    playing: visible
                }

                HoverHandler {
                    id: mouse
                    onHoveredChanged: {
                        if (hovered && !isPlaying) {
                            manrow.visible = true;
                        } else if (!hovered) {
                            manrow.visible = false;
                        }
                    }
                }
            }
        }
    }

    /* ===================== 推荐区块 delegate ===================== */
    Component {
        id: recommendSectionDelegate

        Item {
            width: parent.width
            height: column.implicitHeight

            property string title: modelData.title
            property int playRange: modelData.range
            property var songModel: modelData.model
            property bool isExpanded: false
            property int displayCount: isExpanded ? songModel.length : Math.min(6, songModel.length)
            property bool hasMore: songModel.length > 6

            Column {
                id: column
                spacing: 10
                width: parent.width

                Item {
                    width: parent.width
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 0.05 * parent.width
                    anchors.rightMargin: 0.053 * parent.width
                    height: 50

                    Text {
                        id: titletext
                        text: title
                        font.family: "黑体"
                        font.pixelSize: 18
                        color: "white"
                    }
                    Rectangle {
                        width: 22
                        height: width
                        radius: height / 2
                        anchors.left: titletext.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: titletext.verticalCenter
                        color: playAllHoverHandler.hovered ? "#FF6B6B" : "#4A4A5A"

                        Image {
                            id: playAllIcon
                            anchors.centerIn: parent
                            source: "qrc:/image/play.png"
                            width: 12
                            height: 12
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: playAllIcon
                                color: "#FFFFFF"
                            }
                        }

                        HoverHandler {
                            id: playAllHoverHandler
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                // 清空当前播放列表
                                playlistmanager.clearPlaylist();
                                // 批量添加当前区块的所有歌曲
                                for (var i = 0; i < songModel.length; i++) {
                                    var song = songModel[i];
                                    playlistmanager.addSong(song.songname, song.songhash, song.singername, song.union_cover, song.album_name, song.duration);
                                }
                                // 播放第一首
                                playlistmanager.playSongbyindex(0);
                                BasicConfig.emitSongAdded("已播放: " + title);
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // 刷新按钮
                    Rectangle {
                        id: refreshBtn
                        width: 32
                        height: 32
                        radius: 16
                        color: refreshHoverHandler.hovered ? "#30FFFFFF" : "transparent"
                        anchors.right: parent.right
                        anchors.verticalCenter: titletext.verticalCenter

                        Image {
                            id: refreshIcon
                            anchors.centerIn: parent
                            source: "qrc:/image/shuaxin.png"
                            width: 16
                            height: 16
                            fillMode: Image.PreserveAspectFit
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: refreshIcon
                                color: "#FFFFFF"
                            }
                        }

                        HoverHandler {
                            id: refreshHoverHandler
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: {
                                if (recommendation) {
                                    recommendation.getdatabygetdatarange(playRange);
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                GridView {
                    id: songGridView
                    width: parent.width
                    height: contentHeight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 0.05 * parent.width
                    anchors.rightMargin: 0.053 * parent.width
                    cellWidth: width / 2 - 10
                    cellHeight: 60
                    interactive: false
                    cacheBuffer: 100
                    model: displayCount
                    property int range: playRange
                    delegate: Item {
                        width: songGridView.cellWidth
                        height: 60
                        property var modelData: songModel[index]
                        Loader {
                            anchors.fill: parent
                            sourceComponent: songDelegate
                            onLoaded: {
                                item.songData = Qt.binding(function () {
                                    return modelData;
                                });
                            }
                        }
                    }
                }

                // 展开更多按钮
                Rectangle {
                    id: expandBtn
                    visible: hasMore
                    width: parent.width * 0.9
                    height: 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: expandHoverHandler.hovered ? "#3A3A45" : "#2A2A35"
                    radius: 8

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: isExpanded ? "收起" : "展开更多 (" + (songModel.length - 6) + "首)"
                            color: "#AAAAAA"
                            font.pixelSize: 13
                            font.family: "黑体"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Image {
                            id: expandIcon
                            source: "qrc:/image/left_line.png"
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
                            rotation: isExpanded ? 90 : -90
                            anchors.verticalCenter: parent.verticalCenter
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                source: expandIcon
                                color: "#AAAAAA"
                            }

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: expandHoverHandler
                    }

                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            isExpanded = !isExpanded;
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }
    }

    /* ===================== 滚动容器 ===================== */
    Flickable {
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
                color: "#42424b"
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 30
            Item {
                width: 1
                height: 1
            }

            Repeater {
                model: sectionModel
                delegate: recommendSectionDelegate
            }
        }
    }
}
