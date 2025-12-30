import QtQuick 2.15
import QtQuick.Controls
import "../ComponentPage"
import "../BasicConfig"
Rectangle{
    property alias rightTopPage: righttoppage
    RightTopPage{
        id:righttoppage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 60
    }
    StackView {
        id: stackView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: righttoppage.bottom
        anchors.bottom: parent.bottom
        property int maxDepth: 5
        initialItem: "qrc:/Src/ComponentPage/HomePage.qml"  // 初始页面
        Connections{
            target:BasicConfig
            function urlToObjectName(url)
            {
                let fileName = url.split('/').pop();
                return fileName.split('.')[0];
            }
            function onPushPage(url)
            {
                if(stackView.depth >= stackView.maxDepth)
                {
                    // 删除最底部的页面（第一个入栈的）
                    stackView.pop(null) // 弹出到空，即移除最底层页面
                }

                if (!stackView.currentItem)
                {
                    stackView.push(url);
                }
                let currentName = stackView.currentItem.objectName;
                let pushName = urlToObjectName(url);
                if (currentName !== pushName)
                {
                    stackView.push(url);
                }
            }
            function onPushsearchsongPage(url)
            {
                if(stackView.depth >= stackView.maxDepth)
                {
                    // 删除最底部的页面（第一个入栈的）
                    stackView.pop(null) // 弹出到空，即移除最底层页面
                }
                if (!stackView.currentItem)
                {
                    // 当前无页面，直接入栈
                    stackView.push(url);
                    BasicConfig.searchKeywordchange()
                }
                // 当前页面的objectName
                let currentName = stackView.currentItem.objectName;
                let pushName = urlToObjectName(url);
                if (currentName !== pushName)
                {
                    stackView.push(url);
                    BasicConfig.searchKeywordchange()
                }
                else
                {
                    BasicConfig.searchKeywordchange()
                }
            }
            function onPopPage()
            {
                stackView.pop();
                const topItem = stackView.currentItem;
                if (topItem && topItem.index !== undefined)
                {
                    BasicConfig.indexchange(topItem.index)
                }
            }
        }
    }
}
