import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
Rectangle {
    id: lyricspage
    color: "#13131a"
    radius: 20

    property string albumCover: playlistmanager ?(playlistmanager.union_cover === ""?"qrc:/image/touxi.jpg":playlistmanager.union_cover):"qrc:/image/touxi.jpg"
    property string songName: playlistmanager?(playlistmanager.currentTitle === ""?"默认歌曲":playlistmanager.currentTitle):"........"
    property string singerName: playlistmanager?(playlistmanager.currentsingername=== ""?"默认歌手":playlistmanager.currentsingername):"....."


    // 1. 原始图片
    Image {
        id: originalImage
        anchors.fill: parent
        source: albumCover
        fillMode: Image.PreserveAspectCrop
        visible: false  // 隐藏原图
    }

    // 2. 先进行高斯模糊
    GaussianBlur {
        id: blurredImage
        anchors.fill: parent
        source: originalImage
        radius: Math.min(parent.width, parent.height) * 0.4
        samples: 120
        transparentBorder: true  // 重要！
        visible: false  // 隐藏模糊结果
    }

    // === 最终覆盖层 ===
    ColorOverlay {
        id:cover
        anchors.fill: blurredImage
        source: blurredImage
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: 1.0
        visible: false
    }

    // 3. 最后应用圆角裁剪
    OpacityMask {
        id:bgopmk
        anchors.fill: parent
        source: cover
        maskSource: Rectangle {
            width: originalImage.width
            height: originalImage.height
            radius: 20
            visible: false
        }
    }



    MouseArea {
        id: eventBlocker
        anchors.fill: parent
        property real pressX: 0
        property real pressY: 0
        property bool dragged: false
        property real dragThreshold: 5 // 判断是否真的拖动的最小距离
        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            dragged = false;
        }
        onPositionChanged: mouse => {
            // 判断是否拖动超过阈值
            if (!dragged && (Math.abs(mouse.x - pressX) > dragThreshold || Math.abs(mouse.y - pressY) > dragThreshold)) {
                dragged = true;
                if (root.visibility === Window.Maximized) {
                    root.showNormal();
                    root.y = mouse.y - 20;
                    leftrect.radius = 20;
                    rightrect.radius = 20;
                    bottomrect.radius = 20;
                }
                Qt.callLater(() => {
                    root.startSystemMove();
                });
            }
        }
        onReleased: mouse => {
            if (!dragged) {
                // 没有拖动就是点击
            }
        }
    }

    Item{
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0.03*root.height
        anchors.leftMargin: 0.03*root.width
        width: 30
        height: 30
        Image {
            anchors.fill: parent
            source: "qrc:/image/left_line.png"
            rotation: -90
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    root.lyricsOpened = !root.lyricsOpened
                }
            }
        }
    }


    // ======================= 顶部 ===========================
    Row {
        id: topBar
        spacing: 16
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 24

        Text {
            text: "歌曲"
            font.pixelSize: 20
            color: "white"
        }
        Text {
            text: "·"
            font.pixelSize: 20
            color: "#AAAAAA"
        }
        Text {
            text: "评论"
            font.pixelSize: 20
            color: "#666666"
        }
        Text {
            text: "·"
            font.pixelSize: 20
            color: "#AAAAAA"
        }
        Text {
            text: "相关"
            font.pixelSize: 20
            color: "#666666"
        }
    }

    // ================== 左侧唱片区 ==========================
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 100
        anchors.top: parent.top
        anchors.topMargin: 0.18*lyricspage.height

        spacing: 16
        width: 350

        Text {
            text: songName
            font.pixelSize: 16
            font.bold: true
            color: "white"
            font.family: "黑体"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: singerName
            font.pixelSize: 14
            color: "#DDDDDD"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Rectangle {
            width: 300
            height: 300
            radius: width/2
            clip: true
            anchors.horizontalCenter: parent.horizontalCenter
            Image {
                id:avatarImage
                anchors.fill: parent
                property real currentRotation: 0
                source: albumCover
                rotation: currentRotation
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: 300
                        height: 300
                        radius: width/2
                    }
                }
                NumberAnimation on currentRotation{
                    id: rotationAnim
                    from: 0
                    to: 360
                    duration: 15000
                    loops: Animation.Infinite
                    running: false
                }
                // 根据 isPaused 启停动画
                Connections
                {
                    target: playlistmanager
                    function onIsPausedChanged()
                    {
                        if (!playlistmanager.isPaused)
                        {
                            // 从当前角度重新开始动画
                            rotationAnim.from = avatarImage.currentRotation % 360
                            rotationAnim.to = rotationAnim.from + 360
                            rotationAnim.start()
                        }
                        else
                        {
                            rotationAnim.stop()
                        }
                    }
                }
            }
        }
        Item{
            height: 5
            width: 1
        }

        Row {
            spacing: 35
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                width: 28; height: 28
                source: "qrc:/image/shoucang.png"
            }

            Image {
                width: 28; height: 28
                source: "qrc:/image/xiazai.png"
            }

            Image {
                width: 28; height: 28
                source: "qrc:/image/pinlun.png"
            }

            Image {
                width: 28; height: 28
                source: "qrc:/image/caidan.png"
            }
        }
    }

    // ================== 右侧歌词区 ==========================
    ListView {
        id: lyricList
        anchors.right: parent.right
        anchors.rightMargin: 120
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0.2*root.height
        anchors.topMargin: 160
        clip: true
        width: 400

        model: playlistmanager?playlistmanager.m_lyrics:0
        interactive: false   //是否可以手动滚动
        spacing: 16

        currentIndex: playlistmanager ? playlistmanager.lyricsindex : -1

        highlightRangeMode: ListView.ApplyRange

        preferredHighlightBegin: lyricList.height / 2
        preferredHighlightEnd: lyricList.height / 2

        snapMode: ListView.SnapToItem

        delegate: Text {
            width: 400
            height: contentHeight > 0 ? contentHeight : 20 // 防止高度为0
            text: modelData.text
            color: ListView.isCurrentItem ? "#1B81FB" : "#dddddd"
            font.pixelSize: ListView.isCurrentItem ? 20 : 16
            horizontalAlignment: Text.AlignHCenter
            opacity: ListView.isCurrentItem ? 1.0 : 0.5
            Behavior on color {
                ColorAnimation {
                    duration: 300
                }
            }
            Behavior on font.pixelSize {
                NumberAnimation{
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

}
