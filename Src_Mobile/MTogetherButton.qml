import QtQuick
import "."
import "../Src/BasicConfig"

// 点播到一起听（进房后才显示）：点一下把这首歌加进房间播放列表。
// 用法：
//   MTogetherButton {
//       songname: modelData.songname;  songhash: modelData.songhash
//       singername: modelData.singername; albumname: modelData.album_name
//       duration: modelData.duration || ""; coverurl: modelData.union_cover || ""
//   }
MIcon
{
    id: root

    property string songname: ""
    property string songhash: ""
    property string singername: ""
    property string albumname: ""
    property string duration: ""
    property string coverurl: ""

    width: 18
    height: 18
    // 抬到行点击区之上：各歌曲行的 MouseArea 都声明在图标之后（z 更高），
    // 不抬 z 的话点按钮会整行播放
    z: 5
    visible: websocket && websocket.connectionState !== 0
    source: AppIcon.addTogether
    color: ma.pressed ? MTheme.accent : MTheme.textSecondary

    MouseArea {
        id: ma

        anchors.fill: parent
        anchors.margins: -8              // 扩大热区到 34px，不占行布局
        onClicked: {
            if (!websocket || websocket.connectionState === 0)
                return
            websocket.addSongToTogether(root.songname, root.songhash, root.singername,
                                        root.albumname, root.duration, root.coverurl)
            MTheme.toast(qsTr("已点播《%1》").arg(root.songname))
        }
    }
}
