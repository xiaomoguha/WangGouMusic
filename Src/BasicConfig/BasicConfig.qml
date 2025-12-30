pragma Singleton
import QtQuick 2.15

QtObject {
    signal bkanAreaClicked//窗口空白被点击
    signal pushPage(string pageUrl)
    signal popPage
    signal indexchange(int index)
    signal pushsearchsongPage(string pageUrl)
    signal searchKeywordchange

    property string searchKeyword: ""
}
