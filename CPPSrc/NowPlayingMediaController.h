#ifndef NOWPLAYINGMEDIACONTROLLER_H
#define NOWPLAYINGMEDIACONTROLLER_H

#include <QObject>

class PlaylistManager;

#ifdef Q_OS_MAC
// macOS 媒体控制：耳机按键、键盘媒体键、通知中心"正在播放"
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
// 非 macOS 平台空实现
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
