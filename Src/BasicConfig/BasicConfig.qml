pragma Singleton
import QtQuick 2.15

QtObject {
    signal bkanAreaClicked//窗口空白被点击
    signal pushPage(string pageUrl)
    signal popPage
    signal indexchange(int index)
    signal pushsearchsongPage(string pageUrl)
    signal searchKeywordchange
    signal notice_error(string errormessages)
    signal notice_success(string messages)
    signal songAdded(string songname)

    property string searchKeyword: ""

    // 便捷方法：发送歌曲添加成功提示
    function emitSongAdded(songname) {
        songAdded(songname || "已添加至播放列表");
    }
}
