#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreAudio/CoreAudio.h>

#include <QtGlobal>
#include <QDebug>
#include "NowPlayingMediaController.h"
#include "playlistmanager.h"

// ==================== NowPlayingImpl ====================

@interface NowPlayingImpl : NSObject
@property (nonatomic, assign) NowPlayingMediaController *controller;
@property (nonatomic, assign) PlaylistManager *playlistManager;
@property (nonatomic, strong) NSString *cachedCoverURL;
@property (nonatomic, strong) MPMediaItemArtwork *cachedArtwork;
- (void)setup;
- (void)updateNowPlaying;
- (void)clearNowPlaying;
- (void)startAudioDeviceMonitor;
- (void)stopAudioDeviceMonitor;
- (void)loadArtworkFromURL:(NSString *)urlString;
- (void)applyAppIconArtwork;
@end

// CoreAudio 设备变化回调：输出设备变化时暂停播放
static OSStatus AudioDeviceChangedCallback(AudioObjectID inObjectID,
                                           UInt32 inNumberAddresses,
                                           const AudioObjectPropertyAddress inAddresses[],
                                           void *inClientData)
{
    NowPlayingImpl *impl = (__bridge NowPlayingImpl *)inClientData;
    if (inAddresses[0].mSelector != kAudioHardwarePropertyDefaultOutputDevice)
        return noErr;

    dispatch_async(dispatch_get_main_queue(), ^{
        impl.playlistManager->setPaused(true);
    });
    return noErr;
}

@implementation NowPlayingImpl

- (void)setup
{
    // 显式确保 NSApp 图标已加载：Qt 不一定调用 setApplicationIconImage，
    // 导致 [NSApp applicationIconImage] 返回空/占位灰图，媒体控制栏右下角
    // app 图标随之变灰。从 bundle 资源加载 icns 并强制设置。
    NSString *iconName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
    if (iconName) {
        NSImage *icon = [[NSImage imageNamed:iconName] copy];
        if (!icon) {
            NSString *iconPath = [[NSBundle mainBundle] pathForImageResource:iconName];
            if (iconPath) icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
        }
        if (icon) {
            [NSApp setApplicationIconImage:icon];
        }
    }

    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];

    // 播放 / 暂停
    [cc.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        Q_UNUSED(event)
        self.playlistManager->setPaused(false);
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [cc.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        Q_UNUSED(event)
        self.playlistManager->setPaused(true);
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [cc.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        Q_UNUSED(event)
        bool paused = self.playlistManager->isPaused();
        self.playlistManager->setPaused(!paused);
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    // 上一首 / 下一首
    [cc.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        Q_UNUSED(event)
        self.playlistManager->playPrevious();
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [cc.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        Q_UNUSED(event)
        self.playlistManager->playNext();
        return MPRemoteCommandHandlerStatusSuccess;
    }];

    // 进度条拖动
    [cc.changePlaybackPositionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        if ([event isKindOfClass:[MPChangePlaybackPositionCommandEvent class]]) {
            MPChangePlaybackPositionCommandEvent *posEvent = (MPChangePlaybackPositionCommandEvent *)event;
            double durationSec = self.playlistManager->durationstr().split(QLatin1Char(':')).size() == 2
                ? self.playlistManager->durationstr().split(QLatin1Char(':'))[0].toInt() * 60.0
                  + self.playlistManager->durationstr().split(QLatin1Char(':'))[1].toInt()
                : self.playlistManager->durationstr().toDouble();
            if (durationSec > 0) {
                float percent = posEvent.positionTime / durationSec;
                if (percent >= 0 && percent <= 1) {
                    self.playlistManager->setposistion(percent);
                    // seek 完成后更新媒体中心进度
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                        [self updateNowPlaying];
                    });
                }
            }
            return MPRemoteCommandHandlerStatusSuccess;
        }
        return MPRemoteCommandHandlerStatusCommandFailed;
    }];

    [self startAudioDeviceMonitor];
}

- (void)startAudioDeviceMonitor
{
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &addr,
                                   AudioDeviceChangedCallback,
                                   (__bridge void *)self);
}

- (void)stopAudioDeviceMonitor
{
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &addr,
                                      AudioDeviceChangedCallback,
                                      (__bridge void *)self);
}

- (void)updateNowPlaying
{
    NSString *title = self.playlistManager->currentTitle().toNSString();
    NSString *artist = self.playlistManager->currentsingername().toNSString();
    QString coverQstr = self.playlistManager->union_cover();
    float percent = self.playlistManager->getpercent();
    double durationSec = 0.0;
    QString durStr = self.playlistManager->durationstr();
    if (durStr.contains(QLatin1Char(':'))) {
        auto parts = durStr.split(QLatin1Char(':'));
        if (parts.size() == 2)
            durationSec = parts[0].toInt() * 60.0 + parts[1].toInt();
    } else {
        durationSec = durStr.toDouble();
    }

    float rate = self.playlistManager->isPaused() ? 0.0f : 1.0f;
    NSTimeInterval elapsedTime = percent * durationSec;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (title) [info setObject:title forKey:MPMediaItemPropertyTitle];
    if (artist) [info setObject:artist forKey:MPMediaItemPropertyArtist];
    if (durationSec > 0)
        [info setObject:@(durationSec) forKey:MPMediaItemPropertyPlaybackDuration];
    [info setObject:@(rate) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [info setObject:@(elapsedTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];

    // 保留已有封面，避免闪烁；无封面时使用 App 图标兜底
    if (self.cachedArtwork) {
        [info setObject:self.cachedArtwork forKey:MPMediaItemPropertyArtwork];
    } else {
        NSImage *appIcon = [NSApp applicationIconImage];
        if (appIcon) {
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc]
                initWithBoundsSize:appIcon.size
                requestHandler:^NSImage *(CGSize requestedSize) {
                    return appIcon;
                }];
            self.cachedArtwork = artwork;
            [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
        }
    }

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];

    // 封面 URL 变化时才重新下载
    NSString *coverNStr = coverQstr.toNSString();
    if (!coverQstr.isEmpty() && ![coverNStr isEqualToString:self.cachedCoverURL]) {
        qDebug("NowPlaying: 开始下载封面 URL: %s", coverNStr.UTF8String);
        self.cachedCoverURL = coverNStr;
        [self loadArtworkFromURL:coverNStr];
    } else if (coverQstr.isEmpty()) {
        qDebug("NowPlaying: 封面 URL 为空，使用 App 图标兜底");
        [self applyAppIconArtwork];
    }
}

- (void)loadArtworkFromURL:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        qDebug("NowPlaying: 封面 URL 无效，使用 App 图标兜底");
        [self applyAppIconArtwork];
        return;
    }

    // 用 sharedSession（单例，不会被提前释放）。
    // 注意：不能用局部 [NSURLSession sessionWithConfiguration:]——ARC 下局部 session
    // 在方法返回后即释放，而 task 不持有 session，回调时访问已释放 session 会段错误。
    // 超时通过 NSMutableURLRequest 配置。
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 8.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResp = [response isKindOfClass:[NSHTTPURLResponse class]]
                                          ? (NSHTTPURLResponse *)response : nil;
            if (error || !data || (httpResp && httpResp.statusCode != 200)) {
                qWarning("NowPlaying: 封面下载失败(status=%ld err=%s)，使用 App 图标兜底",
                      (long)(httpResp.statusCode), error.localizedDescription.UTF8String);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self applyAppIconArtwork];
                });
                return;
            }

            NSImage *nsImage = [[NSImage alloc] initWithData:data];
            if (!nsImage) {
                qWarning("NowPlaying: 封面数据无法解析为图片，使用 App 图标兜底");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self applyAppIconArtwork];
                });
                return;
            }

            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc]
                initWithBoundsSize:nsImage.size
                requestHandler:^NSImage *(CGSize requestedSize) {
                    return nsImage;
                }];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.cachedArtwork = artwork;
                NSMutableDictionary *current = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
                if (!current) current = [NSMutableDictionary dictionary];
                [current setObject:artwork forKey:MPMediaItemPropertyArtwork];
                [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:current];
            });
        }];
    [task resume];
}

// 用 App 图标作为媒体控制栏封面兜底（下载失败/URL 无效/为空时调用）
- (void)applyAppIconArtwork
{
    NSImage *appIcon = [NSApp applicationIconImage];
    // NSApp 图标为空时，尝试从主 bundle 资源加载（CFBundleIconFile 指向的 icns）
    if (!appIcon || appIcon.size.width == 0) {
        NSString *iconName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
        if (iconName) {
            appIcon = [[NSImage imageNamed:iconName] copy]
                      ?: [[NSImage alloc] initWithContentsOfFile:
                          [[NSBundle mainBundle] pathForImageResource:iconName]];
        }
    }
    if (!appIcon) {
        qWarning("NowPlaying: App 图标兜底也失败，封面将显示为系统默认");
        return;
    }
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc]
        initWithBoundsSize:appIcon.size
        requestHandler:^NSImage *(CGSize requestedSize) {
            return appIcon;
        }];
    self.cachedArtwork = artwork;
    NSMutableDictionary *current = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
    if (!current) current = [NSMutableDictionary dictionary];
    [current setObject:artwork forKey:MPMediaItemPropertyArtwork];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:current];
}

- (void)clearNowPlaying
{
    self.cachedCoverURL = nil;
    self.cachedArtwork = nil;
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
}

@end

// ==================== C++ 实现 ====================

NowPlayingMediaController::NowPlayingMediaController(PlaylistManager *pm, QObject *parent)
    : QObject(parent), m_playlistManager(pm)
{
    m_impl = [[NowPlayingImpl alloc] init];
    static_cast<NowPlayingImpl *>(m_impl).controller = this;
    static_cast<NowPlayingImpl *>(m_impl).playlistManager = pm;
    [static_cast<NowPlayingImpl *>(m_impl) setup];

    connect(m_playlistManager, &PlaylistManager::currentSongChanged, this, &NowPlayingMediaController::updateNowPlaying);
    connect(m_playlistManager, &PlaylistManager::isPausedChanged, this, &NowPlayingMediaController::updateNowPlaying);
    connect(m_playlistManager, &PlaylistManager::durationChanged, this, &NowPlayingMediaController::updateNowPlaying);
}

NowPlayingMediaController::~NowPlayingMediaController()
{
    [static_cast<NowPlayingImpl *>(m_impl) stopAudioDeviceMonitor];
    [static_cast<NowPlayingImpl *>(m_impl) clearNowPlaying];
}

void NowPlayingMediaController::updateNowPlaying()
{
    [static_cast<NowPlayingImpl *>(m_impl) updateNowPlaying];
}

void NowPlayingMediaController::clearNowPlaying()
{
    [static_cast<NowPlayingImpl *>(m_impl) clearNowPlaying];
}
