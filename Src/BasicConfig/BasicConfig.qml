pragma Singleton
import QtQuick 2.15

QtObject {
    signal bkanAreaClicked//窗口空白被点击
    signal pushPage(string pageUrl)
    signal indexchange(int index)
    signal pushsearchsongPage(string pageUrl)
    signal searchKeywordchange
    signal notice_error(string errormessages)
    signal notice_success(string messages)
    signal songAdded(string songname)

    property string searchKeyword: ""

    // 导航回退
    property string previousPageUrl: ""
    property int previousIndex: 0

    // 歌单详情页参数
    property string playlistDetailId: ""
    property string playlistDetailName: ""
    property string playlistDetailCover: ""
    property string playlistDetailIntro: ""

    function openPlaylistDetail(id, name, cover, intro) {
        playlistDetailId = id;
        playlistDetailName = name;
        playlistDetailCover = cover;
        playlistDetailIntro = intro;
        pushPage("qrc:/Src/ComponentPage/PlaylistDetailPage.qml");
    }

    function goBack() {
        if (previousPageUrl !== "") {
            pushPage(previousPageUrl);
            indexchange(previousIndex);
        }
    }

    // 便捷方法：发送歌曲添加成功提示
    function emitSongAdded(songname) {
        songAdded(songname || "已添加至播放列表");
    }
}
