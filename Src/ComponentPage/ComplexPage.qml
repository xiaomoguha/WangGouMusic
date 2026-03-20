import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../BasicConfig"

Page {
    background: Rectangle {
        color: "transparent"
    }
    Connections {
        target: BasicConfig
        function onSearchKeywordchange() {
            loadingOverlay.visible = true;
            complexsearch.fetchComplexData(BasicConfig.searchKeyword);
        }
    }
    Connections {
        target: complexsearch
        function onLoadFinished() {
            loadingOverlay.visible = false;
        }
    }
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: "#13131a"    // 半透明黑色背景（看起来是灰色）
        visible: false      // 默认隐藏
        z: 9999             // 确保在最上层
        BusyIndicator {
            id: busycry
            anchors.top: parent.top
            anchors.topMargin: 30
            anchors.horizontalCenter: parent.horizontalCenter
            running: loadingOverlay.visible

            // 设置颜色为白色
            contentItem: Item {
                implicitWidth: 30
                implicitHeight: 30

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: parent.visible
                }

                Repeater {
                    model: 8  // 默认有 8 个小圆点
                    delegate: Rectangle {
                        x: parent.width / 2 - width / 2
                        y: 2  // 调整位置
                        width: 3
                        height: 3
                        radius: width / 2
                        color: "white"  // 设置为白色
                        transform: [
                            Translate {
                                y: -Math.min(parent.width, parent.height) * 0.4
                            },
                            Rotation {
                                angle: index * 45  // 8 个点，每个间隔 45 度
                                origin.x: width / 2
                                origin.y: Math.min(parent.width, parent.height) * 0.4
                            }
                        ]
                    }
                }
            }
        }
        Text {
            anchors {
                top: busycry.bottom
                topMargin: 20
                horizontalCenter: parent.horizontalCenter
            }
            text: "加载中..."
            color: "white"
            font.pixelSize: 10
        }
    }
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: 0.025 * root.width
        clip: true
        contentWidth: listCol.width
        contentHeight: listCol.height
        Column {
            id: listCol
            width: flick.width
            spacing: 10
            Repeater {
                model: complexsearch ? complexsearch.items : []
                delegate: Rectangle {
                    id: sosuoItem
                    width: listCol.width
                    height: sosuoindexrow.height + 25
                    radius: 5
                    color: sosuoHoverHandler.hovered ? "#212127" : "transparent"

                    property bool showActions: sosuoHoverHandler.hovered

                    HoverHandler {
                        id: sosuoHoverHandler
                    }
                    Row {
                        id: sosuoindexrow
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 15
                        Text {
                            text: index + 1 <= 9 ? "0" + String(index + 1) : index + 1
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16
                            color: "#a1a1a3"
                        }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 45
                            height: 45
                            source: modelData.union_cover
                            asynchronous: true
                            cache: true
                            mipmap: true
                            sourceSize.width: 90
                            sourceSize.height: 90
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                text: modelData.songname
                                font.pixelSize: 13
                                color: "white"
                                elide: Text.ElideRight     // 超出部分显示省略号
                                width: 0.19 * root.width                 // 设置最大宽度，省略号才生效
                                wrapMode: Text.NoWrap      // 禁止换行
                            }
                            Text {
                                text: modelData.singername
                                elide: Text.ElideRight     // 超出部分显示省略号
                                width: 0.19 * root.width                  // 设置最大宽度，省略号才生效
                                wrapMode: Text.NoWrap      // 禁止换行
                                font.pixelSize: 11
                                color: "white"
                            }
                        }
                    }
                    Row {
                        id: additemsrow
                        visible: showActions
                        x: 0.28 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // 播放按钮
                        Rectangle {
                            id: playNowBtn
                            width: 32
                            height: 32
                            radius: 16
                            color: playNowHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                            Image {
                                id: playNowIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/playnow.png"
                                width: 16
                                height: 16
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
                                    playlistmanager.addandplay(modelData.songname, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // 添加到播放列表按钮
                        Rectangle {
                            id: addPlaylistBtn
                            width: 32
                            height: 32
                            radius: 16
                            color: addPlaylistHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                            Image {
                                id: addPlaylistIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/addplaylist.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: addPlaylistIcon
                                    color: "#FFFFFF"
                                }
                            }

                            HoverHandler {
                                id: addPlaylistHoverHandler
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    playlistmanager.addSong(modelData.songname, modelData.songhash, modelData.singername, modelData.union_cover, modelData.album_name, modelData.duration);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // 添加到喜欢按钮
                        Rectangle {
                            id: addLoveBtn
                            width: 32
                            height: 32
                            radius: 16
                            color: addLoveHoverHandler.hovered ? "#30FFFFFF" : "transparent"

                            Image {
                                id: addLoveIcon
                                anchors.centerIn: parent
                                source: "qrc:/image/addlove.png"
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    source: addLoveIcon
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
                    Text {
                        id: albumText
                        x: showActions ? 0.48 * root.width : 0.4 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight     // 超出部分显示省略号
                        width: 0.28 * root.width                 // 设置最大宽度，省略号才生效
                        wrapMode: Text.NoWrap      // 禁止换行
                        text: modelData.album_name
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: "white"

                        Behavior on x {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                    Text {
                        id: songlenText
                        anchors.right: parent.right
                        anchors.rightMargin: 0.05 * root.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration
                        font.pixelSize: 14
                        font.family: "黑体"
                        color: "white"
                    }
                }
            }
        }
    }
}
