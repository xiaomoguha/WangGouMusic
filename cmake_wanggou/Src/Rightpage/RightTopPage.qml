import QtQuick 2.15

//上层状态栏
Item{
    //搜索、后退、语音按钮
    Search{
        anchors.left: parent.left
        anchors.leftMargin: 0.03*root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15
    }

    Row{
        anchors.right: parent.right
        anchors.rightMargin: 0.02*root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30
        //登录信息
        LoginStatus{
            spacing: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        //最大化最小化
        MaxMin{
            spacing: 15
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
