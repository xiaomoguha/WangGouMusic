cmake_minimum_required(VERSION 3.16)
project(网狗音乐 VERSION 0.5.6 LANGUAGES CXX)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# macOS 上启用 Objective-C++
if(APPLE)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
endif()

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Quick Multimedia WebSockets Widgets QuickControls2 Core5Compat Network)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Quick Multimedia WebSockets Widgets QuickControls2 Core5Compat Network)

set(PROJECT_SOURCES
    main.cpp
)

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(WangGouMusic
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
        qml.qrc
        CPPSrc/httpgetrequester.cpp CPPSrc/HttpGetRequester.h CPPSrc/lyricparser.cpp CPPSrc/lyricparser.h CPPSrc/playlistmanager.cpp CPPSrc/playlistmanager.h CPPSrc/recommendation.cpp CPPSrc/recommendation.h CPPSrc/searchcomplex.cpp CPPSrc/searchcomplex.h CPPSrc/trayhandler.cpp CPPSrc/trayhandler.h CPPSrc/WebSocketClient.cpp CPPSrc/WebSocketClient.h
        CPPSrc/gethostsearch.cpp CPPSrc/gethostsearch.h
        CPPSrc/lyricsconfigmanager.cpp CPPSrc/lyricsconfigmanager.h
        CPPSrc/appupdater.cpp CPPSrc/appupdater.h
        CPPSrc/usermanager.cpp CPPSrc/usermanager.h
        CPPSrc/singleapplication.cpp CPPSrc/singleapplication.h
        CPPSrc/NowPlayingMediaController.h
        image.qrc
    )
    # Windows 应用程序图标
    if(WIN32)
        target_sources(WangGouMusic PRIVATE app.rc)
    endif()
    # 非 macOS 平台也需要头文件以触发 AUTOMOC（#else 分支有 Q_OBJECT）
    if(NOT APPLE)
        target_sources(WangGouMusic PRIVATE CPPSrc/NowPlayingMediaController.h)
    endif()
    # macOS Objective-C++ 源文件
    if(APPLE)
        target_sources(WangGouMusic PRIVATE CPPSrc/macoswindow.mm CPPSrc/macoswindow.h
                        CPPSrc/NowPlayingMediaController.mm CPPSrc/NowPlayingMediaController.h)
        set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/cmake_wanggou.icns PROPERTIES
            MACOSX_PACKAGE_LOCATION Resources)
        target_sources(WangGouMusic PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cmake_wanggou.icns)
    endif()
# Define target properties for Android with Qt 6 as:
#    set_property(TARGET WangGouMusic APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
#                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
# For more information, see https://doc.qt.io/qt-6/qt-add-executable.html#target-creation
else()
    if(ANDROID)
        add_library(WangGouMusic SHARED
            ${PROJECT_SOURCES}
        )
# Define properties for Android with Qt 5 after find_package() calls as:
#    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    else()
        add_executable(WangGouMusic
          ${PROJECT_SOURCES}
        )
    endif()
endif()

target_link_libraries(WangGouMusic
  PRIVATE Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Quick Qt${QT_VERSION_MAJOR}::Multimedia Qt${QT_VERSION_MAJOR}::WebSockets Qt${QT_VERSION_MAJOR}::Widgets Qt${QT_VERSION_MAJOR}::QuickControls2 Qt${QT_VERSION_MAJOR}::Core5Compat Qt${QT_VERSION_MAJOR}::Network)

# 将版本号注入 C++ 宏
target_compile_definitions(WangGouMusic PRIVATE APP_VERSION="${PROJECT_VERSION}")

# macOS 链接 Cocoa 框架
if(APPLE)
    find_library(COCOA_FRAMEWORK Cocoa)
    find_library(MEDIAPLAYER_FRAMEWORK MediaPlayer)
    find_library(COREAUDIO_FRAMEWORK CoreAudio)
    find_library(COREIMAGE_FRAMEWORK CoreImage)
    target_link_libraries(WangGouMusic PRIVATE ${COCOA_FRAMEWORK} ${MEDIAPLAYER_FRAMEWORK} ${COREAUDIO_FRAMEWORK} ${COREIMAGE_FRAMEWORK})
endif()

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
if(${QT_VERSION} VERSION_LESS 6.1.0)
  set(BUNDLE_ID_OPTION MACOSX_BUNDLE_GUI_IDENTIFIER com.example.WangGouMusic)
endif()
set_target_properties(WangGouMusic PROPERTIES
    ${BUNDLE_ID_OPTION}
    OUTPUT_NAME "网狗音乐"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    MACOSX_BUNDLE_ICON_FILE cmake_wanggou.icns
    # 禁用 QML 编译器的 unqualified access 警告
    QT_QML_SKIP_QMLCOMPILER_WARNINGS ON
)

include(GNUInstallDirs)
install(TARGETS WangGouMusic
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})

if(QT_VERSION_MAJOR EQUAL 6)
    qt_import_qml_plugins(WangGouMusic)
    qt_finalize_executable(WangGouMusic)
endif()
