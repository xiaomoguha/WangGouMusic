pragma Singleton
import QtQuick 2.15

QtObject {
    signal bkanAreaClicked // 窗口空白被点击
    signal pushPage(string pageUrl)
    signal indexChange(int index)
    signal pushSearchSongPage(string pageUrl)
    signal searchKeywordChange
    signal noticeError(string errormessages)
    signal noticeSuccess(string messages)
    signal songAdded(string songname)
    signal requestDesktopLyricsSettings()

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
            indexChange(previousIndex);
        }
    }

    // 便捷方法：发送歌曲添加成功提示
    function emitSongAdded(songname) {
        songAdded(songname || "已添加至播放列表");
    }
}
