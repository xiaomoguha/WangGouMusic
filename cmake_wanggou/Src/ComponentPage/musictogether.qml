import QtQuick 2.15
Loader {
    id: pageLoader
    width: parent?parent.width:10
    height: parent?parent.height:10
    source: websocket.connected?"qrc:/Src/ComponentPage/Togethermusicmain.qml":"qrc:/Src/ComponentPage/Add_room_window.qml"
}
