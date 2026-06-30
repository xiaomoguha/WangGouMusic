#ifndef NOWPLAYINGMEDIACONTROLLER_H
#define NOWPLAYINGMEDIACONTROLLER_H

#include <QObject>

class PlaylistManager;

// macOS 与 Windows 都有真实实现（macOS 在 .mm、Windows 在 _win.cpp），
// 通过 void* m_impl 指向各自的平台 impl；其余平台走下面的空实现。
#if defined(Q_OS_MAC) || defined(Q_OS_WIN)
// 媒体控制：耳机按键、键盘媒体键、系统媒体控件（macOS 通知中心 / Windows SMTC）
class NowPlayingMediaController : public QObject
{
    Q_OBJECT
public:
    explicit NowPlayingMediaController(PlaylistManager *pm, QObject *parent = nullptr);
    ~NowPlayingMediaController();

    void updateNowPlaying();
    void clearNowPlaying();

private:
    PlaylistManager *m_playlistManager;
    void *m_impl;
};
#else
// 其它平台（Linux 等）空实现
class NowPlayingMediaController : public QObject
{
    Q_OBJECT
public:
    explicit NowPlayingMediaController(PlaylistManager *, QObject *parent = nullptr) : QObject(parent) {}
    void updateNowPlaying() {}
    void clearNowPlaying() {}
};
#endif

#endif // NOWPLAYINGMEDIACONTROLLER_H
