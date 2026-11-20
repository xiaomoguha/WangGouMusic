import QtQuick 2.15
import QtQuick.Controls 2.15

// 新建歌单弹窗：输入名称，创建成功后由页面刷新我的歌单
ThemedPopup {
    id: root
    width: 360
    height: 200

    signal created(string name)

    function openDialog() {
        nameInput.text = ""
        open()
        nameInput.forceActiveFocus()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Text {
            text: "新建歌单"
            font.pixelSize: AppTheme.fontSizeTitleLg
            font.bold: true
            color: AppTheme.textPrimary
            font.family: AppTheme.fontFamily
        }

        Rectangle {
            width: parent.width
            height: 38
            radius: 8
            color: AppTheme.bgCard
            border.color: nameInput.activeFocus ? AppTheme.accent : AppTheme.borderDefault
            border.width: 1

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: AppTheme.textPrimary
                font.pixelSize: AppTheme.fontSizeBody
                font.family: AppTheme.fontFamily
                selectByMouse: true
                onAccepted: createBtnTap.create()
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            Rectangle {
                width: 70
                height: 34
                radius: 17
                color: cancelHover.hovered ? AppTheme.bgNavHover : "transparent"
                border.width: 1
                border.color: AppTheme.borderDefault

                Text {
                    anchors.centerIn: parent
                    text: "取消"
                    color: AppTheme.textSecondary
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.family: AppTheme.fontFamily
                }
                HoverHandler { id: cancelHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: root.close()
                }
            }

            Rectangle {
                width: 70
                height: 34
                radius: 17
                color: createHover.hovered ? AppTheme.accentHover : AppTheme.accent

                Text {
                    anchors.centerIn: parent
                    text: "创建"
                    color: "white"
                    font.pixelSize: AppTheme.fontSizeSmall
                    font.bold: true
                    font.family: AppTheme.fontFamily
                }
                HoverHandler { id: createHover }
                TapHandler {
                    id: createBtnTap
                    cursorShape: Qt.PointingHandCursor
                    enabled: !(playlistCollection && playlistCollection.isWorking)
                    function create() {
                        var name = nameInput.text.trim()
                        if (name === "") {
                            BasicConfig.noticeError("请输入歌单名")
                            return
                        }
                        playlistCollection.createPlaylist(name)
                    }
                    onTapped: create()
                }
            }
        }
    }

    Connections {
        target: playlistCollection
        function onOperationFinished(success, message) {
            if (!root.visible)
                return
            if (success) {
                root.created(nameInput.text.trim())
                root.close()
            }
        }
    }
}
