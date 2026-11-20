import QtQuick 2.15
import QtQuick.Controls 2.15

// 歌曲行右键菜单：行内只留试听/播放，其余功能集中到这里
Popup {
    id: menu

    property var song: ({})
    property bool togetherMode: false
    property bool showAi: false
    property bool showRemove: false
    // 行内回调：菜单是全局单例，AI/移除等需要当前行上下文
    property var aiHandler: null
    property var removeHandler: null

    width: 208
    padding: 6
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function songMap() {
        var s = song || ({})
        return {
            "songname": s.songname || "",
            "songhash": s.songhash || "",
            "singername": s.singername || "",
            "union_cover": s.union_cover || "",
            "album_name": s.album_name || "",
            "duration": s.duration || "",
            "album_id": s.album_id || "",
            "mixsongid": s.mixsongid || ""
        }
    }

    function loginOk() {
        if (!userManager || !userManager.isLoggedIn) {
            BasicConfig.noticeError("请先登录")
            return false
        }
        return true
    }

    function openFor(anchorItem, songData, px, py, options) {
        song = songData || ({})
        var opt = options || ({})
        togetherMode = !!opt.togetherMode
        showAi = !!opt.showAi
        showRemove = !!opt.showRemove
        aiHandler = opt.onAi || null
        removeHandler = opt.onRemove || null
        // 固定在 Overlay 坐标系里打开，x/y 才能与鼠标窗口坐标一致
        if (Overlay.overlay)
            parent = Overlay.overlay
        // 统一关闭上一个右键菜单，避免多个菜单叠着
        var prev = BasicConfig.activeContextMenu
        BasicConfig.activeContextMenu = menu
        if (prev && prev !== menu)
            prev.close()

        // 跟随真实鼠标位置：顶部在光标右下角；没有 cursorTracker 时退回点击坐标
        var p
        if (typeof cursorTracker !== "undefined" && cursorTracker && cursorTracker.insideWindow)
            p = cursorTracker.pos
        else if (anchorItem)
            p = anchorItem.mapToItem(null, px, py)
        else
            p = { "x": px, "y": py }
        var menuH = contentColumn.implicitHeight + padding * 2
        var gx = p.x + 4
        var gy = p.y + 4
        // Popup 挂在 Overlay 上，用 Overlay 的实际尺寸做边界修正（Window.width 在 Popup 里不可靠）
        var availW = Overlay.overlay ? Overlay.overlay.width : 0
        var availH = Overlay.overlay ? Overlay.overlay.height : 0
        if (availW > 0 && gx + width > availW - 6)
            gx = Math.max(6, availW - width - 6)
        if (availH > 0 && gy + menuH > availH - 6)
            gy = Math.max(6, availH - menuH - 6)
        x = gx
        y = gy
        open()
    }

    onClosed: if (BasicConfig.activeContextMenu === menu) BasicConfig.activeContextMenu = null
    Component.onDestruction: if (BasicConfig.activeContextMenu === menu) BasicConfig.activeContextMenu = null

    contentItem: Column {
        id: contentColumn
        spacing: 2

        ContextMenuItem {
            text: "播放"
            iconSource: AppIcon.playCircle
            visible: !menu.togetherMode
            onClicked: {
                menu.close()
                if (playlistmanager) {
                    playlistmanager.playNextAndPlay(menu.songMap())
                    BasicConfig.emitSongAdded("正在播放: " + (menu.song.songname || ""))
                }
            }
        }

        ContextMenuItem {
            text: "下一首播放"
            iconSource: AppIcon.addToList
            visible: !menu.togetherMode
            onClicked: {
                menu.close()
                if (playlistmanager) {
                    playlistmanager.addSongNext(menu.songMap())
                    BasicConfig.emitSongAdded("已添加到下一首: " + (menu.song.songname || ""))
                }
            }
        }

        ContextMenuItem {
            text: "高潮试听"
            iconSource: AppIcon.sparkle
            onClicked: {
                menu.close()
                if (playlistmanager && menu.song.songhash)
                    playlistmanager.toggleClimaxPreview(
                        menu.song.songhash, menu.song.songname || "",
                        menu.song.singername || "", menu.song.union_cover || ""
                    )
            }
        }

        ContextMenuItem {
            text: "添加到歌单…"
            iconSource: AppIcon.list
            onClicked: {
                menu.close()
                if (menu.loginOk())
                    BasicConfig.requestAddToPlaylist(menu.songMap())
            }
        }

        ContextMenuItem {
            text: "收藏到我喜欢"
            iconSource: AppIcon.heart
            onClicked: {
                menu.close()
                if (menu.loginOk())
                    playlistCollection.addToFavorite(
                        menu.song.songname || "", menu.song.songhash || "", menu.song.singername || ""
                    )
            }
        }

        ContextMenuItem {
            text: "添加到一起听"
            iconSource: AppIcon.addTogether
            visible: menu.togetherMode
            onClicked: {
                menu.close()
                if (websocket)
                    websocket.addSongToTogether(
                        menu.song.songname || "", menu.song.songhash || "",
                        menu.song.singername || "", menu.song.album_name || "",
                        menu.song.duration || "", menu.song.union_cover || ""
                    )
            }
        }

        ContextMenuItem {
            text: "播放 MV"
            iconSource: AppIcon.video
            visible: !!(menu.song && menu.song.mvhash)
            onClicked: {
                menu.close()
                BasicConfig.requestMvPlay({
                    mvhash: menu.song.mvhash,
                    title: menu.song.songname || "",
                    singername: menu.song.singername || "",
                    songhash: menu.song.songhash || "",
                    cover: menu.song.union_cover || ""
                })
            }
        }

        ContextMenuItem {
            text: "AI 推荐"
            iconSource: AppIcon.sparkle
            visible: menu.showAi
            onClicked: {
                menu.close()
                if (typeof menu.aiHandler === "function")
                    menu.aiHandler()
            }
        }

        Rectangle {
            width: parent.width
            height: visible ? 1 : 0
            color: AppTheme.borderDefault
            visible: menu.showRemove
        }

        ContextMenuItem {
            text: "从歌单移除"
            iconSource: AppIcon.deleteIcon
            danger: true
            visible: menu.showRemove
            onClicked: {
                menu.close()
                if (typeof menu.removeHandler === "function")
                    menu.removeHandler()
            }
        }
    }

    background: Rectangle {
        radius: 10
        color: AppTheme.bgOverlay
        border.color: AppTheme.dialogBorder
        border.width: 1
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
    }
}
