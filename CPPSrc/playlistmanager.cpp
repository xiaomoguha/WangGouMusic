#include "playlistmanager.h"
#include "ApiClient.h"
#include "DominantColorExtractor.h"
#include "PlaylistCacheStore.h"
#include <QAudioDevice>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QEventLoop>
#include <QRandomGenerator>
#include <QMediaDevices>
#include <QPropertyAnimation>
#include <QTimer>
#include <memory>
// 退出时进程中断的下载会留下半截 flac（probe 失败 -> 播放无声音），析构时删除
PlaylistManager::~PlaylistManager()
{
    for (const QString &path : std::as_const(m_activeDownloadFiles))
        QFile::remove(path);
}

PlaylistManager::PlaylistManager(Recommendation *recommendation, QObject *parent)
    : QObject(parent), m_recommendation(recommendation)
{
    // QML 列表视图 model（与 m_playlist/m_togetherplaylist/m_recentPlaylist 同步）
    m_playlistModel         = new SongListModel(this);
    m_togetherplaylistModel = new SongListModel(this);
    m_recentPlaylistModel   = new SongListModel(this);

    // 音质档位持久化（0自动/1标准128/2高品320/3无损flac）
    m_quality = m_settings.value("quality", 0).toInt();

    // 主色调提取模块：extract 异步返回结果，转发到 QML 绑定的 dominantColor 属性
    m_colorExtractor = new DominantColorExtractor(this);
    connect(
        m_colorExtractor, &DominantColorExtractor::dominantColorReady, this,
        [this](const QString &, const QString &color)
        {
            m_dominantColor = color;
            emit dominantColorChanged();
        }
    );

    m_player->setAudioOutput(m_audioOutput);
    // 音量持久化：启动恢复上次音量（m_targetVolume 同步，fade 动画以它为目标）
    const qreal initialVolume = m_settings.value(QStringLiteral("volume"), 1.0).toReal();
    m_audioOutput->setVolume(initialVolume);
    m_targetVolume = initialVolume;

    // 跟随系统默认音频输出设备：运行中新接入蓝牙耳机或切换默认播放设备时，自动把音频路由到新设备。
    auto *mediaDevices = new QMediaDevices(this);
    connect(
        mediaDevices, &QMediaDevices::audioOutputsChanged, this,
        [this]()
        {
            const QAudioDevice def = QMediaDevices::defaultAudioOutput();
            if (def.isNull())
                return;
            if (m_audioOutput->device() != def)
                m_audioOutput->setDevice(def);
            if (m_climaxOutput->device() != def)
                m_climaxOutput->setDevice(def);
        }
    );

    // 音量淡入/淡出：新歌(Stopped->Playing)渐强；暂停/自然结束前渐弱（见 playstop / updatePlaybackProgress）
    m_prevPlaybackState = m_player->playbackState();
    connect(
        m_player, &QMediaPlayer::playbackStateChanged, this,
        [this](QMediaPlayer::PlaybackState state)
        {
            // 高潮试听期间主播放必须保持暂停：兜底拦截缓冲恢复、异步取址完成等路径的自动 play
            if (state == QMediaPlayer::PlayingState && m_climaxPreviewing)
            {
                m_player->pause();
                m_prevPlaybackState = state;
                return;
            }
            if (state == QMediaPlayer::PlayingState && m_prevPlaybackState == QMediaPlayer::StoppedState)
                fadeInVolume(); // 切歌/首次开播：渐强
            m_prevPlaybackState = state;
        }
    );

    // 延迟到事件循环空闲时加载缓存，避免主线程同步 readAll + JSON 解析阻塞 QML 首屏
    // loadPlaylistFromCache 末尾会 emit playlistUpdated()，QML 绑定会自动刷新
    QTimer::singleShot(
        0, this,
        [this]()
        {
            loadPlaylistFromCache();
            loadRecentFromCache();
        }
    );
    //  连接 mediaStatusChanged 信号
    QObject::connect(
        m_player, &QMediaPlayer::mediaStatusChanged, this,
        [this](QMediaPlayer::MediaStatus status)
        {
            if (status == QMediaPlayer::EndOfMedia)
            {
                emit playbackFinished();
                m_isPaused = true;
                emit isPausedChanged();
                if (type == LOCAL)
                {
                    QTimer::singleShot(200, this, [this]() { this->playNext(); });
                }
            }
            else if (status == QMediaPlayer::LoadedMedia)
            {
                qint64 totalDuration = m_player->duration();
                m_duration           = formatTime(totalDuration);
                emit durationChanged();
                // 高潮点补请求：恢复播放/流媒体 duration 延迟就绪时，首次 climax 请求
                // 因 totalMs=0 未算成（m_climaxHash 仍标记该 hash）——就绪后重试一次。
                if (!m_climaxHash.isEmpty() && m_climaxPercent <= 0 && !m_climaxPending)
                {
                    const QString h = m_climaxHash;
                    m_climaxHash.clear(); // 绕过去重
                    fetchClimax(h);       // 命中本地缓存则不再发网络请求
                }
                // TOGETHER 模式下，歌曲加载完成后 seek 到目标进度
                if (type == TOGETHER && m_togetherSeekPercent > 0)
                {
                    qint64 targetPos = static_cast<qint64>(m_togetherSeekPercent * totalDuration);
                    m_player->setPosition(targetPos);
                    m_togetherSeekPercent = 0;
                }
            }
        }
    );
    // 连接播放进度变化信号
    connect(m_player, &QMediaPlayer::positionChanged, this, &PlaylistManager::updatePlaybackProgress);
    // 逐字进度高频刷新：positionChanged 实测仅 ~11-20Hz（无损缓存更低），
    // 定时器按真实播放位置重算补足——跳跃歌词动画（星星/字压扁）因此 60fps 平滑。
    m_lyricAnimTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_lyricAnimTimer, &QTimer::timeout, this, [this]() {
        if (m_climaxPreviewing)
        {
            if (m_climaxPlayer->playbackState() == QMediaPlayer::PlayingState)
                updateLyricProgress(climaxSongPosition());
        }
        else if (m_player->playbackState() == QMediaPlayer::PlayingState)
            updateLyricProgress(m_player->position());
    });
    recomputeLyricFeed();
    connect(m_player, &QMediaPlayer::errorOccurred, this, &PlaylistManager::handlePlayerError);
    connect(&m_lyricParser, &LyricParser::parselyricsuc, this, &PlaylistManager::parlyricsuc);

    // 高潮试听播放器：独立音频输出；片段按字节范围下到内存缓冲播放（不写本地文件）
    m_climaxPlayer->setAudioOutput(m_climaxOutput);
    m_climaxOutput->setVolume(0.0);
    m_climaxNam = new QNetworkAccessManager(this);
    connect(
        m_climaxPlayer, &QMediaPlayer::mediaStatusChanged, this,
        [this](QMediaPlayer::MediaStatus status)
        {
            if (!m_climaxPreviewing || m_climaxFinishing)
                return;
            if (status == QMediaPlayer::EndOfMedia)
            {
                if (m_fmPeakMode)
                {
                    m_fmPeakAdvanceOnFinish = true;
                    finishClimaxPreview(false, 120);
                }
                else
                {
                    finishClimaxPreview(true, 120);
                }
                return;
            }
            if (m_climaxPlayStarted || status != QMediaPlayer::LoadedMedia)
                return;
            m_climaxPlayStarted = true;
            if (!m_climaxBufferMode && m_climaxStartMs > 0)
                m_climaxPlayer->setPosition(m_climaxStartMs);
            m_climaxOutput->setVolume(0.0);
            m_climaxPlayer->play();
            fadeClimaxVolume(m_targetVolume, 400);
        }
    );
    connect(
        m_climaxPlayer, &QMediaPlayer::positionChanged, this,
        [this](qint64 pos)
        {
            if (!m_climaxPreviewing || m_climaxFinishing || !m_climaxPlayStarted || m_climaxEndMs <= 0)
                return;
            const qint64 songPos = pos + m_climaxMediaOffsetMs;
            updateClimaxPreviewProgress(songPos);  // 底栏进度/时间跟随试听
            updateLyricProgress(songPos);          // 歌词跟随试听进度滚动
            if (songPos >= m_climaxEndMs)
            {
                if (m_fmPeakMode)
                {
                    m_fmPeakAdvanceOnFinish = true;
                    finishClimaxPreview(false, 220);
                }
                else
                {
                    finishClimaxPreview(true, 220);
                }
            }
        }
    );
    connect(
        m_climaxPlayer, &QMediaPlayer::errorOccurred, this,
        [this](QMediaPlayer::Error, const QString &errorString)
        {
            if (!m_climaxPreviewing || m_climaxFinishing)
                return;
            m_climaxRequestHash.clear();
            if (m_fmPeakMode)
            {
                m_fmPeakAdvanceOnFinish = true;
                finishClimaxPreview(false, 120);
            }
            else
            {
                finishClimaxPreview(true, 120);
                emit climaxPreviewFailed(QStringLiteral("高潮试听加载失败：") + errorString);
            }
        }
    );
}

// 歌词逐字动画的自适应刷新频率。消费方（QML 窗口）主动上报可见性：
// 播放页展开或桌面歌词可见 → 60Hz；都不可见 → 停表。
void PlaylistManager::recomputeLyricFeed()
{
    const int hz = (m_playingPageLyricsActive || m_desktopLyricsActive) ? 60 : 0;
    if (hz == m_lyricFeedHz)
        return;
    m_lyricFeedHz = hz;
    if (hz == 0)
    {
        m_lyricAnimTimer.stop();
        return;
    }
    m_lyricAnimTimer.setInterval(1000 / hz);
    m_lyricAnimTimer.start();
    if (m_player->playbackState() == QMediaPlayer::PlayingState)
        updateLyricProgress(m_player->position());
}

void PlaylistManager::setPlayingPageLyricsActive(bool active)
{
    if (m_playingPageLyricsActive == active)
        return;
    m_playingPageLyricsActive = active;
    recomputeLyricFeed();
}

void PlaylistManager::setDesktopLyricsActive(bool active)
{
    if (m_desktopLyricsActive == active)
        return;
    m_desktopLyricsActive = active;
    recomputeLyricFeed();
}

// UI 空闲（失焦/被遮蔽，QML Binding 同步）：期间跳过进度条 10fps 发射。
void PlaylistManager::setUiIdle(bool idle)
{
    if (m_uiIdle == idle)
        return;
    m_uiIdle = idle;
    emit uiIdleChanged();
    if (!idle && m_player->duration() > 0)
    {
        m_lastPercentNotifyMs = 0;
        emit percentChanged();
    }
}

// 静态：从 QVariantMap 构造 SongInfo。统一字段映射（hash->songhash, cover->union_cover 等）
SongInfo PlaylistManager::songFromMap(const QVariantMap &map)
{
    SongInfo song;
    song.title       = map.value("title", map.value("songname")).toString();
    song.songhash    = map.value("songhash", map.value("hash")).toString();
    song.url         = map.value("url").toString();
    song.singername  = map.value("singername").toString();
    song.union_cover = map.value("union_cover", map.value("cover")).toString();
    song.album_name  = map.value("album_name").toString();
    song.duration    = map.value("duration").toString();
    song.lyric       = map.value("lyric").toString();
    song.peakStartMs = map.value("peak_start_ms").toLongLong();
    song.peakEndMs   = map.value("peak_end_ms").toLongLong();
    // 评论用 album_audio_id：QML 传了就用，没传则查列表解析时登记的缓存
    // （这样评论不用再为拿 id 去搜索歌名或额外查接口）
    song.mxid = map.value("mxid", map.value("album_audio_id", map.value("mixsongid"))).toString();
    if (song.mxid.isEmpty())
        song.mxid = SongInfo::cachedMxid(song.songhash);
    return song;
}

void PlaylistManager::addSong(const SongInfo &song)
{
    doAddSong(song, /*toHead=*/false, /*playNow=*/false);
}

void PlaylistManager::addSong(const QVariantMap &songMap)
{
    addSong(songFromMap(songMap));
}

void PlaylistManager::addSongNext(const SongInfo &song)
{
    if (type != LOCAL)
        return;
    // 若这首歌就是当前正在播放的，无需操作（它已经是"当前"）
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size() &&
        m_playlist[m_currentIndex].songhash == song.songhash)
    {
        return;
    }
    // 去重：若已在队列其它位置，先移除，再重新插到「下一首」位置，
    // 确保它真的成为下一首（而非保留在原位置）
    for (int i = 0; i < m_playlist.size(); i++)
    {
        if (m_playlist[i].songhash == song.songhash)
        {
            m_playlist.removeAt(i);
            break;
        }
    }
    SongInfo copy = song;
    copy.url.clear();
    const int insertIndex = m_currentIndex + 1;
    if (insertIndex >= m_playlist.size())
        m_playlist.append(copy);
    else
        m_playlist.insert(insertIndex, copy);
    savePlaylistToCache();
    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();
}

void PlaylistManager::addSongNext(const QVariantMap &songMap)
{
    addSongNext(songFromMap(songMap));
}
void PlaylistManager::removeSong(int index)
{
    if (index >= 0 && index < (*m_curplaylist).size())
    {
        (*m_curplaylist).removeAt(index);
        if (type == LOCAL)
            savePlaylistToCache();
        m_playlistModel->syncFromList(m_playlist);
        emit playlistUpdated();
        if (index == m_currentIndex)
        {
            m_currentIndex = -1;
            emit currentIndexChanged(m_currentIndex);
        }
    }
}

void PlaylistManager::clearPlaylist()
{
    (*m_curplaylist).clear();
    m_currentIndex = -1;
    m_lazySourceId.clear();
    m_lazyTotal    = 0;
    m_lazyPage     = 0;
    m_lazySeenHashes.clear();
    m_lazyFetching = false;
    if (type == LOCAL)
        savePlaylistToCache();
    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();
    emit currentIndexChanged(-1);
}

// 缓存目录访问转发到 PlaylistCacheStore（统一实现，消除三处 #ifdef 重复）
QString PlaylistManager::getCacheDir() const
{
    return PlaylistCacheStore::cacheDir();
}

QList<SongInfo> PlaylistManager::recentPlaylist() const
{
    return m_recentPlaylist;
}

SongListModel *PlaylistManager::recentPlaylistModel()
{
    return m_recentPlaylistModel;
}

void PlaylistManager::addToRecent(const SongInfo &song)
{
    if (song.songhash.isEmpty())
        return;

    // 如果已存在则先移除
    for (int i = 0; i < m_recentPlaylist.size(); ++i)
    {
        if (m_recentPlaylist[i].songhash == song.songhash)
        {
            m_recentPlaylist.removeAt(i);
            break;
        }
    }

    // 插入到头部
    m_recentPlaylist.prepend(song);

    // 超出上限则移除最旧的
    while (m_recentPlaylist.size() > MAX_RECENT_SIZE)
    {
        m_recentPlaylist.removeLast();
    }

    saveRecentToCache();
    m_recentPlaylistModel->syncFromList(m_recentPlaylist);
    emit recentPlaylistUpdated();
}

void PlaylistManager::saveRecentToCache()
{
    PlaylistCacheStore::saveRecent(m_recentPlaylist);
}

void PlaylistManager::loadRecentFromCache()
{
    PlaylistCacheStore::loadRecent(m_recentPlaylist);
    // 缺这两行会导致启动时 QML 的 recentPlaylist 仍为空——直到首次 addToRecent 才同步。
    m_recentPlaylistModel->syncFromList(m_recentPlaylist);
    emit recentPlaylistUpdated();
}

bool PlaylistManager::verifyCachedFileMd5(const QString &filePath, const QString &songhash)
{
    QCryptographicHash md5(QCryptographicHash::Md5);
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    md5.addData(&f);
    f.close();
    const QString actualHex = QString::fromLatin1(md5.result().toHex());  // 小写
    // 注意：toHex() 输出小写，与 hash 比较必须忽略大小写（曾因大写比对恒失败误删全库缓存）
    const QString sessionMd5 = m_sessionFileMd5.value(filePath);
    bool ok;
    if (!sessionMd5.isEmpty())
        ok = sessionMd5.compare(actualHex, Qt::CaseInsensitive) == 0;
    else if (m_quality >= 2)
        // 高音质转码文件 MD5 与歌单 hash 不同源且无会话期望：无法比对，放行
        // （这些文件由下载完成时的字节数+MD5 校验把关）
        ok = true;
    else
        ok = actualHex.compare(songhash, Qt::CaseInsensitive) == 0;
    if (ok)
        return true;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_md5FailAtMs.value(songhash.toUpper(), 0) < 5 * 60 * 1000)
        return true; // 冷却期内放行
    m_md5FailAtMs.insert(songhash.toUpper(), now);
    return false;
}

// 判断是否有缓存文件
int PlaylistManager::is_have_cache(const SongInfo &song, const int index)
{
    PlaylistCacheStore::ensureCacheDir();
    // 按音质分目录缓存（songs/128|320|flac），每种音质独立文件
    QString cacheFilePath = PlaylistCacheStore::songCachePath(song.title, song.singername, m_quality);

    QFile cacheFile(cacheFilePath);

    if (cacheFile.exists())
    {
        // 播放前完整性校验（决绝版，不兼容旧缓存）：酷狗 hash 即该音质文件的 MD5（实测），
        // 本地文件与之不符 = 半截/损坏——删除并走网络重新下载。5 分钟冷却防反复
        if (!verifyCachedFileMd5(cacheFilePath, song.songhash))
        {
            qWarning() << "缓存 MD5 校验失败，删除重新下载:" << cacheFilePath;
            cacheFile.remove();
            return 0;
        }
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;

        // 音质切换续播：缓存的另一音质文件也从当前进度接着放，
        // 不能直接 play() 从 0 开始
        const double resumePercent = m_resumePercentAfterSwitch;
        m_resumePercentAfterSwitch = -1.0f;

        m_player->stop();
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
        if (resumePercent > 0 && resumePercent < 1.0)
        {
            auto conn = std::make_shared<QMetaObject::Connection>();
            *conn     = connect(
                m_player, &QMediaPlayer::mediaStatusChanged, this,
                [this, resumePercent, conn](QMediaPlayer::MediaStatus status)
                {
                    if (status == QMediaPlayer::LoadedMedia)
                    {
                        seekToPercent(resumePercent);
                        m_player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                        QObject::disconnect(*conn);
                    }
                }
            );
        }
        else
        {
            m_player->play();
        }
        m_isPaused     = false;
        m_currentIndex = index;
        // 提取专辑封面主色调
        m_colorExtractor->extract(song.union_cover);
        // 重置进度：缓存命中的新歌也从 0 开始（与 startPlayback 一致）。
        m_percent    = 0.0f;
        m_percentstr = "00:00";
        emit percentChanged();
        emit currentIndexChanged(index);
        emit currentSongChanged();
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
        addToRecent(song);

        // 鲁棒性兜底：半截 flac（退出时下载中断）probe 失败后播放器可能静默无响应
        // （无声音、进度条不走，且 errorOccurred 可能延迟甚至不触发）。
        QTimer::singleShot(
            5000, this,
            [this, cacheFilePath, index, songhash = song.songhash]()
            {
                if (m_player->duration() > 0 || m_player->playbackState() == QMediaPlayer::PlayingState)
                    return; // 已正常解析/播放
                if (m_currentIndex != index || !QFile::exists(cacheFilePath))
                    return; // 已切歌或文件已处理
                if (m_player->source().toLocalFile() != cacheFilePath)
                    return; // 播放器已换源
                qWarning() << "缓存文件播放无响应，删除并重新下载:" << cacheFilePath;
                m_player->stop();
                m_player->setSource(QUrl());
                QFile::remove(cacheFilePath);
                playSongbyindex(index);
            }
        );
        return 1;
    }
    return 0;
}

QVector<LyricLine> PlaylistManager::LyricLine_get() const
{
    return m_lyricParser.getLyrics();
}

qint64 PlaylistManager::lyricsindexget()
{
    return m_lyricParser.getcurindex();
}

// 根据index播放
void PlaylistManager::loadSongPaused(int index)
{
    if (index < 0 || index >= (*m_curplaylist).size())
        return;

    const SongInfo &song = (*m_curplaylist)[index];
    m_currentIndex       = index;
    emit currentIndexChanged(index);

    // 加载歌词
    if (song.lyric.isEmpty())
    {
        QString cachedLyric = loadLyricFromCache(song.songhash);
        if (!cachedLyric.isEmpty())
        {
            (*m_curplaylist)[index].lyric = cachedLyric;
            m_lyricParser.parseKRCLyrics(cachedLyric);
        }
        else
        {
            fetchLyricData(
                song.songhash,
                [this, index](const QString &lyric)
                {
                    if (!lyric.isEmpty())
                    {
                        (*m_curplaylist)[index].lyric = lyric;
                        saveLyricToCache((*m_curplaylist)[index].songhash, lyric);
                        m_lyricParser.parseKRCLyrics(lyric);
                    }
                }
            );
        }
    }
    else
    {
        m_lyricParser.parseKRCLyrics(song.lyric);
    }

    // 加载音频到播放器，不播放
    m_player->stop();
    m_player->setSource(QUrl());

    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = PlaylistCacheStore::songCachePath(song.title, song.singername, m_quality);

    if (QFile::exists(cacheFilePath))
    {
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
    }
    else if (!song.url.isEmpty())
    {
        m_player->setSource(QUrl(song.url));
    }
    else
    {
        // 异步获取 URL 后加载
        fetchSongUrl(
            song.songhash,
            [this, index](const QString &url)
            {
                if (!url.isEmpty())
                {
                    (*m_curplaylist)[index].url = url;
                    if (m_currentIndex == index)
                    {
                        m_player->setSource(QUrl(url));
                    }
                }
            }
        );
    }

    m_colorExtractor->extract(song.union_cover);
    m_isPaused = true;
    emit currentSongChanged();
    emit isPausedChanged();
}

void PlaylistManager::playSongbyindex(int index)
{
    cancelClimaxPreview();
    if (index >= 0 && index < (*m_curplaylist).size())
    {
        // 先判断是否可以用本地缓存播放
        if (!is_have_cache((*m_curplaylist)[index], index))
        {
            if ((*m_curplaylist)[index].url != "")
            {
                qDebug() << "已有url，直接播放";
                m_currentIndex = index;
                emit currentIndexChanged(index);
                startPlayback((*m_curplaylist)[index]);
            }
            else
            {
                // 立即切歌 + 进入 loading/暂停态：取 URL 期间不显示"播放中"（URL 还没拿到），
                // 成功后 startPlayback 转 playing；失败由 handleSongUrlFailed 提示并自动跳下一首。
                m_currentIndex = index;
                emit currentIndexChanged(index);
                emit currentSongChanged();
                m_player->stop();  // 立即停旧歌：UI 已切新歌，避免"看着新歌、耳朵还在放旧歌"
                m_isBuffering = true;
                emit isBufferingChanged();
                m_isPaused = true;
                emit isPausedChanged();
                fetchSongUrl(
                    (*m_curplaylist)[index].songhash,
                    [this, index](const QString &url)
                    {
                        if (!url.isEmpty())
                        {
                            (*m_curplaylist)[index].url = url;
                            startPlayback((*m_curplaylist)[index]);
                        }
                        // 失败由 fetchSongUrl 内部 handleSongUrlFailed 统一处理（m_currentIndex 已是本歌→暂停+提示）
                    }
                );
            }
        }
        if ((*m_curplaylist)[index].lyric == "")
        {
            // 先尝试从本地缓存加载歌词
            QString cachedLyric = loadLyricFromCache((*m_curplaylist)[index].songhash);
            if (!cachedLyric.isEmpty())
            {
                (*m_curplaylist)[index].lyric = cachedLyric;
                m_lyricParser.parseKRCLyrics(cachedLyric);
                qDebug() << "从本地缓存加载歌词";
            }
            else
            {
                fetchLyricData(
                    (*m_curplaylist)[index].songhash,
                    [this, index](const QString &lyric)
                    {
                        if (!lyric.isEmpty())
                        {
                            (*m_curplaylist)[index].lyric = lyric;
                            saveLyricToCache((*m_curplaylist)[index].songhash, lyric);
                            m_lyricParser.parseKRCLyrics(lyric);
                        }
                        else
                        {
                            qWarning() << "获取lyric失败";
                        }
                    }
                );
            }
        }
        else
        {
            m_lyricParser.parseKRCLyrics((*m_curplaylist)[index].lyric);
            qDebug() << "已有歌词";
        }
        // 懒加载模式：播放位置接近队列末尾时预加载下一批
        tryLazyLoadMore();
    }
    else
    {
        qDebug() << "索引出错！";
    }
}
// 根据hash值播放
void PlaylistManager::playPlaylistFromSource(
    const QString &sourceId, int totalCount, int startIndexInSource, const QVariantList &firstBatch
)
{
    cancelClimaxPreview();
    if (type != LOCAL)
        return; // 一起听模式不处理
    m_lazySourceId = sourceId;
    m_lazyTotal    = totalCount;
    m_lazyFetching = false;

    // 清空队列，用首批数据立即建队（无网络延迟）
    m_playlist.clear();
    m_lazySeenHashes.clear();
    QList<SongInfo> songs = convertToSongInfoList(firstBatch);
    for (const SongInfo &s : songs)
    {
        m_playlist.append(s);
        m_lazySeenHashes.insert(s.songhash);
    }
    // 首批不一定恰好是 m_lazyPageSize 的整数页（旧缓存只有 30 条、QML 已
    // 滚动加载了多页等）：按已加载完整页数向上取整；不足一页且源还有更多时
    const int loaded = songs.size();
    m_lazyPage       = loaded > 0 ? (loaded + m_lazyPageSize - 1) / m_lazyPageSize : 0;
    if (loaded > 0 && loaded < m_lazyPageSize && m_lazyTotal > loaded)
        m_lazyPage = 0;

    savePlaylistToCache();
    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();

    // 起始下标在首批内的相对位置
    int localIndex = startIndexInSource;
    if (localIndex >= m_playlist.size())
        localIndex = m_playlist.size() - 1;
    if (localIndex < 0)
        localIndex = 0;
    playSongbyindex(localIndex);
    // 双击播放不再立即级联拉全量（每次双击都拉一遍剩余页对风控不友好）：
    // 剩余页由 tryLazyLoadMore（播放临近已加载末尾）/ requestMoreSourceTracks
}

void PlaylistManager::tryLazyLoadMore()
{
    // 仅懒加载模式；非一起听；未在拉取；源还有更多；距末尾 ≤ 5（播放预取）
    if (m_lazySourceId.isEmpty() || type != LOCAL || m_lazyFetching)
        return;
    if (m_lazyPage * m_lazyPageSize >= m_lazyTotal)
        return; // 源已全加载
    if (m_playlist.size() - m_currentIndex > 5)
        return; // 余量充足
    fetchNextSourcePage();
}

void PlaylistManager::requestMoreSourceTracks()
{
    // 弹窗滚动按需加载：与 tryLazyLoadMore 共用前置守卫，但不受「距末尾 ≤ 5」限制。
    if (m_lazySourceId.isEmpty() || type != LOCAL || m_lazyFetching)
        return;
    if (m_lazyPage * m_lazyPageSize >= m_lazyTotal)
        return; // 源已全加载
    fetchNextSourcePage();
}

void PlaylistManager::fetchNextSourcePage()
{
    m_lazyFetching = true;
    int nextPage   = m_lazyPage + 1;
    if (m_recommendation)
    {
        m_recommendation->fetchPlaylistTracksPage(
            m_lazySourceId, nextPage, m_lazyPageSize,
            [this](const QVariantList &items)
            {
                m_lazyFetching        = false;
                QList<SongInfo> songs = convertToSongInfoList(items);
                for (const SongInfo &s : songs)
                {
                    // 补拉页与首批可能重叠（首批不足一页时从第 1 页重拉）：
                    // 按 hash 去重，已在队列里的直接跳过
                    if (m_lazySeenHashes.contains(s.songhash))
                        continue;
                    m_lazySeenHashes.insert(s.songhash);
                    m_playlist.append(s);
                }
                // 空页（含失败兜底）不推进页号，下次触发重试同一页；
                if (!items.isEmpty())
                    m_lazyPage += 1;
                savePlaylistToCache();
                m_playlistModel->syncFromList(m_playlist);
                emit playlistUpdated();
                // 单页补拉：不再级联拉全量，由触发方（临近末尾/弹窗滚动/下一首）按需再拉
                // playNext 在已加载末尾触发拉取时，下一批到位后续播下一首
                if (m_pendingNextAfterLoad)
                {
                    m_pendingNextAfterLoad = false;
                    if (m_currentIndex + 1 < m_playlist.size())
                        playSongbyindex(m_currentIndex + 1);
                }
            }
        );
    }
}
// 根据hash值播放
void PlaylistManager::playSongbyhasg(const QString &songhash)
{
    cancelClimaxPreview();
    for (int index = 0; index < (*m_curplaylist).size(); index++)
    {
        if ((*m_curplaylist)[index].songhash == songhash)
        {
            // 先判断是否可以用本地缓存播放
            if (!is_have_cache((*m_curplaylist)[index], index))
            {
                // 没有url的时候再获取url，有的话直接播放
                if ((*m_curplaylist)[index].url != "")
                {
                    // 直接播放
                    qDebug() << "已有url，直接播放";
                    m_currentIndex = index;
                    emit currentIndexChanged(index);
                    startPlayback((*m_curplaylist)[index]);
                }
                else
                {
                    // 立即切歌 + loading/暂停态(同 playSongbyindex)：取 URL 期间不显示"播放中"
                    m_currentIndex = index;
                    emit currentIndexChanged(index);
                    emit currentSongChanged();
                    m_player->stop();  // 立即停旧歌，避免"看着新歌、耳朵还在放旧歌"
                    m_isBuffering = true;
                    emit isBufferingChanged();
                    m_isPaused = true;
                    emit isPausedChanged();
                    fetchSongUrl(
                        songhash,
                        [this, index](const QString &url)
                        {
                            if (!url.isEmpty())
                            {
                                (*m_curplaylist)[index].url = url;
                                startPlayback((*m_curplaylist)[index]);
                            }
                            // 失败由 fetchSongUrl 内部 handleSongUrlFailed 统一处理
                        }
                    );
                }
            }
            if ((*m_curplaylist)[index].lyric == "")
            {
                // 先尝试从本地缓存加载歌词
                QString cachedLyric = loadLyricFromCache(songhash);
                if (!cachedLyric.isEmpty())
                {
                    (*m_curplaylist)[index].lyric = cachedLyric;
                    m_lyricParser.parseKRCLyrics(cachedLyric);
                    qDebug() << "从本地缓存加载歌词";
                }
                else
                {
                    fetchLyricData(
                        songhash,
                        [this, index, songhash](const QString &lyric)
                        {
                            if (!lyric.isEmpty())
                            {
                                (*m_curplaylist)[index].lyric = lyric;
                                saveLyricToCache(songhash, lyric);
                                m_lyricParser.parseKRCLyrics(lyric);
                            }
                            else
                            {
                                qWarning() << "获取lyric失败";
                            }
                        }
                    );
                }
            }
            else
            {
                qDebug() << "已有歌词";
                m_lyricParser.parseKRCLyrics((*m_curplaylist)[index].lyric);
            }
            return;
        }
    }
}
// 按播放模式取下一首并播放（顺序 / 单曲循环 / 随机）
void PlaylistManager::playNext()
{
    const int size = (*m_curplaylist).size();
    if (size <= 0)
        return;

    if (m_playMode == MODE_RANDOM)
    {
        // 随机：避免连续重复同一首（单首歌时只能循环自己）
        int next = m_currentIndex;
        if (size > 1)
            while (next == m_currentIndex)
                next = QRandomGenerator::global()->bounded(size);
        playSongbyindex(next);
        return;
    }

    if (m_playMode == MODE_SINGLE_LOOP)
    {
        // 单曲循环：重播当前歌（走完整管线：重置进度/封面色/歌词）
        int target = m_currentIndex >= 0 ? m_currentIndex : 0;
        playSongbyindex(target);
        return;
    }

    // 顺序播放
    if (m_currentIndex + 1 < size)
    {
        playSongbyindex(m_currentIndex + 1);
    }
    else if (!m_lazySourceId.isEmpty() && m_lazyPage * m_lazyPageSize < m_lazyTotal)
    {
        // 已到已加载队列末尾，但源歌单还有更多：拉取下一批，到位后续播下一首（而非回到第一首）
        m_pendingNextAfterLoad = true;
        if (!m_lazyFetching)
            fetchNextSourcePage();
    }
    else
    {
        playSongbyindex(0);
    }
}

void PlaylistManager::cyclePlayMode()
{
    m_playMode = (m_playMode + 1) % 3;
    emit playModeChanged();
    savePlaylistToCache();   // 播放模式持久化：下次启动恢复
}

int PlaylistManager::playMode() const
{
    return m_playMode;
}

int PlaylistManager::quality() const
{
    return m_quality;
}

void PlaylistManager::setQuality(int q)
{
    if (q == m_quality)
        return;
    m_quality = q;
    m_settings.setValue("quality", q);
    emit qualityChanged();
    // 队列里已取过的 URL 全部作废（旧音质）：下次播放自动按新音质重取
    for (SongInfo &s : m_playlist)
        s.url.clear();
    // 一起听：播放由服务器广播驱动（URL 来自广播），音质调整不换源、不打扰房间同步，
    // 档位仅记录，供退出一起听后的本地播放使用
    if (type == TOGETHER)
        return;
    for (SongInfo &s : m_togetherplaylist)
        s.url.clear();
    // 当前歌即时换源：走标准播放管线（缓存优先 + 边下边播，与切歌完全同路径）。
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        m_resumePercentAfterSwitch = m_percent > 0.02f ? m_percent : -1.0f;
        playSongbyindex(m_currentIndex);
    }
}

void PlaylistManager::playPrevious()
{
    if (m_currentIndex > 0)
    {
        playSongbyindex(m_currentIndex - 1);
    }
    else
    {
        playSongbyindex((*m_curplaylist).size() - 1);
    }
}

void PlaylistManager::playstop()
{
    // 个人FM 30秒模式：暂停/继续试听片段，不触发恢复整首
    if (m_fmPeakMode && type == LOCAL)
    {
        if (m_climaxPreviewing)
        {
            if (m_climaxPlayer->playbackState() == QMediaPlayer::PlayingState)
            {
                m_climaxPlayer->pause();
                m_isPaused = true;
            }
            else
            {
                m_climaxPlayer->play();
                m_isPaused = false;
            }
            emit isPausedChanged();
            return;
        }
        if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
            startFmPeakPreview((*m_curplaylist)[m_currentIndex]);
        return;
    }

    // 试听中按播放/暂停键 = 结束试听并回到原播放状态
    if (m_climaxPreviewing)
    {
        finishClimaxPreview(true);
        return;
    }
    cancelClimaxPreview();
    QMediaPlayer::PlaybackState state = m_player->playbackState();

    if (state == QMediaPlayer::PlayingState)
    {
        // 一起听：本地暂停只影响自己，不告知服务器（房间其他人继续播）
        m_localPaused = true;
        m_pendingPlayWhenReady = false;
        // 暂停前 1.5s 渐弱，再真正暂停（图标立即切换为暂停）
        m_isPaused = true;
        emit isPausedChanged();
        fadeOutVolume(
            1000,
            [this]()
            {
                if (m_player->playbackState() == QMediaPlayer::PlayingState)
                    m_player->pause();
            }
        );
    }
    else
    {
        // 如果没有设置有效 URL，不允许播放
        if (m_player->source().isValid())
        {
            m_player->play();
            m_isPaused = false;
            emit isPausedChanged();
            fadeInVolume(); // 恢复时渐强
            // 一起听：手动恢复播放由 WebSocketClient 监听 isPausedChanged
            // 接管——清掉本地暂停标记，从房间最新进度续上（含错过的切歌）
        }
        else
        {
            // 恢复播放时 URL 还在拉取中（source 未就绪）：标记待播，
            // source 就绪（LoadedMedia）后自动续播，避免"点了没反应"
            m_pendingPlayWhenReady = true;
            qDebug() << "播放源未就绪，已排队等待自动播放";
        }
    }
}

// 插到当前播放歌曲的下一首并立即播放这首
void PlaylistManager::playNextAndPlay(const SongInfo &song)
{
    if (type != LOCAL)
        return; // 一起听模式不处理
    // 去重：若已在队列则直接切过去播
    for (int i = 0; i < m_playlist.size(); i++)
    {
        if (m_playlist[i].songhash == song.songhash)
        {
            playSongbyindex(i);
            return;
        }
    }
    // 插到 currentIndex+1
    SongInfo copy = song;
    copy.url.clear();
    const int insertIndex = m_currentIndex + 1;
    if (insertIndex >= m_playlist.size())
        m_playlist.append(copy);
    else
        m_playlist.insert(insertIndex, copy);
    savePlaylistToCache();
    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();
    // 立即播放刚插入的这首
    playSongbyindex(insertIndex);
}

void PlaylistManager::playNextAndPlay(const QVariantMap &songMap)
{
    playNextAndPlay(songFromMap(songMap));
}

// 内部复用：把歌曲加入当前 curplaylist 末尾（不再对外暴露）
void PlaylistManager::doAddSong(const SongInfo &song, bool /*toHead*/, bool /*playNow*/)
{
    QList<SongInfo> &list = *m_curplaylist;
    for (int index = 0; index < list.size(); index++)
    {
        if (list[index].songhash == song.songhash)
            return;
    }
    SongInfo copy = song;
    copy.url.clear();
    copy.lyric.clear();
    list.append(copy);
    if (type == LOCAL)
    {
        savePlaylistToCache();
        m_playlistModel->syncFromList(m_playlist);
        emit playlistUpdated();
    }
    else if (type == TOGETHER)
    {
        m_togetherplaylistModel->syncFromList(m_togetherplaylist);
        emit togetherplaylistUpdated();
    }
}

void PlaylistManager::setposistion(float positionvalue)
{
    cancelClimaxPreview();
    qint64 position                   = positionvalue * m_player->duration();
    QMediaPlayer::PlaybackState state = m_player->playbackState();
    if (state == QMediaPlayer::PlayingState)
    {
        m_player->setPosition(position);
    }
    else if (m_player->source().isValid())
    {
        m_player->setPosition(position);
        m_player->play();
        m_isPaused = false;
        emit isPausedChanged();
        fadeInVolume(); // 暂停/停止态点进度条恢复播放：音量已被暂停淡出降到 0，需淡入恢复
    }
    else
    {
        qDebug() << "未在播放状态且无有效源";
    }
}
// 类中添加辅助函数
QList<SongInfo> PlaylistManager::convertToSongInfoList(const QVariantList &variantList)
{
    QList<SongInfo> result;
    for (const QVariant &item : variantList)
    {
        QVariantMap map = item.toMap();
        result.append(
            SongInfo{
                map["songname"].toString(), map["songhash"].toString(), "", map["singername"].toString(),
                map["union_cover"].toString(), map["album_name"].toString(), map["duration"].toString(), ""
            }
        );
    }
    return result;
}
int PlaylistManager::currentIndex() const
{
    return m_currentIndex;
}

QString PlaylistManager::currentTitle() const
{
    if (m_climaxPreviewing && !m_climaxPreviewTitle.isEmpty())
        return m_climaxPreviewTitle;
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].title;
    }
    return "";
}

QString PlaylistManager::currentsingername() const
{
    if (m_climaxPreviewing && !m_climaxPreviewSinger.isEmpty())
        return m_climaxPreviewSinger;
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].singername;
    }
    return "";
}

QString PlaylistManager::currentSongHash() const
{
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].songhash;
    }
    return "";
}

// 当前歌的评论用 album_audio_id：一起听场景由服务器解析下发；本地播放为空（评论走歌名搜索兜底）
QString PlaylistManager::currentSongMxid() const
{
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].mxid;
    }
    return "";
}

bool PlaylistManager::isPaused() const
{
    // 试听中视为播放状态：底栏/播放页显示暂停键，点击即结束试听
    if (m_climaxPreviewing)
        return false;
    return m_isPaused;
}

QString PlaylistManager::union_cover() const
{
    if (m_climaxPreviewing && !m_climaxPreviewCover.isEmpty())
        return m_climaxPreviewCover;
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].union_cover;
    }
    return "";
}

QString PlaylistManager::getpercentstr() const
{
    if (m_climaxPreviewing)
        return m_climaxPreviewPosStr;
    return m_percentstr;
}

QString PlaylistManager::durationstr()
{
    if (m_climaxPreviewing)
        return m_climaxPreviewDurationStr;
    return m_duration;
}

qint64 PlaylistManager::playerDuration() const
{
    return m_player->duration();
}

QList<SongInfo> PlaylistManager::playlist()
{
    return m_playlist;
}

SongListModel *PlaylistManager::playlistModel()
{
    return m_playlistModel;
}

QList<SongInfo> PlaylistManager::togetherplaylist()
{
    return m_togetherplaylist;
}

SongListModel *PlaylistManager::togetherplaylistModel()
{
    return m_togetherplaylistModel;
}

void PlaylistManager::clearTogetherSongHash()
{
    m_currentTogetherSongHash.clear();
}

int PlaylistManager::playlistcount() const
{
    return (*m_curplaylist).size();
}

int PlaylistManager::playlistTotalCount() const
{
    // 懒加载模式返回源总数，否则返回队列实际大小
    if (!m_lazySourceId.isEmpty())
        return m_lazyTotal;
    return m_playlist.size();
}

QString PlaylistManager::getcurrlyric() const
{
    return currlyric;
}

int PlaylistManager::lyricCharIndexget()
{
    return m_lyricCharIndex;
}

float PlaylistManager::lyricCharProgressget()
{
    return m_lyricCharProgress;
}

QVariantList PlaylistManager::lyricCharsget()
{
    return m_lyricChars;
}

int PlaylistManager::lyricCharCountget()
{
    return m_lyricCharCount;
}

PlaylistType PlaylistManager::getplaylist_type() const
{
    return type;
}

qreal PlaylistManager::downloadProgress() const
{
    return m_downloadProgress;
}

bool PlaylistManager::isBuffering() const
{
    return m_isBuffering;
}

void PlaylistManager::changeplaylisttype(enum PlaylistType changetype)
{
    if (changetype == type)
    {
        return;
    }
    if (changetype == TOGETHER)
    {
        // 切到一起听前，暂停并保存本地播放状态
        m_player->pause();
        m_isPaused = true;
        emit isPausedChanged();
        m_localPaused  = false; // 新房间从无本地暂停状态开始
        m_localIndex   = m_currentIndex;
        m_localPercent = m_percent;
        type           = TOGETHER;
        m_curplaylist  = &m_togetherplaylist;
        m_currentIndex = -1;
        emit currentIndexChanged(-1);
    }
    else if (changetype == LOCAL)
    {
        type = LOCAL;
        m_localPaused = false;
        m_currentTogetherSongHash.clear();
        m_curplaylist = &m_playlist;
        // 恢复本地播放索引并加载歌曲（暂停状态）
        if (m_localIndex >= 0 && m_localIndex < m_playlist.size())
        {
            m_currentIndex = m_localIndex;
            loadSongPaused(m_localIndex);
        }
    }
    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();
    emit playlist_typeChanged();
}

float PlaylistManager::getpercent() const
{
    if (m_climaxPreviewing)
        return m_climaxPreviewPercent;
    return m_percent;
}

// 边下边播共享逻辑（startPlayback 与 playTogetherSongFromServer 共用）
void PlaylistManager::downloadAndStream(
    const QString &songUrl, const QString &songHash, const QString &cacheFilePath, const QString &coverUrlForColor,
    double seekPercent, std::function<void()> onStreamStart
)
{
    // flac 边下边播：500KB 阈值会在播放中遇到写盘中的截断帧（invalid sync code），
    // 提高阈值到 2MB（flac 帧约 16KB，2MB ≈ 120+ 完整帧），与 mp3 同一播放路径
    const qint64 startThreshold = cacheFilePath.endsWith(QLatin1String(".flac"))
                                      ? 2 * 1024 * 1024
                                      : 500 * 1024; // mp3/320: 500KB 后开始播放

    // 音质子目录（songs/128|320|flac）可能尚未创建
    QDir().mkpath(QFileInfo(cacheFilePath).absolutePath());
    // 消费一次取歌期望值（字节数 + 内容 MD5），防止陈旧值泄漏到后续无关下载
    const qint64 expectBytes = m_pendingFileSize;
    const QString expectMd5  = m_pendingFileMd5.toLower();
    m_pendingFileSize = 0;
    m_pendingFileMd5.clear();
    // 会话内记住该文件的期望 MD5：播放前校验时兼容不同页面携带的不同 hash 口味
    if (!expectMd5.isEmpty())
        m_sessionFileMd5[cacheFilePath] = expectMd5;
    QFile *tempFile = new QFile(cacheFilePath, this);
    if (!tempFile->open(QIODevice::WriteOnly))
    {
        qCritical() << "Cannot open cache file:" << cacheFilePath;
        return;
    }

    QNetworkAccessManager *mgr = new QNetworkAccessManager(this);
    QNetworkReply *reply       = mgr->get(QNetworkRequest(QUrl(songUrl)));

    m_downloadProgress   = 0.0;
    m_downloadedBytes    = 0;
    m_totalDownloadBytes = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
    emit downloadProgressChanged();
    // 续播（音质切换）：seek 目标对应的字节数，下载到该位置才开播，避免 seek 超出已下载区
    const qint64 seekBytes = seekPercent > 0 && m_totalDownloadBytes > 0
                                 ? static_cast<qint64>(seekPercent * m_totalDownloadBytes)
                                 : 0;
    // 登记下载中文件：退出时析构删除半截（见 ~PlaylistManager）
    m_activeDownloadFiles.insert(cacheFilePath);
    // 代际递增：同路径若有在途旧下载，其回调将检测到被接管并静默退出
    const qint64 myGen = ++m_downloadGen[cacheFilePath];

    QObject::connect(
        reply, &QNetworkReply::readyRead, this,
        [=]()
        {
            QByteArray chunk = reply->readAll();
            if (!chunk.isEmpty())
            {
                tempFile->write(chunk);
                tempFile->flush();
                m_downloadedBytes += chunk.size();
                if (m_totalDownloadBytes > 0)
                {
                    m_downloadProgress = static_cast<qreal>(m_downloadedBytes) / m_totalDownloadBytes;
                    emit downloadProgressChanged();
                }
            }

            // 达到阈值且尚未开始播放 -> 设置源并播放
            // 续播时额外要求 seek 目标字节已下载到位（flac 2MB 阈值 < 3 分钟处的 ~12MB）
            QFileInfo fi(cacheFilePath);
            if (fi.size() >= startThreshold && m_player->source().isEmpty()
                && (seekBytes == 0 || fi.size() >= seekBytes))
            {
                m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
                // seekPercent > 0：等 LoadedMedia 后 seek 再播放；否则直接播放
                if (seekPercent > 0)
                {
                    auto conn = std::make_shared<QMetaObject::Connection>();
                    *conn     = connect(
                        m_player, &QMediaPlayer::mediaStatusChanged, this,
                        [this, seekPercent, conn](QMediaPlayer::MediaStatus status)
                        {
                            if (status == QMediaPlayer::LoadedMedia)
                            {
                                seekToPercent(seekPercent);
                                m_player->play();
                                m_isPaused = false;
                                emit isPausedChanged();
                                QObject::disconnect(*conn);
                            }
                        }
                    );
                }
                else
                {
                    m_player->play();
                    m_isPaused = false;
                    emit isPausedChanged();
                }
                if (onStreamStart)
                    onStreamStart();
            }
        }
    );

    // 下载失败/取消：一律删除半截文件。
    QObject::connect(
        reply, &QNetworkReply::errorOccurred, this,
        [=](QNetworkReply::NetworkError err)
        {
            // 被同路径的新下载接管：只清理自己的句柄，不删新下载正在写的文件
            if (m_downloadGen.value(cacheFilePath) != myGen)
                return;
            qWarning() << "下载失败:" << err << songUrl;
            m_activeDownloadFiles.remove(cacheFilePath);
            tempFile->remove();
            if (m_player->source().isEmpty())
            {
                m_isPaused    = true;
                m_isBuffering = false;
                emit isPausedChanged();
            }
        }
    );

    QObject::connect(
        reply, &QNetworkReply::finished, this,
        [=]()
        {
            m_activeDownloadFiles.remove(cacheFilePath);
            tempFile->flush();
            tempFile->close();

            // 被同路径的新下载接管：不校验、不删改文件、不动播放状态，静默退出
            if (m_downloadGen.value(cacheFilePath) != myGen)
                return;

            // 完整性校验：字节数（快，优先接口 fileSize，兜底 HTTP Content-Length）
            const qint64 actual = QFileInfo(cacheFilePath).size();
            const qint64 expect = expectBytes > 0 ? expectBytes : m_totalDownloadBytes;
            QString failReason;
            if (expect > 0 && actual != expect)
                failReason = QStringLiteral("字节数不符（期望 %1 实际 %2）").arg(expect).arg(actual);
            else if (!expectMd5.isEmpty())
            {
                QCryptographicHash md5(QCryptographicHash::Md5);
                QFile vf(cacheFilePath);
                if (vf.open(QIODevice::ReadOnly))
                {
                    md5.addData(&vf);
                    vf.close();
                }
                if (md5.result().toHex() != expectMd5)
                    failReason = QStringLiteral("MD5 不符（期望 %1 实际 %2）")
                                     .arg(expectMd5, QString::fromLatin1(md5.result().toHex()));
            }
            if (!failReason.isEmpty())
            {
                qWarning() << "缓存完整性校验失败（" << failReason << "），删除:" << cacheFilePath;
                QFile::remove(cacheFilePath);  // Windows 下若播放器仍占用则删不掉，靠下次播放前的 MD5 校验兜底
                if (m_player->source().toLocalFile() == cacheFilePath)
                {
                    m_player->stop();
                    m_player->setSource(QUrl());
                }
                // 不对就重新下载：同曲最多自动重下 2 次（首次下载 + 2 次重试），
                // 仍失败则放弃并走取址失败统一收尾（本地模式跳下一首/一起听暂停提示），绝不死循环
                const int fails = ++m_integrityFailCount[songHash.toUpper()];
                if (fails <= 2)
                {
                    m_isBuffering = false;
                    emit isBufferingChanged();
                    fetchSongUrl(
                        songHash,
                        [this, songHash, cacheFilePath, coverUrlForColor, seekPercent, onStreamStart](const QString &url)
                        {
                            if (!url.isEmpty())
                                downloadAndStream(url, songHash, cacheFilePath, coverUrlForColor, seekPercent,
                                                  onStreamStart);
                        },
                        true);  // 重试链：保留失败计数不清零
                }
                else
                {
                    m_integrityFailCount.remove(songHash.toUpper());  // 放弃后清零，用户再点播可重新来过
                    handleSongUrlFailed(songHash, QStringLiteral("缓存文件多次校验失败，已放弃下载"));
                }
                return;
            }

            m_integrityFailCount.remove(songHash.toUpper());  // 校验通过：清零失败计数
            m_downloadProgress = 1.0;
            m_downloadedBytes  = m_totalDownloadBytes;
            emit downloadProgressChanged();
            if (m_isBuffering)
            {
                m_isBuffering = false;
                m_player->play();
                emit isBufferingChanged();
            }
            qDebug() << "下载完成:" << cacheFilePath;

            // 文件太小未触发阈值时，手动设置源并播放（一起听场景需要）
            if (m_player->source().isEmpty() && QFile::exists(cacheFilePath))
            {
                m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
                if (seekPercent > 0)
                {
                    auto conn = std::make_shared<QMetaObject::Connection>();
                    *conn     = connect(
                        m_player, &QMediaPlayer::mediaStatusChanged, this,
                        [this, seekPercent, conn](QMediaPlayer::MediaStatus status)
                        {
                            if (status == QMediaPlayer::LoadedMedia)
                            {
                                seekToPercent(seekPercent);
                                m_player->play();
                                m_isPaused = false;
                                emit isPausedChanged();
                                QObject::disconnect(*conn);
                            }
                        }
                    );
                }
                else
                {
                    m_player->play();
                    m_isPaused = false;
                    emit isPausedChanged();
                }
                if (onStreamStart)
                    onStreamStart();
            }

            // 释放本次下载资源（避免累积泄漏）
            reply->deleteLater();
            mgr->deleteLater();
            tempFile->deleteLater();
        }
    );

    // 颜色提取：本地播放路径需要，一起听路径 coverUrlForColor 传空跳过
    if (!coverUrlForColor.isEmpty())
    {
        m_colorExtractor->extract(coverUrlForColor);
    }
}

void PlaylistManager::startFmPeakPreview(const SongInfo &song)
{
    m_fmPeakAdvanceOnFinish = false;
    if (m_climaxPreviewing)
        cancelClimaxPreview();

    // 主播放器不加载整首：只走试听片段引擎（/song/climax/url + 30 秒字节范围）
    m_player->stop();
    m_player->setSource(QUrl());
    m_isPaused = false;
    emit isPausedChanged();

    addToRecent(song);
    startClimaxPreview(song.songhash, song.title, song.singername, song.union_cover);

    m_isPaused = false;
    emit isPausedChanged();
}

void PlaylistManager::startPlayback(const SongInfo &song)
{
    // 个人FM 30秒模式：直接复用试听片段引擎，主播放器不加载整首歌
    if (m_fmPeakMode && type == LOCAL)
    {
        startFmPeakPreview(song);
        return;
    }
    cancelClimaxPreview();
    m_mainLyricRaw.clear();  // 主歌切换：清除上一首歌词原文，试听恢复时不串歌
    // 记录到最近播放
    addToRecent(song);

    // 停止播放器，防止文件句柄未释放
    m_player->stop();
    m_player->setSource(QUrl());

    // 重置下载状态
    m_downloadProgress   = 1.0;
    m_isBuffering        = false;
    m_downloadedBytes    = 0;
    m_totalDownloadBytes = 0;
    emit downloadProgressChanged();
    emit isBufferingChanged();

    // 重置进度：新歌从 0 开始。避免上一首自然播完时的 ~1.0 残留，
    // 导致媒体控制栏(currentSongChanged 触发)把下一首进度显示在末尾。
    m_percent    = 0.0f;
    m_percentstr = "00:00";
    emit percentChanged();

    // 立即通知媒体控制栏更新标题/歌手/封面 URL——封面由 NowPlaying 异步下载，
    // 这样切歌瞬间媒体栏就能反映新歌信息，不必等边下边播达到阈值。
    emit currentSongChanged();

    // 下载/缓冲期间即显示"播放中"（边下边播）：否则播放按钮停留在"播放"图标，
    // 用户点击时 source 无效被忽略（"没设置URL"），看起来点了没反应
    m_isPaused = false;
    emit isPausedChanged();

    // 音质切换续播：取出本次换源的续播进度（消费一次，其余调用不受影响）
    const double resumePercent = m_resumePercentAfterSwitch;
    m_resumePercentAfterSwitch = -1.0f;

    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = PlaylistCacheStore::songCachePath(song.title, song.singername, m_quality);

    // 本地缓存命中：直接播放（各音质独立目录，互不影响）。
    bool playLocal = QFile::exists(cacheFilePath);
    if (playLocal && !verifyCachedFileMd5(cacheFilePath, song.songhash))
    {
        qWarning() << "缓存 MD5 校验失败，删除重新下载:" << cacheFilePath;
        QFile::remove(cacheFilePath);
        playLocal = false;
    }
    if (playLocal)
    {
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;
        m_player->stop();
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
        if (resumePercent > 0 && resumePercent < 1.0)
        {
            // 续播：LoadedMedia 后 seek 再播放
            auto conn = std::make_shared<QMetaObject::Connection>();
            *conn     = connect(
                m_player, &QMediaPlayer::mediaStatusChanged, this,
                [this, resumePercent, conn](QMediaPlayer::MediaStatus status)
                {
                    if (status == QMediaPlayer::LoadedMedia)
                    {
                        seekToPercent(resumePercent);
                        m_player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                        QObject::disconnect(*conn);
                    }
                }
            );
        }
        else
        {
            m_player->play();
        }
        m_isPaused = false;
        m_colorExtractor->extract(song.union_cover);
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
        return;
    }

    // 无缓存：边下边播（下载逻辑与一起听路径共用 downloadAndStream）
    downloadAndStream(song.url, song.songhash, cacheFilePath, song.union_cover, resumePercent, nullptr);
}

// 保存播放列表到本地缓存
void PlaylistManager::savePlaylistToCache()
{
    // TOGETHER 模式下保存切换前的本地索引和进度，而非一起听的
    const int idx   = (type == TOGETHER) ? m_localIndex : m_currentIndex;
    const float pct = (type == TOGETHER) ? m_localPercent : m_percent;
    PlaylistCacheStore::savePlaylist(m_playlist, idx, pct, m_playMode);
}

// 从本地缓存加载播放列表
void PlaylistManager::loadPlaylistFromCache()
{
    int savedIndex     = -1;
    float savedPercent = 0.0f;
    int savedPlayMode  = -1;
    if (!PlaylistCacheStore::loadPlaylist(m_playlist, savedIndex, savedPercent, savedPlayMode))
        return;

    // 恢复播放模式（旧缓存无该字段时保持默认顺序播放）
    if (savedPlayMode >= MODE_ORDER && savedPlayMode <= MODE_RANDOM)
    {
        m_playMode = savedPlayMode;
        emit playModeChanged();
        qDebug() << "从缓存恢复播放模式:" << m_playMode;
    }

    m_playlistModel->syncFromList(m_playlist);
    emit playlistUpdated();

    // 恢复上次播放的歌曲和进度
    if (savedIndex >= 0 && savedIndex < m_playlist.size())
    {
        m_currentIndex   = savedIndex;
        m_restorePercent = savedPercent;
        emit currentIndexChanged(savedIndex);
        emit currentSongChanged();
        qDebug() << "从缓存恢复播放: index=" << savedIndex << "percent=" << savedPercent;
    }
    else
    {
        m_currentIndex = -1;
        emit currentIndexChanged(-1);
    }
    qDebug() << "从缓存加载播放列表，共" << m_playlist.size() << "首歌曲";
}

void PlaylistManager::restoreLastPlayback()
{
    if (m_restorePercent < 0 || m_currentIndex < 0 || m_currentIndex >= m_playlist.size())
        return;

    float seekPercent = m_restorePercent;
    m_restorePercent  = -1.0f;

    int index     = m_currentIndex;
    SongInfo song = m_playlist[index];

    // 加载歌词
    if (song.lyric.isEmpty())
    {
        QString cachedLyric = loadLyricFromCache(song.songhash);
        if (!cachedLyric.isEmpty())
        {
            m_playlist[index].lyric = cachedLyric;
            m_lyricParser.parseKRCLyrics(cachedLyric);
        }
        else
        {
            fetchLyricData(
                song.songhash,
                [this](const QString &lyric)
                {
                    if (!lyric.isEmpty())
                        m_lyricParser.parseKRCLyrics(lyric);
                }
            );
        }
    }
    else
    {
        m_lyricParser.parseKRCLyrics(song.lyric);
    }

    m_colorExtractor->extract(song.union_cover);
    emit currentIndexChanged(index);
    emit currentSongChanged();

    // 加载歌曲但不播放
    m_player->stop();
    m_player->setSource(QUrl());

    auto conn = std::make_shared<QMetaObject::Connection>();
    *conn     = connect(
        m_player, &QMediaPlayer::mediaStatusChanged, this,
        [this, seekPercent, conn](QMediaPlayer::MediaStatus status)
        {
            if (status == QMediaPlayer::LoadedMedia)
            {
                if (seekPercent > 0 && seekPercent < 1.0)
                {
                    if (m_player->duration() > 0)
                        seekToPercent(seekPercent);
                    else
                    {
                        // duration 未就绪时 seek 无效（实测 LoadedMedia 时 duration 可能为 0）
                        auto dconn = std::make_shared<QMetaObject::Connection>();
                        *dconn     = connect(
                            m_player, &QMediaPlayer::durationChanged, this,
                            [this, seekPercent, dconn]()
                            {
                                seekToPercent(seekPercent);
                                QObject::disconnect(*dconn);
                            }
                        );
                    }
                }
                // 用户曾点过播放（source 未就绪时排队）：就绪后自动续播
                if (m_pendingPlayWhenReady)
                {
                    m_pendingPlayWhenReady = false;
                    m_player->play();
                    m_isPaused = false;
                    emit isPausedChanged();
                }
                else
                {
                    m_player->pause();
                    m_isPaused = true;
                    emit isPausedChanged();
                }
                QObject::disconnect(*conn);
            }
        }
    );

    // 优先使用本地缓存文件，避免过期 URL 导致 403
    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = PlaylistCacheStore::songCachePath(song.title, song.singername, m_quality);
    if (QFile::exists(cacheFilePath))
    {
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
    }
    else
    {
        fetchSongUrl(
            song.songhash,
            [this](const QString &url)
            {
                if (!url.isEmpty())
                    m_player->setSource(QUrl(url));
            }
        );
    }
}

// 保存歌词到本地缓存
void PlaylistManager::saveLyricToCache(const QString &songhash, const QString &lyric)
{
    PlaylistCacheStore::saveLyric(songhash, lyric);
}

// 从本地缓存加载歌词
QString PlaylistManager::loadLyricFromCache(const QString &songhash)
{
    return PlaylistCacheStore::loadLyric(songhash);
}

void PlaylistManager::fetchClimax(const QString &hash)
{
    if (hash.isEmpty())
    {
        setClimaxPercent(0);
        return;
    }
    // 去重：同 hash 正在请求中跳过（底栏 + 播放页两个 ClimaxDot 切歌时各触发一次，合并为一次请求）
    if (m_climaxHash == hash)
        return;
    m_climaxHash = hash;
    setClimaxPercent(0);  // 切歌先清旧高潮点

    // 本地缓存命中：直接换算，不发请求（duration 未就绪时保持 0，
    // LoadedMedia 就绪后既有补请求机制重试，重试仍命中缓存）
    loadClimaxCache();
    const QString key = hash.toUpper();
    if (m_climaxCache.contains(key))
    {
        const qint64 cachedStart = m_climaxCache.value(key);
        if (cachedStart > 0)
        {
            const qint64 totalMs = parseDurationMs(m_duration);
            if (totalMs > 0)
                setClimaxPercent(qMin(qreal(cachedStart) / totalMs, 1.0));
        }
        // cachedStart<=0 = 已知该曲无高潮点：保持 0
        return;
    }

    m_climaxPending = true;
    ApiClient::instance().get(
        QString("https://api.special520.com/song/climax?hash=%1").arg(hash),
        [this, hash, key](QByteArray body) {
            if (m_climaxHash != hash)  // 迟到核对：期间已切歌则丢弃
                return;
            m_climaxPending = false;
            qreal pct = 0;
            QJsonParseError pe;
            const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
            if (pe.error == QJsonParseError::NoError && doc.isObject())
            {
                const QJsonObject o = doc.object();
                if (o.value("status").toInt() == 1)
                {
                    const QJsonArray arr = o.value("data").toArray();
                    if (!arr.isEmpty() && arr[0].isObject())
                    {
                        const qint64 startMs = arr[0].toObject().value("start_time").toVariant().toLongLong();
                        // 先落缓存再算（与 duration 是否就绪无关）：
                        // duration 未就绪的补请求重试将直接命中缓存
                        if (startMs > 0)
                            saveClimaxCacheEntry(key, startMs);
                        const qint64 totalMs = parseDurationMs(m_duration);
                        if (totalMs <= 0)
                        {
                            // duration 未就绪（恢复播放/流媒体刚启动）：不算死成 0，
                            // m_climaxHash 保持标记，duration 就绪后自动补请求重试
                            return;
                        }
                        pct = qMin(qreal(startMs) / totalMs, 1.0);
                    }
                    else
                    {
                        // 服务端确认该曲无高潮数据：也缓存（存 0），重播不再询问
                        saveClimaxCacheEntry(key, 0);
                    }
                }
            }
            setClimaxPercent(pct);
        },
        [this, hash](QString, int) {
            if (m_climaxHash == hash)
            {
                m_climaxPending = false;
                setClimaxPercent(0);
            }
        },
        10000
    );
}

void PlaylistManager::loadClimaxCache()
{
    if (m_climaxCacheLoaded)
        return;
    m_climaxCacheLoaded = true;
    QFile f(PlaylistCacheStore::configPath("climax_cache.json"));
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    const QJsonObject o = doc.object();
    for (auto it = o.begin(); it != o.end(); ++it)
        m_climaxCache.insert(it.key(), it.value().toVariant().toLongLong());
}

void PlaylistManager::saveClimaxCacheEntry(const QString &hash, qint64 startMs)
{
    if (m_climaxCache.value(hash, -1) == startMs)
        return;
    m_climaxCache.insert(hash, startMs);
    QJsonObject o;
    for (auto it = m_climaxCache.cbegin(); it != m_climaxCache.cend(); ++it)
        o.insert(it.key(), double(it.value()));
    QFile f(PlaylistCacheStore::configPath("climax_cache.json"));
    if (f.open(QIODevice::WriteOnly))
    {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
        f.close();
    }
}

void PlaylistManager::setClimaxPercent(qreal p)
{
    if (qFuzzyCompare(m_climaxPercent, p))
        return;
    m_climaxPercent = p;
    emit climaxPercentChanged();
}

qint64 PlaylistManager::parseDurationMs(const QString &str)
{
    if (str.isEmpty())
        return 0;
    if (str.contains(':'))
    {
        const auto parts = str.split(':');
        if (parts.size() == 2)
            return (parts[0].toInt() * 60 + parts[1].toInt()) * 1000;
    }
    return static_cast<qint64>(str.toDouble() * 1000);
}

void PlaylistManager::toggleClimaxPreview(
    const QString &hash, const QString &title, const QString &singer, const QString &cover
)
{
    if (hash.isEmpty())
        return;
    // 同一首再点一次 = 结束试听；其他歌 = 切换片段（保留最初的主播放状态）
    if (m_climaxPreviewing && m_climaxPreviewHash.compare(hash, Qt::CaseInsensitive) == 0)
    {
        finishClimaxPreview(true);
        return;
    }
    startClimaxPreview(hash, title, singer, cover);
}

void PlaylistManager::startClimaxPreview(
    const QString &hash, const QString &title, const QString &singer, const QString &cover
)
{
    const bool wasPreviewing = m_climaxPreviewing;
    if (!wasPreviewing)
    {
        m_climaxResumeWasPlaying = (m_player->playbackState() == QMediaPlayer::PlayingState);
        m_climaxResumePosition   = m_player->position();
        // 保存主歌歌词与偏移，试听结束后原样恢复
        m_savedMainLyricRaw.clear();
        if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
            m_savedMainLyricRaw = (*m_curplaylist)[m_currentIndex].lyric;
        if (m_savedMainLyricRaw.isEmpty())
            m_savedMainLyricRaw = m_mainLyricRaw;
        if (m_savedMainLyricRaw.isEmpty())
            m_savedMainLyricRaw = loadLyricFromCache(currentSongHash());
        m_savedLyricOffsetMs   = m_lyricOffsetMs;
        m_savedLyricOffsetHash = m_lyricOffsetSongHash;
    }

    m_climaxFinishing      = false;
    m_climaxRequestHash    = hash;
    m_climaxPreviewHash    = hash;
    m_climaxPreviewTitle   = title;
    m_climaxPreviewSinger  = singer;
    m_climaxPreviewCover   = cover;
    m_climaxPreviewing     = true;
    m_climaxPlayStarted    = false;
    m_climaxStartMs        = 0;
    m_climaxEndMs          = 0;
    m_climaxPreviewPercent = 0.0;
    m_climaxPreviewPosStr  = "00:00";
    m_climaxPreviewDurationStr = "00:00";
    emit currentSongChanged();  // 底栏/播放页临时显示试听歌曲信息
    emit isPausedChanged();
    emit percentChanged();
    emit durationChanged();
    emit climaxPreviewChanged();
    loadClimaxPreviewLyric(hash);  // 歌词切到试听歌曲，并跟随试听进度滚动

    auto playNew = [this, hash]()
    {
        if (!m_climaxPreviewing || m_climaxRequestHash != hash || m_climaxFinishing)
            return;
        fetchClimaxPreview(hash);
    };

    if (wasPreviewing)
    {
        // A 歌高潮切到 B 歌高潮：旧片段快速淡出后再取新片段
        fadeClimaxVolume(
            0.0, 160,
            [this, playNew]()
            {
                if (m_climaxFinishing)
                    return;
                m_climaxFinishing = true;  // 清空 source 触发的错误不再按试听失败处理
                releaseClimaxBuffer();
                m_climaxPlayer->stop();
                m_climaxPlayer->setSource(QUrl());
                m_climaxFinishing = false;
                m_climaxOutput->setVolume(0.0);
                playNew();
            }
        );
        return;
    }

    if (m_climaxResumeWasPlaying)
    {
        // 主播放先淡出再暂停（保留进度），之后才起高潮片段，避免两路声音叠加
        fadeOutVolume(
            280,
            [this, playNew]()
            {
                if (!m_climaxPreviewing || m_climaxFinishing)
                    return;
                if (m_player->playbackState() == QMediaPlayer::PlayingState)
                    m_player->pause();
                if (!m_fmPeakMode)
                {
                    m_isPaused = true;
                    emit isPausedChanged();
                }
                playNew();
            }
        );
    }
    else
    {
        // 原本就没在播：静音主输出后直接取片段
        m_audioOutput->setVolume(0.0);
        playNew();
    }
}

void PlaylistManager::updateClimaxPreviewProgress(qint64 positionMs)
{
    if (m_climaxEndMs <= m_climaxStartMs)
        return;
    const qint64 span      = m_climaxEndMs - m_climaxStartMs;
    const qint64 rel       = qBound<qint64>(0, positionMs - m_climaxStartMs, span);
    m_climaxPreviewPercent = qreal(rel) / qreal(span);
    m_climaxPreviewPosStr  = formatTime(rel);
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastPercentNotifyMs >= 1000 / 24)
    {
        m_lastPercentNotifyMs = now;
        emit percentChanged();
    }
}

void PlaylistManager::setClimaxPreviewPosition(qreal percent)
{
    if (!m_climaxPreviewing || m_climaxEndMs <= m_climaxStartMs)
        return;
    const qint64 span       = m_climaxEndMs - m_climaxStartMs;
    const qint64 songTarget = m_climaxStartMs + qint64(qBound(0.0, percent, 1.0) * qreal(span));
    const qint64 mediaTarget = qMax<qint64>(0, songTarget - m_climaxMediaOffsetMs);
    m_climaxPlayer->setPosition(mediaTarget);
    updateClimaxPreviewProgress(songTarget);
}

qint64 PlaylistManager::climaxSongPosition() const
{
    return m_climaxPlayer->position() + m_climaxMediaOffsetMs;
}

void PlaylistManager::fetchClimaxAudioRange(
    const QString &url, qint64 startByte, qint64 endByte, const QString &hash, qint64 startMs
)
{
    if (m_climaxReply)
    {
        m_climaxReply->abort();
        m_climaxReply->deleteLater();
        m_climaxReply = nullptr;
    }
    if (m_climaxBuffer)
    {
        m_climaxPlayer->stop();
        m_climaxPlayer->setSource(QUrl());
        m_climaxBuffer->close();
        m_climaxBuffer->deleteLater();
        m_climaxBuffer = nullptr;
    }

    QNetworkRequest request{QUrl(url)};
    request.setRawHeader("Range", QStringLiteral("bytes=%1-%2").arg(startByte).arg(endByte).toUtf8());
    QNetworkReply *reply = m_climaxNam->get(request);
    m_climaxReply        = reply;
    connect(
        reply, &QNetworkReply::finished, this,
        [this, reply, hash, url, startMs]()
        {
            if (m_climaxReply != reply)  // 已被新的试听请求/结束操作取代
            {
                reply->deleteLater();
                return;
            }
            m_climaxReply = nullptr;
            reply->deleteLater();
            if (!m_climaxPreviewing || m_climaxRequestHash != hash || m_climaxFinishing)
                return;
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (reply->error() != QNetworkReply::NoError || status != 206)
            {
                // 极少数 CDN 不支持 Range：回退直接播片段 URL
                m_climaxBufferMode    = false;
                m_climaxMediaOffsetMs = 0;
                m_climaxPlayer->setSource(QUrl(url));
                return;
            }
            QByteArray data = reply->readAll();
            // 从字节中间开始，向前找 MP3 帧头对齐，避免开头爆音
            int align     = 0;
            const int scan = qMin(4096, int(data.size()) - 1);
            for (int i = 0; i < scan; ++i)
            {
                if (quint8(data.at(i)) == 0xFF && (quint8(data.at(i + 1)) & 0xE0) == 0xE0)
                {
                    align = i;
                    break;
                }
            }
            if (align > 0)
                data.remove(0, align);
            if (data.size() < 4096)
            {
                m_climaxBufferMode    = false;
                m_climaxMediaOffsetMs = 0;
                m_climaxPlayer->setSource(QUrl(url));
                return;
            }
            m_climaxBuffer = new QBuffer(this);
            m_climaxBuffer->setData(data);
            m_climaxBuffer->open(QIODevice::ReadOnly);
            m_climaxBufferMode    = true;
            m_climaxMediaOffsetMs = startMs;
            // 只播内存中的高潮段，不写本地文件，也不需要网络 seek
            m_climaxPlayer->setSourceDevice(m_climaxBuffer, QUrl(QStringLiteral("climax.mp3")));
        }
    );
}

void PlaylistManager::releaseClimaxBuffer()
{
    if (m_climaxReply)
    {
        m_climaxReply->abort();
        m_climaxReply->deleteLater();
        m_climaxReply = nullptr;
    }
    if (m_climaxBuffer)
    {
        m_climaxPlayer->stop();
        m_climaxPlayer->setSource(QUrl());
        m_climaxBuffer->close();
        m_climaxBuffer->deleteLater();
        m_climaxBuffer     = nullptr;
        m_climaxBufferMode = false;
        m_climaxMediaOffsetMs = 0;
    }
}

void PlaylistManager::loadClimaxPreviewLyric(const QString &hash)
{
    // 先清空并一次性通知，避免旧行/旧字符与新歌词列表混用
    m_lyricParser.clear();
    m_lastRawPosMs        = -1;
    currlyric.clear();
    m_lyricCharIndex      = -1;
    m_lyricCharProgress   = 0.0f;
    m_lyricChars.clear();
    m_lyricCharCount      = 0;
    m_lyricOffsetMs       = 0;
    m_lyricOffsetSongHash = hash;
    emit parlyricsuc();
    emit currlyricChanged();
    fetchLyricData(
        hash,
        [this, hash](const QString &lyric)
        {
            if (!m_climaxPreviewing || m_climaxPreviewHash.compare(hash, Qt::CaseInsensitive) != 0)
                return;
            if (lyric.isEmpty())
                return;
            // 不触发中间态信号：解析完成后统一重建行/字符状态再通知 QML
            m_lyricParser.parseKRCLyrics(lyric, false);
            m_lastRawPosMs        = -1;
            currlyric.clear();
            m_lyricCharIndex      = -1;
            m_lyricCharProgress   = 0.0f;
            m_lyricChars.clear();
            m_lyricCharCount      = 0;
            m_lyricOffsetSongHash = hash;
            m_lyricOffsetMs       = 0;
            updateLyricProgress(climaxSongPosition());
            emit parlyricsuc();
            emit currlyricChanged();
        }
    );
}

void PlaylistManager::restoreMainLyric()
{
    m_lyricParser.clear();
    m_lastRawPosMs      = -1;
    currlyric.clear();
    m_lyricCharIndex    = -1;
    m_lyricCharProgress = 0.0f;
    m_lyricChars.clear();
    m_lyricCharCount    = 0;
    emit parlyricsuc();
    emit currlyricChanged();
    auto apply = [this](const QString &lyric)
    {
        if (lyric.isEmpty())
            return;
        m_lyricParser.parseKRCLyrics(lyric, false);
        m_lastRawPosMs      = -1;
        currlyric.clear();
        m_lyricCharIndex    = -1;
        m_lyricCharProgress = 0.0f;
        m_lyricChars.clear();
        m_lyricCharCount    = 0;
        m_lyricOffsetSongHash = m_savedLyricOffsetHash.isEmpty() ? currentSongHash() : m_savedLyricOffsetHash;
        m_lyricOffsetMs       = m_savedLyricOffsetMs;
        updateLyricProgress(m_player->position());
        emit parlyricsuc();
        emit currlyricChanged();
    };
    if (!m_savedMainLyricRaw.isEmpty())
    {
        apply(m_savedMainLyricRaw);
        return;
    }
    if (!m_mainLyricRaw.isEmpty())
    {
        apply(m_mainLyricRaw);
        return;
    }
    const QString mainHash = currentSongHash();
    if (mainHash.isEmpty())
        return;
    fetchLyricData(
        mainHash,
        [this, mainHash](const QString &lyric)
        {
            if (m_climaxPreviewing || currentSongHash() != mainHash)
                return;
            if (lyric.isEmpty())
                return;
            m_lyricParser.parseKRCLyrics(lyric, false);
            m_lastRawPosMs      = -1;
            currlyric.clear();
            m_lyricCharIndex    = -1;
            m_lyricCharProgress = 0.0f;
            m_lyricChars.clear();
            m_lyricCharCount    = 0;
            m_lyricOffsetSongHash = m_savedLyricOffsetHash.isEmpty() ? mainHash : m_savedLyricOffsetHash;
            m_lyricOffsetMs       = m_savedLyricOffsetMs;
            updateLyricProgress(m_player->position());
            emit parlyricsuc();
            emit currlyricChanged();
        }
    );
}

void PlaylistManager::fetchClimaxPreview(const QString &hash)
{
    const QString requestHash = hash;
    ApiClient::instance().get(
        QString("https://api.special520.com/song/climax/url?hash=%1").arg(hash),
        [this, requestHash](QByteArray body)
        {
            if (!m_climaxPreviewing || m_climaxRequestHash != requestHash || m_climaxFinishing)
                return;
            QJsonParseError pe;
            const QJsonDocument doc = QJsonDocument::fromJson(body, &pe);
            const QJsonObject o      = doc.object();
            const QJsonObject data   = o.value("data").toObject();
            const QString url        = data.value("url").toString();
            const qint64 startMs     = data.value("start_ms").toVariant().toLongLong();
            const qint64 endMs       = data.value("end_ms").toVariant().toLongLong();
            const qint64 startByte   = data.value("start_byte").toVariant().toLongLong();
            const qint64 endByte     = data.value("end_byte").toVariant().toLongLong();
            if (pe.error != QJsonParseError::NoError || o.value("status").toInt() != 1 || url.isEmpty() || endMs <= startMs)
            {
                m_climaxRequestHash.clear();
                if (m_fmPeakMode)
                {
                    m_fmPeakAdvanceOnFinish = true;
                    finishClimaxPreview(false, 120);
                }
                else
                {
                    finishClimaxPreview(true, 120);
                    emit climaxPreviewFailed(QStringLiteral("该歌曲暂无高潮试听"));
                }
                return;
            }
            m_climaxStartMs            = startMs;
            m_climaxEndMs              = endMs;
            m_climaxPlayStarted        = false;
            m_climaxPreviewPercent     = 0.0;
            m_climaxPreviewPosStr      = "00:00";
            m_climaxPreviewDurationStr = formatTime(endMs - startMs);
            emit percentChanged();
            emit durationChanged();
            // 优先按字节范围只取高潮段到内存播放；服务端未给区间时回退直接播片段 URL
            m_climaxBufferMode    = endByte > startByte && (startMs == 0 || startByte > 0);
            m_climaxMediaOffsetMs = m_climaxBufferMode ? startMs : 0;
            if (m_climaxBufferMode)
                fetchClimaxAudioRange(url, startByte, endByte, requestHash, startMs);
            else
                m_climaxPlayer->setSource(QUrl(url));
        },
        [this, requestHash](QString errorString, int)
        {
            if (!m_climaxPreviewing || m_climaxRequestHash != requestHash || m_climaxFinishing)
                return;
            m_climaxRequestHash.clear();
            if (m_fmPeakMode)
            {
                m_fmPeakAdvanceOnFinish = true;
                finishClimaxPreview(false, 120);
            }
            else
            {
                finishClimaxPreview(true, 120);
                emit climaxPreviewFailed(QStringLiteral("高潮试听加载失败：") + errorString);
            }
        },
        10000
    );
}

void PlaylistManager::finishClimaxPreview(bool restorePlayback, int fadeMs)
{
    if (!m_climaxPreviewing || m_climaxFinishing)
        return;
    m_climaxFinishing   = true;
    m_climaxRequestHash.clear();
    m_climaxPlayStarted = false;  // 淡出期间阻止 position/EndOfMedia 重入

    fadeClimaxVolume(
        0.0, qMax(0, fadeMs),
        [this, restorePlayback]()
        {
            m_climaxPreviewing = false;  // 先落状态：清空 source 的错误信号不再进入试听逻辑
            releaseClimaxBuffer();
            m_climaxPlayer->stop();
            m_climaxPlayer->setSource(QUrl());
            m_climaxOutput->setVolume(0.0);
            m_climaxPreviewHash.clear();
            m_climaxPreviewTitle.clear();
            m_climaxPreviewSinger.clear();
            m_climaxPreviewCover.clear();
            m_climaxPreviewPercent     = 0.0;
            m_climaxPreviewPosStr      = "00:00";
            m_climaxPreviewDurationStr = "00:00";
            m_climaxStartMs            = 0;
            m_climaxEndMs              = 0;
            m_climaxFinishing          = false;
            emit climaxPreviewChanged();
            emit currentSongChanged();  // 恢复底栏/播放页的主歌信息
            emit percentChanged();
            emit durationChanged();
            restoreMainLyric();         // 恢复主歌歌词与逐字进度

            if (!restorePlayback)
            {
                m_audioOutput->setVolume(m_targetVolume);
                emit isPausedChanged();
                const bool advanceNext = m_fmPeakAdvanceOnFinish && m_fmPeakMode;
                m_fmPeakAdvanceOnFinish = false;
                if (advanceNext)
                    QTimer::singleShot(0, this, [this]() { playNext(); });
                return;
            }
            // 恢复进入试听前的播放状态：原来在播 → 回到原歌曲原进度继续；
            // 原来暂停/未播 → 保持暂停（只恢复音量，不自动开播）
            if (m_climaxResumeWasPlaying && m_player->source().isValid())
            {
                m_audioOutput->setVolume(0.0);
                m_player->setPosition(m_climaxResumePosition);
                m_player->play();
                m_isPaused = false;
                emit isPausedChanged();
                fadeMainVolumeTo(m_targetVolume, 420);
            }
            else
            {
                m_audioOutput->setVolume(m_targetVolume);
                m_isPaused = (m_player->playbackState() != QMediaPlayer::PlayingState);
                emit isPausedChanged();
            }
        }
    );
}

void PlaylistManager::cancelClimaxPreview()
{
    if (!m_climaxPreviewing)
        return;
    // 主播放操作抢占：立刻停掉试听，不恢复旧状态（新操作自己会接管播放）
    m_climaxFinishing   = true;
    m_climaxRequestHash.clear();
    m_climaxPlayStarted = false;
    m_climaxPreviewing  = false;
    m_climaxPreviewHash.clear();
    m_climaxPreviewTitle.clear();
    m_climaxPreviewSinger.clear();
    m_climaxPreviewCover.clear();
    m_climaxPreviewPercent     = 0.0;
    m_climaxPreviewPosStr      = "00:00";
    m_climaxPreviewDurationStr = "00:00";
    if (m_climaxVolAnim)
    {
        m_climaxVolAnim->stop();
        m_climaxVolAnim->disconnect(this);
    }
    if (m_volAnim)
    {
        m_volAnim->stop();
        m_volAnim->disconnect(this);  // 取消可能还在排队的“淡出后暂停”回调
    }
    releaseClimaxBuffer();
    m_climaxPlayer->stop();
    m_climaxPlayer->setSource(QUrl());
    m_climaxOutput->setVolume(0.0);
    m_climaxStartMs   = 0;
    m_climaxEndMs     = 0;
    m_climaxFinishing = false;
    m_audioOutput->setVolume(m_targetVolume);
    restoreMainLyric();
    emit climaxPreviewChanged();
    emit currentSongChanged();
    emit percentChanged();
    emit durationChanged();
    emit isPausedChanged();
}

void PlaylistManager::fadeClimaxVolume(qreal target, int ms, std::function<void()> onFinished)
{
    if (!m_climaxVolAnim)
        m_climaxVolAnim = new QPropertyAnimation(m_climaxOutput, "volume", this);
    m_climaxVolAnim->stop();
    m_climaxVolAnim->disconnect(this);
    if (onFinished)
        connect(m_climaxVolAnim, &QPropertyAnimation::finished, this, [onFinished]() { onFinished(); });
    m_climaxVolAnim->setStartValue(m_climaxOutput->volume());
    m_climaxVolAnim->setEndValue(qBound(0.0, target, 1.0));
    m_climaxVolAnim->setDuration(qMax(0, ms));
    m_climaxVolAnim->setEasingCurve(QEasingCurve::InOutQuad);
    m_climaxVolAnim->start();
}

void PlaylistManager::fadeMainVolumeTo(qreal target, int ms, std::function<void()> onFinished)
{
    if (!m_volAnim)
        m_volAnim = new QPropertyAnimation(m_audioOutput, "volume", this);
    m_volAnim->stop();
    m_volAnim->disconnect(this);
    if (onFinished)
        connect(m_volAnim, &QPropertyAnimation::finished, this, [onFinished]() { onFinished(); });
    m_volAnim->setStartValue(m_audioOutput->volume());
    m_volAnim->setEndValue(qBound(0.0, target, 1.0));
    m_volAnim->setDuration(qMax(0, ms));
    m_volAnim->setEasingCurve(QEasingCurve::InOutQuad);
    m_volAnim->start();
}

void PlaylistManager::fetchSongUrl(const QString &hash, std::function<void(QString)> callback,
                                   bool keepIntegrityCount)
{
    m_pendingFileSize = 0;  // 每次取址先重置期望大小
    m_pendingFileMd5.clear();
    // 用户主动点播（非校验失败重试链）：清零该曲的完整性失败计数，重新给足重试额度
    if (!keepIntegrityCount)
        m_integrityFailCount.remove(hash.toUpper());
    resolvePrivilegeThenFetch(hash, std::move(callback));
}

void PlaylistManager::resolvePrivilegeThenFetch(const QString &hash, std::function<void(QString)> callback)
{
    // 音质候选（音质档, 该音质文件专属 hash），按当前档位从高到低排列：
    // flac 档 -> [flac,320,128]，320 -> [320,128]，128/自动 -> [128]
    auto buildChain = [this](const QVector<QPair<QString, QString>> &byQuality)
    {
        const QString prefer = m_quality >= 3 ? QStringLiteral("flac")
                              : m_quality == 2 ? QStringLiteral("320")
                                               : QStringLiteral("128");
        QVector<QPair<QString, QString>> chain;
        bool take = false;
        for (const QString &key : {QStringLiteral("flac"), QStringLiteral("320"), QStringLiteral("128")})
        {
            if (key == prefer)
                take = true;
            if (!take)
                continue;
            for (const auto &c : byQuality)
            {
                if (c.first == key)
                {
                    chain.append(c);
                    break;
                }
            }
        }
        return chain;
    };

    const auto cacheHit = m_privilegeCache.constFind(hash.toUpper());
    if (cacheHit != m_privilegeCache.constEnd())
    {
        QVector<QPair<QString, QString>> chain = buildChain(*cacheHit);
        // 解析结果一个可用档都没有（罕见）：退回歌单 hash 直取
        if (chain.isEmpty())
            chain.append({QStringLiteral("128"), hash});
        trySongUrlCandidates(hash, chain, 0, std::move(callback));
        return;
    }

    ApiClient::instance().getJson(
        QString("https://api.special520.com/privilege/lite?hash=%1").arg(hash),
        [this, hash, callback, buildChain](QJsonObject root)
        {
            // data[] 每项及其 relate_goods 携带各音质变体：quality/hash/level（0=不可用）
            QVector<QPair<QString, QString>> byQuality;
            const QJsonArray data = root["data"].toArray();
            for (const QJsonValue &itemVal : data)
            {
                const QJsonObject item = itemVal.toObject();
                QJsonArray variants;
                variants.append(item);
                for (const QJsonValue &rv : item["relate_goods"].toArray())
                    variants.append(rv);
                for (const QJsonValue &vv : variants)
                {
                    const QJsonObject v        = vv.toObject();
                    const QString quality      = v["quality"].toString();
                    const QString fileHash     = v["hash"].toString();
                    if (fileHash.isEmpty() || v["level"].toInt() == 0)
                        continue;
                    if (quality != QLatin1String("128") && quality != QLatin1String("320")
                        && quality != QLatin1String("flac"))
                        continue;
                    bool dup = false;
                    for (const auto &c : byQuality)
                    {
                        if (c.first == quality)
                        {
                            dup = true;
                            break;
                        }
                    }
                    if (!dup)
                        byQuality.append({quality, fileHash});
                }
            }
            m_privilegeCache.insert(hash.toUpper(), byQuality);
            QVector<QPair<QString, QString>> chain = buildChain(byQuality);
            if (chain.isEmpty())
                chain.append({QStringLiteral("128"), hash});
            trySongUrlCandidates(hash, chain, 0, callback);
        },
        [this, hash, callback](QString, int)
        {
            // privilege 拉取失败：退回歌单 hash 直取（旧行为）
            QVector<QPair<QString, QString>> fallback;
            fallback.append({QStringLiteral("128"), hash});
            trySongUrlCandidates(hash, fallback, 0, callback);
        },
        10000
    );
}

void PlaylistManager::trySongUrlCandidates(
    const QString &songHash, const QVector<QPair<QString, QString>> &candidates, int idx,
    std::function<void(QString)> callback
)
{
    m_pendingFileSize = 0;  // 每档尝试前清掉上一档可能残留的期望值
    m_pendingFileMd5.clear();
    if (idx < 0 || idx >= candidates.size() || idx >= 4)  // 最多 4 档，防异常数据长循环
    {
        handleSongUrlFailed(songHash, QStringLiteral("无可用播放地址"));
        callback(QString());
        return;
    }
    ApiClient::instance().get(
        QString("https://api.special520.com/song/url?hash=%1&quality=%2").arg(candidates[idx].second, candidates[idx].first),
        [this, songHash, candidates, idx, callback](QByteArray body)
        {
            const QJsonDocument doc = QJsonDocument::fromJson(body);
            QString songUrl;
            QString extName;
            if (doc.isObject())
            {
                const QJsonObject o = doc.object();
                const QJsonArray urlarray = o["url"].toArray();
                if (!urlarray.isEmpty())
                    songUrl = urlarray[0].toString();
                extName = o["extName"].toString();
                // 接口提供精确字节数与文件内容 MD5：响应 hash 即该音质实际下发文件的
                // MD5（实测 128/320/flac 皆如此，与请求 hash 无关），供下载完成时校验
                m_pendingFileSize = o["fileSize"].toVariant().toLongLong();
                m_pendingFileMd5  = o["hash"].toString();
            }
            // extName==mp4 是该档位对应的高清MV音轨而非音频，视作本档不可用，降下一档
            if (!songUrl.isEmpty() && extName.compare(QLatin1String("mp4"), Qt::CaseInsensitive) != 0)
            {
                m_urlFailStreak = 0;  // 成功取到 URL，清连续失败计数
                callback(songUrl);
                return;
            }
            trySongUrlCandidates(songHash, candidates, idx + 1, callback);
        },
        [this, songHash, candidates, idx, callback](QString, int)
        {
            trySongUrlCandidates(songHash, candidates, idx + 1, callback);
        },
        10000
    );
}

void PlaylistManager::handleSongUrlFailed(const QString &hash, const QString &reason)
{
    qWarning() << "[PlaylistManager] 获取播放地址失败 hash=" << hash << "reason=" << reason;
    // 停 loading 态（否则进度条一直转、界面卡住无反应）
    if (m_isBuffering)
    {
        m_isBuffering = false;
        emit isBufferingChanged();
    }
    // 过时请求（切歌后旧请求迟到失败）不打扰当前播放
    if (m_currentIndex < 0 || m_currentIndex >= m_curplaylist->size())
        return;
    if ((*m_curplaylist)[m_currentIndex].songhash.compare(hash, Qt::CaseInsensitive) != 0)
        return;

    // 一起听：队列由服务器控制，客户端不自动切歌——只暂停 + 提示
    if (type != LOCAL)
    {
        m_isPaused = true;
        emit isPausedChanged();
        emit songUrlFailed(QStringLiteral("获取播放地址失败（一起听由房间控制，已暂停）"));
        return;
    }

    // 本地模式：提示 + 自动播放下一首。连续失败达到队列长度（封顶 10）说明整队都拿不到 URL，停下
    ++m_urlFailStreak;
    const int failLimit = qMin((*m_curplaylist).size(), 10);
    if (m_urlFailStreak >= failLimit)
    {
        m_urlFailStreak = 0;
        m_isPaused      = true;
        emit isPausedChanged();
        emit songUrlFailed(QStringLiteral("连续获取播放地址失败，已停止播放"));
        return;
    }
    emit songUrlFailed(QStringLiteral("获取播放地址失败，3 秒后自动播放下一首"));
    // 错误回调里同步切歌可能被播放器状态机吞掉：延迟到事件循环再切（同 handlePlayerError）。
    QTimer::singleShot(3000, this, [this, hash]()
    {
        // 3 秒内用户手动切了歌/换了队列：这次自动跳歌作废
        if (m_currentIndex < 0 || m_currentIndex >= m_curplaylist->size())
            return;
        if ((*m_curplaylist)[m_currentIndex].songhash.compare(hash, Qt::CaseInsensitive) != 0)
            return;
        const int size = (*m_curplaylist).size();
        if (size <= 0)
            return;
        int next;
        if (m_playMode == MODE_RANDOM && size > 1)
        {
            // 随机模式保持随机（避免重复当前首）
            do
            {
                next = QRandomGenerator::global()->bounded(size);
            } while (next == m_currentIndex);
        }
        else
        {
            // 顺序推进（末尾回开头，streak 上限兜底）；单曲循环也强制推进——否则失败的歌会死循环
            next = (m_currentIndex + 1) % size;
        }
        playSongbyindex(next);
    });
}

void PlaylistManager::fetchLyricData(const QString &hash, std::function<void(QString)> callback)
{
    // 去重：同 hash 正在请求中，挂起 callback，等首个请求完成后统一回调
    // （切歌时多个调用点/组件触发同一首歌歌词，避免重复打 /search/lyric + /lyric）
    if (m_lyricPendingHashes.contains(hash))
    {
        m_lyricPendingCallbacks[hash].append(callback);
        return;
    }
    m_lyricPendingHashes.insert(hash);
    m_lyricPendingCallbacks[hash].append(callback);

    // 首个请求完成时，统一回调所有挂起的 callback
    auto finish = [this, hash](const QString &lyric) {
        const auto cbs = m_lyricPendingCallbacks.take(hash);
        m_lyricPendingHashes.remove(hash);
        for (const auto &cb : cbs)
            if (cb) cb(lyric);
    };

    // 第一步：根据 hash 获取歌词信息
    ApiClient::instance().getJson(
        QString("https://api.special520.com/search/lyric?hash=%1").arg(hash),
        [this, hash, finish](QJsonObject root)
        {
            const QJsonArray candidates = root["candidates"].toArray();
            if (candidates.isEmpty() || !candidates[0].isObject())
            {
                finish(QString());
                return;
            }
            const QJsonObject lyricInfo = candidates[0].toObject();
            const QString id            = lyricInfo["id"].toString();
            const QString accesskey     = lyricInfo["accesskey"].toString();
            if (!id.isEmpty() && !accesskey.isEmpty())
            {
                // 第二步：使用 id 和 accesskey 获取具体歌词内容
                fetchLyricContent(id, accesskey, finish);
                return;
            }
            qWarning() << "未找到有效的id或accesskey";
            finish(QString());
        },
        [finish](QString err, int)
        {
            Q_UNUSED(err);
            finish(QString());
        },
        10000
    );
}

void PlaylistManager::fetchLyricContent(
    const QString &id, const QString &accesskey, std::function<void(QString)> callback
)
{
    const QString urlStr = QString("https://api.special520.com/lyric?id=%1&accesskey=%2&fmt=krc&decode=true")
                               .arg(id)
                               .arg(accesskey);

    ApiClient::instance().getJson(
        urlStr,
        [callback](QJsonObject root)
        {
            const QString decodeContent = root["decodeContent"].toString();
            callback(decodeContent);
        },
        [callback](QString err, int)
        {
            Q_UNUSED(err);
            callback(QString());
        },
        10000
    );
}

void PlaylistManager::setFmPeakMode(bool enabled)
{
    if (m_fmPeakMode == enabled)
        return;
    m_fmPeakMode = enabled;
    m_fmPeakAdvanceOnFinish = false;

    if (enabled)
    {
        // 正在播放整首时，立刻切到当前歌曲的 30 秒试听片段
        if (type == LOCAL && !m_isPaused && m_currentIndex >= 0
                && m_currentIndex < (*m_curplaylist).size() && !m_climaxPreviewing)
            startFmPeakPreview((*m_curplaylist)[m_currentIndex]);
    }
    else if (m_climaxPreviewing)
    {
        // 退出 30 秒模式：停片段并恢复当前歌曲完整播放
        finishClimaxPreview(false, 80);
        const int idx = m_currentIndex;
        QTimer::singleShot(120, this, [this, idx]() {
            if (m_fmPeakMode)
                return;
            if (idx >= 0 && idx < (*m_curplaylist).size())
                playSongbyindex(idx);
        });
    }
}

void PlaylistManager::updatePlaybackProgress(qint64 position)
{
    // 歌曲播完后 position 会重置到 0，跳过以避免歌词闪回第一句
    if (m_player->mediaStatus() == QMediaPlayer::EndOfMedia)
        return;
    // 高潮试听期间主歌进度/歌词都不更新，避免覆盖试听中的 UI
    if (m_climaxPreviewing)
        return;
    emit playbackPositionChanged(position);


    if (m_player->duration() > 0)
    {
        m_percent    = static_cast<float>(position) / m_player->duration();
        m_percentstr = formatTime(position);
        // 约 24Hz 刷新进度条/时间：失焦或遮挡时也保持流畅（不再降到 1Hz）
        const qint64 percentNow     = QDateTime::currentMSecsSinceEpoch();
        const qint64 notifyInterval = 1000 / 24;
        if (percentNow - m_lastPercentNotifyMs >= notifyInterval)
        {
            m_lastPercentNotifyMs = percentNow;
            emit percentChanged();
        }

        // 末尾 1.5s 渐弱（自然结束前的淡出）；seek 离开末尾则恢复音量
        const qint64 totalDur = m_player->duration();
        if (totalDur > 0)
        {
            if (position >= totalDur - 1000 && !m_endFadeStarted)
            {
                m_endFadeStarted = true;
                fadeOutVolume(1000, nullptr);
            }
            else if (position < totalDur - 1500 && m_endFadeStarted)
            {
                fadeInVolume(); // 回到非末尾：渐强恢复（同时重置 m_endFadeStarted）
            }
        }

        // 缓冲检测：正在边下边播且播放追上下载进度
        if (m_downloadProgress > 0 && m_downloadProgress < 1.0)
        {
            if (!m_isBuffering && m_percent >= m_downloadProgress - 0.03f)
            {
                m_isBuffering = true;
                m_player->pause();
                emit isBufferingChanged();
                qDebug() << "缓冲中: 播放进度" << m_percent << "下载进度" << m_downloadProgress;
            }
        }
        // 缓冲恢复：下载进度领先播放进度足够多（高潮试听期间不恢复主播放）
        if (!m_climaxPreviewing && m_isBuffering && m_downloadProgress - m_percent > 0.1)
        {
            m_isBuffering = false;
            m_player->play();
            emit isBufferingChanged();
            qDebug() << "缓冲完成，恢复播放";
        }
        // 更新歌词（逐字进度高频刷新见 updateLyricProgress 的 16ms 定时器）
        updateLyricProgress(position);
    }
}

void PlaylistManager::setVolume(qreal v)
{
    v = qBound(0.0, v, 1.0);
    if (m_volAnim)
        m_volAnim->stop();
    m_audioOutput->setVolume(v);
    m_targetVolume = v;
    m_settings.setValue(QStringLiteral("volume"), v);
    emit volumeChanged();
}

void PlaylistManager::fadeInVolume()
{
    m_endFadeStarted = false;
    if (!m_volAnim)
        m_volAnim = new QPropertyAnimation(m_audioOutput, "volume", this);
    m_volAnim->stop();
    m_volAnim->disconnect(this); // 清理上次的 finished 回调（如暂停淡出未完成即恢复）
    m_audioOutput->setVolume(0.0);
    m_volAnim->setStartValue(0.0);
    m_volAnim->setEndValue(m_targetVolume);
    m_volAnim->setDuration(1500);
    m_volAnim->setEasingCurve(QEasingCurve::InOutQuad);
    m_volAnim->start();
}

void PlaylistManager::fadeOutVolume(int ms, std::function<void()> onFinished)
{
    if (!m_volAnim)
        m_volAnim = new QPropertyAnimation(m_audioOutput, "volume", this);
    m_volAnim->stop();
    m_volAnim->disconnect(this); // 清理上次的 finished 回调
    if (onFinished)
        connect(m_volAnim, &QPropertyAnimation::finished, this, [this, onFinished]() { onFinished(); });
    m_volAnim->setStartValue(m_audioOutput->volume());
    m_volAnim->setEndValue(0.0);
    m_volAnim->setDuration(ms);
    m_volAnim->setEasingCurve(QEasingCurve::InOutQuad);
    m_volAnim->start();
}

// 逐字进度刷新。跳跃歌词动画（星星上抛/字压扁）按 charProgress 计算，
// 16ms 定时器高频调用保证 60Hz；每次进度变化都 emit currlyricChanged——
void PlaylistManager::updateLyricProgress(qint64 position)
{
    // 歌词偏移按歌生效：切歌/换一起听歌曲时自动归零（同一首歌 seek、修复重播不受影响）
    const QString songHash = m_climaxPreviewing
                                 ? m_climaxPreviewHash
                                 : ((type == TOGETHER) ? m_currentTogetherSongHash : currentSongHash());
    if (songHash != m_lyricOffsetSongHash)
    {
        m_lyricOffsetSongHash = songHash;
        if (m_lyricOffsetMs != 0)
        {
            m_lyricOffsetMs = 0;
            emit lyricOffsetChanged();
        }
    }
    // position 值外推：flac 音频帧 4096 采样（≈92ms）导致 position 值 92ms 才前进一次，
    // 阶梯间隙按真实时间外推——跳跃歌词动画（星星/字压扁）因此 60Hz 平滑。
    const qint64 tickNow = QDateTime::currentMSecsSinceEpoch();
    if (position == m_lastRawPosMs)
    {
        // 值未刷新（阶梯间隙）：仅播放中按真实时间推进（试听时用试听播放器状态）
        const bool playing = m_climaxPreviewing
                                 ? (m_climaxPlayer->playbackState() == QMediaPlayer::PlayingState)
                                 : (m_player->playbackState() == QMediaPlayer::PlayingState);
        if (playing)
            position = m_lastRawPosMs + (tickNow - m_lastRawTickMs);
        else
            m_lastRawTickMs = tickNow;
    }
    else
    {
        m_lastRawPosMs  = position;
        m_lastRawTickMs = tickNow;
    }
    // 歌词偏移：正值=歌词提前显示（在真实进度上提前 offset 查歌词行/逐字进度）
    position += m_lyricOffsetMs;
    QString newlyric      = m_lyricParser.getLyricAtTime(position);
    int newCharIndex      = m_lyricParser.getCharIndexAtTime(position);
    float newCharProgress = m_lyricParser.getCharProgressAtTime(position);

    // 始终更新进度（用于平滑动画）
    bool progressChanged = qAbs(newCharProgress - m_lyricCharProgress) > 0.001f;
    m_lyricCharProgress  = newCharProgress;

    const bool lineChanged = (newlyric != currlyric);
    if (lineChanged || newCharIndex != m_lyricCharIndex)
    {
        // 字符列表仅切行时重建（切字时列表内容不变）：省掉高频 QVariantList 分配，
        // 值相等时 QML 绑定不触发 Repeater 重建
        if (lineChanged)
        {
            m_lyricChars     = m_lyricParser.getCurrentChars(position);
            m_lyricCharCount = m_lyricChars.size();
        }
        currlyric        = newlyric;
        m_lyricCharIndex = newCharIndex;
        emit currlyricChanged();
    }
    else if (progressChanged)
    {
        // 进度变化 16ms 定时器高频通知（60Hz 动画）
        emit currlyricChanged();
    }
}

int PlaylistManager::lyricOffsetMs() const
{
    return int(m_lyricOffsetMs);
}

void PlaylistManager::adjustLyricOffset(int deltaMs)
{
    // ±10s 上限，防止连点调飞
    m_lyricOffsetMs = qBound(-10000LL, m_lyricOffsetMs + qint64(deltaMs), 10000LL);
    emit lyricOffsetChanged();
    // 立即按新偏移刷新当前行（暂停时 16ms 定时器不跑，直接刷一次）
    updateLyricProgress(m_player->position());
}

void PlaylistManager::resetLyricOffset()
{
    if (m_lyricOffsetMs == 0)
        return;
    m_lyricOffsetMs = 0;
    emit lyricOffsetChanged();
    updateLyricProgress(m_player->position());
}

void PlaylistManager::handlePlayerError(QMediaPlayer::Error error, const QString &errorString)
{
    if (m_isRepairing)
    {
        qWarning() << "正在修复中，忽略重复错误";
        return;
    }

    qWarning() << "播放出错:" << errorString << "错误代码:" << error;

    // 资源/网络错误：URL 失效或无法访问（一起听服务器链接过期、直链 403/404、旧 url 失效等）。
    if (error == QMediaPlayer::ResourceError || error == QMediaPlayer::NetworkError)
    {
        if (m_isBuffering)
        {
            m_isBuffering = false;
            emit isBufferingChanged();
        }
        m_isPaused = true;
        emit isPausedChanged();
        emit songUrlFailed(QStringLiteral("播放失败，歌曲链接已失效或无法访问"));
        return;
    }

    // Qt ffmpeg 后端解码酷狗 flac 尾部不兼容（最小复现：播到 ~99.1% 报 FormatError，文件本身完好，
    // md5 与服务器一致）。接近末尾的错误按自然播完处理：不删缓存、直接下一首
    if (error == QMediaPlayer::FormatError)
    {
        const qint64 dur = m_player->duration();
        if (dur > 0 && m_player->position() >= dur * 95 / 100)
        {
            qWarning() << "播放接近末尾报错（ffmpeg 尾部解码不兼容），按自然播完处理";
            emit playbackFinished();
            m_isPaused = true;
            emit isPausedChanged();
            // 错误回调中同步切歌可能被播放器状态机吞掉：延迟到事件循环再播下一首
            QTimer::singleShot(0, this, [this]() { playNext(); });
            return;
        }
    }

    // FormatError 且正在播放本地缓存文件（非边下边播）-> 删除损坏的缓存并重新下载
    // LOCAL 与 TOGETHER 统一处理：损坏的缓存不删除会永久卡死（每次播放都在同一处报错）
    if (error == QMediaPlayer::FormatError)
    {
        QUrl src = m_player->source();
        if (src.isLocalFile())
        {
            QString localPath = src.toLocalFile();
            QFileInfo fi(localPath);
            // 只处理文件不再增长的情况（非边下边播：下载中文件会持续增长，等它下完）
            qint64 size1 = fi.size();
            QTimer::singleShot(
                200, this,
                [this, localPath, size1]()
                {
                    QFileInfo fi2(localPath);
                    if (fi2.size() != size1 || size1 < 10240)
                    {
                        return;
                    }
                    qDebug() << "缓存文件损坏，删除并重新下载:" << localPath;
                    m_player->stop();
                    m_player->setSource(QUrl());
                    QFile::remove(localPath);

                    if (type == TOGETHER)
                    {
                        m_currentTogetherSongHash.clear(); // 允许重新播放同一首歌
                        if (m_currentIndex >= 0 && m_currentIndex < m_togetherplaylist.size())
                        {
                            const SongInfo &song = m_togetherplaylist[m_currentIndex];
                            if (!song.url.isEmpty())
                            {
                                playTogetherSongFromServer(
                                    song.url, song.title, song.songhash, song.singername, song.union_cover,
                                    song.album_name, song.duration
                                );
                            }
                        }
                    }
                    else
                    {
                        // LOCAL：重播当前歌，走标准管线（缓存已删 -> 重新边下边播）
                        if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
                            playSongbyindex(m_currentIndex);
                    }
                }
            );
            return;
        }
    }

    // 检查是否是FFmpeg解复用错误
    if ((errorString.contains("Demuxing failed") || errorString.contains("AV_NOPTS_VALUE")) &&
        m_repairCount < MAX_REPAIR_ATTEMPTS)
    {
        m_isRepairing = true;
        m_repairCount++;

        qDebug() << "尝试第" << m_repairCount << "次重新播放...";

        qint64 lastPos = m_player->position();
        // 修复：m_currentIndex 可能为 -1（无歌曲加载时任意时刻都可能报错），
        // 导致 m_playlist[-1] 越界崩溃
        if (m_currentIndex < 0 || m_currentIndex >= m_playlist.size())
        {
            m_isRepairing = false;
            m_repairCount = MAX_REPAIR_ATTEMPTS;
            return;
        }
        QString currentUrl = m_playlist[m_currentIndex].url;

        // 先停止并清空当前播放
        m_player->stop();
        m_player->setSource(QUrl());
        m_isPaused = true;
        emit isPausedChanged();
        // 延迟后重试
        QTimer::singleShot(
            50, this,
            [=]()
            {
                m_player->setSource(QUrl(currentUrl));
                m_player->play();

                connect(
                    m_player, &QMediaPlayer::mediaStatusChanged, this,
                    [=](QMediaPlayer::MediaStatus status)
                    {
                        if (status == QMediaPlayer::LoadedMedia)
                        {
                            m_player->setPosition(lastPos);
                        }
                    },
                    Qt::SingleShotConnection
                );
                m_isPaused = false;
                emit isPausedChanged();
                m_isRepairing = false;
            }
        );
    }
    else
    {
        // 修复失败：自动跳到下一首并播放（连续播放体验，坏歌自动跳过）
        qWarning() << "修复失败，跳过当前歌曲，自动播放下一首";
        m_repairCount = 0;
        playNext();
    }
}
// 将毫秒转换为 "分:秒" 格式
QString PlaylistManager::formatTime(qint64 milliseconds)
{
    {
        if (milliseconds <= 0)
            return "00:00";
        QTime time(0, 0);
        time = time.addMSecs(milliseconds);
        return time.toString("mm:ss");
    }
}

// 获取主色调
QString PlaylistManager::dominantColor() const
{
    return m_dominantColor;
}

void PlaylistManager::syncTogetherPlaylistFromServer(const QJsonArray &songs)
{
    // 在清空列表前记住当前播放歌曲的 hash
    QString playingHash;
    if (m_currentIndex >= 0 && m_currentIndex < m_togetherplaylist.size())
        playingHash = m_togetherplaylist[m_currentIndex].songhash;

    m_togetherplaylist.clear();
    for (const QJsonValue &val : songs)
    {
        if (!val.isObject())
            continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title             = obj["songname"].toString();
        song.songhash          = obj["songhash"].toString();
        song.singername        = obj["singername"].toString();
        song.album_name        = obj["album_name"].toString();
        song.duration          = obj["duration"].toString();
        song.union_cover       = obj["cover_url"].toString();
        song.mxid              = obj["mxid"].toString();
        song.added_by_nickname = obj["added_by_nickname"].toString();
        song.added_by_avatar   = obj["added_by_avatar"].toString();
        song.like_count        = obj["like_count"].toInt();
        song.recommend_source  = obj["recommend_source"].toString();
        const QJsonArray likedArr = obj["liked_by"].toArray();
        for (const QJsonValue &likeVal : likedArr)
            song.liked_by.append(likeVal.toString());
        m_togetherplaylist.append(song);
    }

    // 根据当前播放歌曲 hash 重新定位 currentIndex
    if (!playingHash.isEmpty())
    {
        for (int i = 0; i < m_togetherplaylist.size(); i++)
        {
            if (m_togetherplaylist[i].songhash == playingHash)
            {
                if (m_currentIndex != i)
                {
                    m_currentIndex = i;
                    emit currentIndexChanged(i);
                }
                break;
            }
        }
    }

    m_togetherplaylistModel->syncFromList(m_togetherplaylist);
    emit togetherplaylistUpdated();
}
void PlaylistManager::playTogetherSongFromServer(
    const QString &songUrl, const QString &songName, const QString &songHash, const QString &singerName,
    const QString &coverUrl, const QString &albumName, const QString &duration, const QString &mxid
)
{
    // 防重入：同一首歌的周期同步不打断高潮试听
    if (m_currentTogetherSongHash == songHash)
    {
        qDebug() << "一起听 - 跳过重复播放请求:" << songName
                 << (m_climaxPreviewing ? "(试听中)" : "");
        return;
    }
    cancelClimaxPreview();  // 房间切到新歌：结束试听，交给新歌
    m_mainLyricRaw.clear();
    m_currentTogetherSongHash = songHash;

    // 记录到最近播放
    {
        SongInfo recentSong;
        recentSong.title       = songName;
        recentSong.songhash    = songHash;
        recentSong.singername  = singerName;
        recentSong.union_cover = coverUrl;
        recentSong.album_name  = albumName;
        recentSong.duration    = duration;
        addToRecent(recentSong);
    }

    // 查找或创建歌曲条目
    int playIndex = -1;
    for (int i = 0; i < m_togetherplaylist.size(); i++)
    {
        if (m_togetherplaylist[i].songhash == songHash)
        {
            m_togetherplaylist[i].url = songUrl;
            if (!mxid.isEmpty())
                m_togetherplaylist[i].mxid = mxid; // 服务器下发的评论用 id，更新不覆盖为空
            playIndex                 = i;
            break;
        }
    }
    if (playIndex < 0)
    {
        SongInfo song;
        song.title       = songName;
        song.songhash    = songHash;
        song.url         = songUrl;
        song.singername  = singerName;
        song.mxid        = mxid;
        song.union_cover = coverUrl;
        song.album_name  = albumName;
        song.duration    = duration;
        m_togetherplaylist.append(song);
        playIndex = m_togetherplaylist.size() - 1;
        m_togetherplaylistModel->syncFromList(m_togetherplaylist);
        emit togetherplaylistUpdated();
    }
    m_currentIndex = playIndex;
    emit currentIndexChanged(playIndex);

    m_player->stop();
    m_player->setSource(QUrl());

    // 重置下载状态
    m_downloadProgress   = 1.0;
    m_isBuffering        = false;
    m_downloadedBytes    = 0;
    m_totalDownloadBytes = 0;
    emit downloadProgressChanged();
    emit isBufferingChanged();

    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = PlaylistCacheStore::songCachePath(songName, singerName, 1);  // 一起听无音质概念，走标准 128
    bool useCache         = false;
    if (QFile::exists(cacheFilePath))
    {
        QFileInfo cacheInfo(cacheFilePath);
        if (cacheInfo.size() > 10240) // 至少 10KB 才认为是有效缓存
            useCache = true;
        else
        {
            qDebug() << "一起听 - 缓存文件过小，删除并重新下载:" << cacheFilePath << "大小:" << cacheInfo.size();
            QFile::remove(cacheFilePath);
        }
    }

    if (useCache)
    {
        qDebug() << "一起听 - 使用本地缓存:" << cacheFilePath;
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));

        if (m_togetherSeekPercent > 0)
        {
            double seekPercent    = m_togetherSeekPercent;
            m_togetherSeekPercent = 0;
            auto conn             = std::make_shared<QMetaObject::Connection>();
            *conn                 = connect(
                m_player, &QMediaPlayer::mediaStatusChanged, this,
                [this, seekPercent, conn](QMediaPlayer::MediaStatus status)
                {
                    if (status == QMediaPlayer::LoadedMedia)
                    {
                        seekToPercent(seekPercent);
                        m_player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                        QObject::disconnect(*conn);
                    }
                }
            );
        }
        else
        {
            m_player->play();
            m_isPaused = false;
            emit isPausedChanged();
        }
    }
    else if (!songUrl.isEmpty())
    {
        // 无缓存 - 边下边播（下载逻辑与本地播放共用 downloadAndStream）
        double seekPercent    = m_togetherSeekPercent;
        m_togetherSeekPercent = 0;
        // 一起听路径不需要再提取封面色（已在调用方处理）也不需要 currentSongChanged
        downloadAndStream(songUrl, songHash, cacheFilePath, QString(), seekPercent, nullptr);
    }
    else
    {
        // URL 为空，通过 hash 获取播放链接
        m_isPaused            = true;
        double seekPercent    = m_togetherSeekPercent;
        m_togetherSeekPercent = 0;
        fetchSongUrl(
            songHash,
            [this, songHash, seekPercent](const QString &url)
            {
                if (!url.isEmpty())
                {
                    m_player->setSource(QUrl(url));
                    if (seekPercent > 0)
                    {
                        auto conn = std::make_shared<QMetaObject::Connection>();
                        *conn     = connect(
                            m_player, &QMediaPlayer::mediaStatusChanged, this,
                            [this, seekPercent, conn](QMediaPlayer::MediaStatus status)
                            {
                                if (status == QMediaPlayer::LoadedMedia)
                                {
                                    seekToPercent(seekPercent);
                                    m_player->play();
                                    m_isPaused = false;
                                    emit isPausedChanged();
                                    QObject::disconnect(*conn);
                                }
                            }
                        );
                    }
                    else
                    {
                        m_player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                    }
                }
                else
                {
                    qWarning() << "一起听模式 - 无法获取歌曲URL，hash:" << songHash;
                }
            }
        );
    }

    m_colorExtractor->extract(coverUrl);
    emit currentSongChanged();
    emit isPausedChanged();

    fetchLyricData(
        songHash,
        [this](const QString &lyric)
        {
            if (!lyric.isEmpty())
            {
                m_mainLyricRaw = lyric;
                m_lyricParser.parseKRCLyrics(lyric);
                qDebug() << "一起听模式 - 歌词获取成功，长度:" << lyric.length();
            }
            else
            {
                qWarning() << "一起听模式 - 获取歌词失败";
            }
        }
    );
}

void PlaylistManager::seekToPercent(double percent)
{
    // 一起听进度同步不干预本地试听
    if (m_climaxPreviewing)
        return;
    if (m_player->duration() > 0)
    {
        qint64 targetPos = static_cast<qint64>(percent * m_player->duration());
        m_player->setPosition(targetPos);
    }
}

void PlaylistManager::setTogetherSeekPercent(double percent)
{
    m_togetherSeekPercent = percent;
}

double PlaylistManager::togetherSeekPercent() const
{
    return m_togetherSeekPercent;
}

// 一起听：本地环境性暂停（播放键/媒体键/拔出耳机）→ 仅本地暂停，不告知服务器
void PlaylistManager::pauseLocal()
{
    m_localPaused = true;
    setPaused(true);
}

bool PlaylistManager::localPaused() const
{
    return m_localPaused;
}

void PlaylistManager::clearLocalPaused()
{
    m_localPaused = false;
}

void PlaylistManager::setPaused(bool paused)
{
    // 一起听房间的周期播放状态同步不打断本地高潮试听；试听结束后再按保存状态恢复
    if (m_climaxPreviewing)
        return;
    cancelClimaxPreview();
    if (paused && m_player->playbackState() == QMediaPlayer::PlayingState)
    {
        // 一起听：暂停前 1.5s 渐弱，再真正暂停（图标立即切换为暂停）
        m_isPaused = true;
        emit isPausedChanged();
        fadeOutVolume(
            1000,
            [this]()
            {
                if (m_player->playbackState() == QMediaPlayer::PlayingState)
                    m_player->pause();
            }
        );
    }
    else if (!paused && m_player->playbackState() != QMediaPlayer::PlayingState)
    {
        m_player->play();
        m_isPaused = false;
        emit isPausedChanged();
        fadeInVolume(); // 一起听：恢复时渐强
    }
}
