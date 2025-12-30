/****************************************************************************
** Meta object code from reading C++ file 'playlistmanager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../CPPSrc/playlistmanager.h"
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'playlistmanager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN8SongInfoE_t {};
} // unnamed namespace

template <> constexpr inline auto SongInfo::qt_create_metaobjectdata<qt_meta_tag_ZN8SongInfoE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SongInfo",
        "title",
        "songhash",
        "url",
        "singername",
        "union_cover",
        "album_name",
        "duration",
        "lyric"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
        // property 'title'
        QtMocHelpers::PropertyData<QString>(1, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'songhash'
        QtMocHelpers::PropertyData<QString>(2, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'url'
        QtMocHelpers::PropertyData<QString>(3, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'singername'
        QtMocHelpers::PropertyData<QString>(4, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'union_cover'
        QtMocHelpers::PropertyData<QString>(5, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'album_name'
        QtMocHelpers::PropertyData<QString>(6, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'duration'
        QtMocHelpers::PropertyData<QString>(7, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
        // property 'lyric'
        QtMocHelpers::PropertyData<QString>(8, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<SongInfo, qt_meta_tag_ZN8SongInfoE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject SongInfo::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8SongInfoE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8SongInfoE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN8SongInfoE_t>.metaTypes,
    nullptr
} };

void SongInfo::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = reinterpret_cast<SongInfo *>(_o);
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->title; break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->songhash; break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->url; break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->singername; break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->union_cover; break;
        case 5: *reinterpret_cast<QString*>(_v) = _t->album_name; break;
        case 6: *reinterpret_cast<QString*>(_v) = _t->duration; break;
        case 7: *reinterpret_cast<QString*>(_v) = _t->lyric; break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: QtMocHelpers::setProperty(_t->title, *reinterpret_cast<QString*>(_v)); break;
        case 1: QtMocHelpers::setProperty(_t->songhash, *reinterpret_cast<QString*>(_v)); break;
        case 2: QtMocHelpers::setProperty(_t->url, *reinterpret_cast<QString*>(_v)); break;
        case 3: QtMocHelpers::setProperty(_t->singername, *reinterpret_cast<QString*>(_v)); break;
        case 4: QtMocHelpers::setProperty(_t->union_cover, *reinterpret_cast<QString*>(_v)); break;
        case 5: QtMocHelpers::setProperty(_t->album_name, *reinterpret_cast<QString*>(_v)); break;
        case 6: QtMocHelpers::setProperty(_t->duration, *reinterpret_cast<QString*>(_v)); break;
        case 7: QtMocHelpers::setProperty(_t->lyric, *reinterpret_cast<QString*>(_v)); break;
        default: break;
        }
    }
}
namespace {
struct qt_meta_tag_ZN15PlaylistManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto PlaylistManager::qt_create_metaobjectdata<qt_meta_tag_ZN15PlaylistManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "PlaylistManager",
        "currentIndexChanged",
        "",
        "index",
        "playlistUpdated",
        "playbackFinished",
        "isPausedChanged",
        "currentSongChanged",
        "percentChanged",
        "durationChanged",
        "nowplaylistrangeChanged",
        "currlyricChanged",
        "playlist_typeChanged",
        "togetherplaylistUpdated",
        "parlyricsuc",
        "parselyricsuc",
        "addSong",
        "title",
        "songhash",
        "singername",
        "union_cover",
        "album_name",
        "duration",
        "removeSong",
        "playSongbyhasg",
        "playSongbyindex",
        "playNext",
        "playPrevious",
        "playstop",
        "addandplay",
        "url",
        "setposistion",
        "positionvalue",
        "changeplaylistbyrecommandindex",
        "songindex",
        "returnplaylistrange",
        "currentIndex",
        "currentTitle",
        "currentsingername",
        "isPaused",
        "percent",
        "percentstr",
        "playlist",
        "QList<SongInfo>",
        "playlistcount",
        "nowplaylistrange",
        "currlyric",
        "type",
        "playlist_type",
        "togetherplaylist",
        "m_lyrics",
        "QList<LyricLine>",
        "lyricsindex"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'currentIndexChanged'
        QtMocHelpers::SignalData<void(int)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 },
        }}),
        // Signal 'playlistUpdated'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playbackFinished'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isPausedChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentSongChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'percentChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'durationChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'nowplaylistrangeChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currlyricChanged'
        QtMocHelpers::SignalData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playlist_typeChanged'
        QtMocHelpers::SignalData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'togetherplaylistUpdated'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'parlyricsuc'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'parselyricsuc'
        QtMocHelpers::SlotData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'addSong'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &, const QString &, const QString &)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 }, { QMetaType::QString, 18 }, { QMetaType::QString, 19 }, { QMetaType::QString, 20 },
            { QMetaType::QString, 21 }, { QMetaType::QString, 22 },
        }}),
        // Method 'removeSong'
        QtMocHelpers::MethodData<void(int)>(23, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 },
        }}),
        // Method 'playSongbyhasg'
        QtMocHelpers::MethodData<void(const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 18 },
        }}),
        // Method 'playSongbyindex'
        QtMocHelpers::MethodData<void(int)>(25, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 },
        }}),
        // Method 'playNext'
        QtMocHelpers::MethodData<void()>(26, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'playPrevious'
        QtMocHelpers::MethodData<void()>(27, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'playstop'
        QtMocHelpers::MethodData<void()>(28, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'addandplay'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &, const QString &, const QString &, const QString &)>(29, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 }, { QMetaType::QString, 30 }, { QMetaType::QString, 19 }, { QMetaType::QString, 20 },
            { QMetaType::QString, 21 }, { QMetaType::QString, 22 },
        }}),
        // Method 'setposistion'
        QtMocHelpers::MethodData<void(float)>(31, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Float, 32 },
        }}),
        // Method 'changeplaylistbyrecommandindex'
        QtMocHelpers::MethodData<void(int, int)>(33, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 }, { QMetaType::Int, 34 },
        }}),
        // Method 'returnplaylistrange'
        QtMocHelpers::MethodData<void()>(35, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'currentIndex'
        QtMocHelpers::PropertyData<int>(36, QMetaType::Int, QMC::DefaultPropertyFlags, 0),
        // property 'currentTitle'
        QtMocHelpers::PropertyData<QString>(37, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'currentsingername'
        QtMocHelpers::PropertyData<QString>(38, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'isPaused'
        QtMocHelpers::PropertyData<bool>(39, QMetaType::Bool, QMC::DefaultPropertyFlags, 3),
        // property 'union_cover'
        QtMocHelpers::PropertyData<QString>(20, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'percent'
        QtMocHelpers::PropertyData<float>(40, QMetaType::Float, QMC::DefaultPropertyFlags, 5),
        // property 'percentstr'
        QtMocHelpers::PropertyData<QString>(41, QMetaType::QString, QMC::DefaultPropertyFlags, 5),
        // property 'duration'
        QtMocHelpers::PropertyData<QString>(22, QMetaType::QString, QMC::DefaultPropertyFlags, 6),
        // property 'playlist'
        QtMocHelpers::PropertyData<QList<SongInfo>>(42, 0x80000000 | 43, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 1),
        // property 'playlistcount'
        QtMocHelpers::PropertyData<int>(44, QMetaType::Int, QMC::DefaultPropertyFlags, 1),
        // property 'nowplaylistrange'
        QtMocHelpers::PropertyData<int>(45, QMetaType::Int, QMC::DefaultPropertyFlags, 7),
        // property 'currlyric'
        QtMocHelpers::PropertyData<QString>(46, QMetaType::QString, QMC::DefaultPropertyFlags, 8),
        // property 'type'
        QtMocHelpers::PropertyData<enum playlist_type>(47, 0x80000000 | 48, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 9),
        // property 'togetherplaylist'
        QtMocHelpers::PropertyData<QList<SongInfo>>(49, 0x80000000 | 43, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 10),
        // property 'm_lyrics'
        QtMocHelpers::PropertyData<QList<LyricLine>>(50, 0x80000000 | 51, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 11),
        // property 'lyricsindex'
        QtMocHelpers::PropertyData<qint64>(52, QMetaType::LongLong, QMC::DefaultPropertyFlags, 8),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<PlaylistManager, qt_meta_tag_ZN15PlaylistManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject PlaylistManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PlaylistManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PlaylistManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15PlaylistManagerE_t>.metaTypes,
    nullptr
} };

void PlaylistManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<PlaylistManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->currentIndexChanged((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 1: _t->playlistUpdated(); break;
        case 2: _t->playbackFinished(); break;
        case 3: _t->isPausedChanged(); break;
        case 4: _t->currentSongChanged(); break;
        case 5: _t->percentChanged(); break;
        case 6: _t->durationChanged(); break;
        case 7: _t->nowplaylistrangeChanged(); break;
        case 8: _t->currlyricChanged(); break;
        case 9: _t->playlist_typeChanged(); break;
        case 10: _t->togetherplaylistUpdated(); break;
        case 11: _t->parlyricsuc(); break;
        case 12: _t->parselyricsuc(); break;
        case 13: _t->addSong((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[6]))); break;
        case 14: _t->removeSong((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 15: _t->playSongbyhasg((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 16: _t->playSongbyindex((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 17: _t->playNext(); break;
        case 18: _t->playPrevious(); break;
        case 19: _t->playstop(); break;
        case 20: _t->addandplay((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[6]))); break;
        case 21: _t->setposistion((*reinterpret_cast<std::add_pointer_t<float>>(_a[1]))); break;
        case 22: _t->changeplaylistbyrecommandindex((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 23: _t->returnplaylistrange(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)(int )>(_a, &PlaylistManager::currentIndexChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::playlistUpdated, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::playbackFinished, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::isPausedChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::currentSongChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::percentChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::durationChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::nowplaylistrangeChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::currlyricChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::playlist_typeChanged, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::togetherplaylistUpdated, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlaylistManager::*)()>(_a, &PlaylistManager::parlyricsuc, 11))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 13:
        case 8:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< QList<SongInfo> >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->currentIndex(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->currentTitle(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->currentsingername(); break;
        case 3: *reinterpret_cast<bool*>(_v) = _t->isPaused(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->union_cover(); break;
        case 5: *reinterpret_cast<float*>(_v) = _t->getpercent(); break;
        case 6: *reinterpret_cast<QString*>(_v) = _t->getpercentstr(); break;
        case 7: *reinterpret_cast<QString*>(_v) = _t->durationstr(); break;
        case 8: *reinterpret_cast<QList<SongInfo>*>(_v) = _t->playlist(); break;
        case 9: *reinterpret_cast<int*>(_v) = _t->playlistcount(); break;
        case 10: *reinterpret_cast<int*>(_v) = _t->getnowplaylistrange(); break;
        case 11: *reinterpret_cast<QString*>(_v) = _t->getcurrlyric(); break;
        case 12: *reinterpret_cast<enum playlist_type*>(_v) = _t->getplaylist_type(); break;
        case 13: *reinterpret_cast<QList<SongInfo>*>(_v) = _t->togetherplaylist(); break;
        case 14: *reinterpret_cast<QList<LyricLine>*>(_v) = _t->LyricLine_get(); break;
        case 15: *reinterpret_cast<qint64*>(_v) = _t->lyricsindexget(); break;
        default: break;
        }
    }
}

const QMetaObject *PlaylistManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *PlaylistManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PlaylistManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int PlaylistManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 24)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 24;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 24)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 24;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 16;
    }
    return _id;
}

// SIGNAL 0
void PlaylistManager::currentIndexChanged(int _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void PlaylistManager::playlistUpdated()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void PlaylistManager::playbackFinished()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void PlaylistManager::isPausedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void PlaylistManager::currentSongChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void PlaylistManager::percentChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void PlaylistManager::durationChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void PlaylistManager::nowplaylistrangeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void PlaylistManager::currlyricChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void PlaylistManager::playlist_typeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void PlaylistManager::togetherplaylistUpdated()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void PlaylistManager::parlyricsuc()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}
QT_WARNING_POP
