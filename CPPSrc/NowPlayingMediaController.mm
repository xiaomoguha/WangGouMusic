#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreAudio/CoreAudio.h>

#include "NowPlayingMediaController.h"
#include "playlistmanager.h"

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

    // 保留已有封面，避免闪烁
    if (self.cachedArtwork) {
        [info setObject:self.cachedArtwork forKey:MPMediaItemPropertyArtwork];
    }

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];

    // 封面 URL 变化时才重新下载
    NSString *coverNStr = coverQstr.toNSString();
    if (!coverQstr.isEmpty() && ![coverNStr isEqualToString:self.cachedCoverURL]) {
        self.cachedCoverURL = coverNStr;
        [self loadArtworkFromURL:coverNStr];
    }
}

- (void)loadArtworkFromURL:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || !data) {
                NSLog(@"NowPlaying: 封面下载失败: %@", error.localizedDescription);
                return;
            }

            NSImage *nsImage = [[NSImage alloc] initWithData:data];
            if (!nsImage) {
                NSLog(@"NowPlaying: 封面数据无法解析为图片");
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
