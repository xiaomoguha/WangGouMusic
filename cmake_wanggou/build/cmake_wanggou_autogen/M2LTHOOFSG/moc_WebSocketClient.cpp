/****************************************************************************
** Meta object code from reading C++ file 'WebSocketClient.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../CPPSrc/WebSocketClient.h"
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'WebSocketClient.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.10.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN15WebSocketClientE_t {};
} // unnamed namespace

template <> constexpr inline auto WebSocketClient::qt_create_metaobjectdata<qt_meta_tag_ZN15WebSocketClientE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "WebSocketClient",
        "connected",
        "",
        "disconnected",
        "connectionStatusChanged",
        "connectionStateChanged",
        "WebSocketClient::ConnectionState",
        "state",
        "urlChanged",
        "url",
        "togetherplaylist_update",
        "messageReceived",
        "message",
        "jsonReceived",
        "QJsonObject",
        "json",
        "binaryReceived",
        "data",
        "errorOccurred",
        "error",
        "logMessage",
        "log",
        "sendString",
        "onConnected",
        "onDisconnected",
        "onTextMessageReceived",
        "onBinaryMessageReceived",
        "onError",
        "QAbstractSocket::SocketError",
        "sendHeartbeat",
        "tryReconnect",
        "connectToServer",
        "disconnectFromServer",
        "sendJson",
        "isConnected",
        "connectionState",
        "ConnectionState",
        "setUrl",
        "setAutoReconnect",
        "enable",
        "setHeartbeatInterval",
        "seconds",
        "together_playlist",
        "QList<SongInfo>",
        "Disconnected",
        "Connecting",
        "Connected",
        "Reconnecting"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'connected'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'disconnected'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'connectionStatusChanged'
        QtMocHelpers::SignalData<void(bool)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 1 },
        }}),
        // Signal 'connectionStateChanged'
        QtMocHelpers::SignalData<void(WebSocketClient::ConnectionState)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 },
        }}),
        // Signal 'urlChanged'
        QtMocHelpers::SignalData<void(const QString &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 },
        }}),
        // Signal 'togetherplaylist_update'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'messageReceived'
        QtMocHelpers::SignalData<void(const QString &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Signal 'jsonReceived'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 15 },
        }}),
        // Signal 'binaryReceived'
        QtMocHelpers::SignalData<void(const QByteArray &)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QByteArray, 17 },
        }}),
        // Signal 'errorOccurred'
        QtMocHelpers::SignalData<void(const QString &)>(18, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 19 },
        }}),
        // Signal 'logMessage'
        QtMocHelpers::SignalData<void(const QString &)>(20, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 21 },
        }}),
        // Slot 'sendString'
        QtMocHelpers::SlotData<void(const QString &)>(22, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Slot 'onConnected'
        QtMocHelpers::SlotData<void()>(23, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onDisconnected'
        QtMocHelpers::SlotData<void()>(24, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onTextMessageReceived'
        QtMocHelpers::SlotData<void(const QString &)>(25, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 12 },
        }}),
        // Slot 'onBinaryMessageReceived'
        QtMocHelpers::SlotData<void(const QByteArray &)>(26, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QByteArray, 17 },
        }}),
        // Slot 'onError'
        QtMocHelpers::SlotData<void(QAbstractSocket::SocketError)>(27, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 28, 19 },
        }}),
        // Slot 'sendHeartbeat'
        QtMocHelpers::SlotData<void()>(29, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'tryReconnect'
        QtMocHelpers::SlotData<void()>(30, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'connectToServer'
        QtMocHelpers::MethodData<void()>(31, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'disconnectFromServer'
        QtMocHelpers::MethodData<void()>(32, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendJson'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(33, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 15 },
        }}),
        // Method 'isConnected'
        QtMocHelpers::MethodData<bool() const>(34, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'connectionState'
        QtMocHelpers::MethodData<enum ConnectionState() const>(35, 2, QMC::AccessPublic, 0x80000000 | 36),
        // Method 'setUrl'
        QtMocHelpers::MethodData<void(const QString &)>(37, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 },
        }}),
        // Method 'setAutoReconnect'
        QtMocHelpers::MethodData<void(bool)>(38, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 39 },
        }}),
        // Method 'setHeartbeatInterval'
        QtMocHelpers::MethodData<void(int)>(40, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 41 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'connected'
        QtMocHelpers::PropertyData<bool>(1, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'url'
        QtMocHelpers::PropertyData<QString>(9, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
        // property 'connectionState'
        QtMocHelpers::PropertyData<enum ConnectionState>(35, 0x80000000 | 36, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 3),
        // property 'together_playlist'
        QtMocHelpers::PropertyData<QList<SongInfo>>(42, 0x80000000 | 43, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 5),
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'ConnectionState'
        QtMocHelpers::EnumData<enum ConnectionState>(36, 36, QMC::EnumFlags{}).add({
            {   44, ConnectionState::Disconnected },
            {   45, ConnectionState::Connecting },
            {   46, ConnectionState::Connected },
            {   47, ConnectionState::Reconnecting },
        }),
    };
    return QtMocHelpers::metaObjectData<WebSocketClient, qt_meta_tag_ZN15WebSocketClientE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject WebSocketClient::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15WebSocketClientE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15WebSocketClientE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15WebSocketClientE_t>.metaTypes,
    nullptr
} };

void WebSocketClient::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<WebSocketClient *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->connected(); break;
        case 1: _t->disconnected(); break;
        case 2: _t->connectionStatusChanged((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 3: _t->connectionStateChanged((*reinterpret_cast<std::add_pointer_t<WebSocketClient::ConnectionState>>(_a[1]))); break;
        case 4: _t->urlChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 5: _t->togetherplaylist_update(); break;
        case 6: _t->messageReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 7: _t->jsonReceived((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 8: _t->binaryReceived((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1]))); break;
        case 9: _t->errorOccurred((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 10: _t->logMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 11: _t->sendString((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 12: _t->onConnected(); break;
        case 13: _t->onDisconnected(); break;
        case 14: _t->onTextMessageReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 15: _t->onBinaryMessageReceived((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1]))); break;
        case 16: _t->onError((*reinterpret_cast<std::add_pointer_t<QAbstractSocket::SocketError>>(_a[1]))); break;
        case 17: _t->sendHeartbeat(); break;
        case 18: _t->tryReconnect(); break;
        case 19: _t->connectToServer(); break;
        case 20: _t->disconnectFromServer(); break;
        case 21: _t->sendJson((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 22: { bool _r = _t->isConnected();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 23: { enum ConnectionState _r = _t->connectionState();
            if (_a[0]) *reinterpret_cast<enum ConnectionState*>(_a[0]) = std::move(_r); }  break;
        case 24: _t->setUrl((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 25: _t->setAutoReconnect((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1]))); break;
        case 26: _t->setHeartbeatInterval((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 16:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QAbstractSocket::SocketError >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)()>(_a, &WebSocketClient::connected, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)()>(_a, &WebSocketClient::disconnected, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(bool )>(_a, &WebSocketClient::connectionStatusChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(WebSocketClient::ConnectionState )>(_a, &WebSocketClient::connectionStateChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QString & )>(_a, &WebSocketClient::urlChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)()>(_a, &WebSocketClient::togetherplaylist_update, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QString & )>(_a, &WebSocketClient::messageReceived, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QJsonObject & )>(_a, &WebSocketClient::jsonReceived, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QByteArray & )>(_a, &WebSocketClient::binaryReceived, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QString & )>(_a, &WebSocketClient::errorOccurred, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (WebSocketClient::*)(const QString & )>(_a, &WebSocketClient::logMessage, 10))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 3:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< QList<SongInfo> >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->isConnected(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->url(); break;
        case 2: *reinterpret_cast<enum ConnectionState*>(_v) = _t->connectionState(); break;
        case 3: *reinterpret_cast<QList<SongInfo>*>(_v) = _t->togetherplaylist_back(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 1: _t->setUrl(*reinterpret_cast<QString*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *WebSocketClient::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *WebSocketClient::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15WebSocketClientE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int WebSocketClient::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 27)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 27;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 27)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 27;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 4;
    }
    return _id;
}

// SIGNAL 0
void WebSocketClient::connected()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void WebSocketClient::disconnected()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void WebSocketClient::connectionStatusChanged(bool _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1);
}

// SIGNAL 3
void WebSocketClient::connectionStateChanged(WebSocketClient::ConnectionState _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1);
}

// SIGNAL 4
void WebSocketClient::urlChanged(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1);
}

// SIGNAL 5
void WebSocketClient::togetherplaylist_update()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void WebSocketClient::messageReceived(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1);
}

// SIGNAL 7
void WebSocketClient::jsonReceived(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 7, nullptr, _t1);
}

// SIGNAL 8
void WebSocketClient::binaryReceived(const QByteArray & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}

// SIGNAL 9
void WebSocketClient::errorOccurred(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 9, nullptr, _t1);
}

// SIGNAL 10
void WebSocketClient::logMessage(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 10, nullptr, _t1);
}
QT_WARNING_POP
