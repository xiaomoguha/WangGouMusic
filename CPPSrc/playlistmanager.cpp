#include "playlistmanager.h"
#include "ApiClient.h"
#include "DominantColorExtractor.h"
#include "PlaylistCacheStore.h"
#include <QAudioDevice>
#include <QDebug>
#include <QEventLoop>
#include <QMediaDevices>
#include <QPropertyAnimation>
#include <QTimer>
#include <memory>
PlaylistManager::PlaylistManager(Recommendation *recommendation, QObject *parent)
    : QObject(parent), m_recommendation(recommendation)
{
    // QML 列表视图 model（与 m_playlist/m_togetherplaylist/m_recentPlaylist 同步）
    m_playlistModel         = new SongListModel(this);
    m_togetherplaylistModel = new SongListModel(this);
    m_recentPlaylistModel   = new SongListModel(this);

    // 主色调提取模块：extract 异步返回结果，转发到 QML 绑定的 dominantColor 属性
    m_colorExtractor = new DominantColorExtractor(this);
    connect(
        m_colorExtractor, &DominantColorExtractor::dominantColorReady, this,
        [this](const QString &color)
        {
            m_dominantColor = color;
            emit dominantColorChanged();
        }
    );

    m_player->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(1.0);

    // 跟随系统默认音频输出设备：运行中新接入蓝牙耳机或切换默认播放设备时，自动把音频路由到新设备。
    // 否则 QAudioOutput 会一直绑定启动时捕获的旧设备，必须重启应用才切换。
    // audioOutputsChanged 在「输出设备增删」时触发——新连蓝牙会被识别为新增设备从而触发；
    // 默认设备未变（相同设备）时由下方判等跳过，避免无谓的 sink 重建造成杂音。
    auto *mediaDevices = new QMediaDevices(this);
    connect(
        mediaDevices, &QMediaDevices::audioOutputsChanged, this,
        [this]()
        {
            const QAudioDevice def = QMediaDevices::defaultAudioOutput();
            if (def.isNull() || m_audioOutput->device() == def)
                return;
            m_audioOutput->setDevice(def);
        }
    );

    // 音量淡入/淡出：新歌(Stopped->Playing)渐强；暂停/自然结束前渐弱（见 playstop / updatePlaybackProgress）
    m_prevPlaybackState = m_player->playbackState();
    connect(
        m_player, &QMediaPlayer::playbackStateChanged, this,
        [this](QMediaPlayer::PlaybackState state)
        {
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
    connect(m_player, &QMediaPlayer::errorOccurred, this, &PlaylistManager::handlePlayerError);
    connect(&m_lyricParser, &LyricParser::parselyricsuc, this, &PlaylistManager::parlyricsuc);
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
    // 与 loadPlaylistFromCache 末尾一致：加载后立即同步 model 并发信号，QML 绑定刷新。
    m_recentPlaylistModel->syncFromList(m_recentPlaylist);
    emit recentPlaylistUpdated();
}

// 判断是否有缓存文件
int PlaylistManager::is_have_cache(const SongInfo &song, const int index)
{
    PlaylistCacheStore::ensureCacheDir();
    QString cacheDir = getCacheDir();
    // 先判断本地是否有歌曲缓存
    QString cacheFileName = song.title + "-" + song.singername + ".mp3";
    QString cacheFilePath = cacheDir + "/" + cacheFileName;

    QFile cacheFile(cacheFilePath);

    if (cacheFile.exists())
    {
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;

        // 播放本地缓存文件
        m_player->stop();
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
        m_player->play();
        m_isPaused     = false;
        m_currentIndex = index;
        // 提取专辑封面主色调
        m_colorExtractor->extract(song.union_cover);
        // 重置进度：缓存命中的新歌也从 0 开始（与 startPlayback 一致）。
        // 上一首自然播完时 m_percent 冻在 ~1.0（updatePlaybackProgress 在 EndOfMedia 跳过更新），
        // 不重置的话媒体控制栏（currentSongChanged 触发 getpercent）会把本曲显示在末尾。
        m_percent    = 0.0f;
        m_percentstr = "00:00";
        emit percentChanged();
        emit currentIndexChanged(index);
        emit currentSongChanged();
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
        addToRecent(song);
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
    QString cacheFilePath = getCacheDir() + "/" + song.title + "-" + song.singername + ".mp3";

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
                fetchSongUrl(
                    (*m_curplaylist)[index].songhash,
                    [this, index](const QString &url)
                    {
                        if (!url.isEmpty())
                        {
                            (*m_curplaylist)[index].url = url;
                            m_currentIndex              = index;
                            emit currentIndexChanged(index);
                            startPlayback((*m_curplaylist)[index]);
                        }
                        else
                        {
                            qWarning() << "获取播放 URL 失败";
                        }
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
    if (type != LOCAL)
        return; // 一起听模式不处理
    m_lazySourceId = sourceId;
    m_lazyTotal    = totalCount;
    m_lazyPage     = 1; // 首批已由 QML 提供，视为第 1 页已加载
    m_lazyFetching = false;

    // 清空队列，用首批数据立即建队（无网络延迟）
    m_playlist.clear();
    QList<SongInfo> songs = convertToSongInfoList(firstBatch);
    for (const SongInfo &s : songs)
        m_playlist.append(s);

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
    // 立即自动拉取剩余所有页（fetchNextSourcePage 内部会级联到全量），
    // 让队列真实就是完整播放列表，数量即时对上
    if (m_lazyPage * m_lazyPageSize < m_lazyTotal)
        fetchNextSourcePage();
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
                    m_playlist.append(s);
                m_lazyPage += 1;
                savePlaylistToCache();
                m_playlistModel->syncFromList(m_playlist);
                emit playlistUpdated();
                // 全量填充：剩余页自动续拉直到源全部加载完，
                // 播放列表不再按需动态拓展，底部弹窗即完整列表。
                // 空页（含失败兜底的空结果）停下，避免断网时无限重试
                if (m_lazyPage * m_lazyPageSize < m_lazyTotal && !items.isEmpty())
                    fetchNextSourcePage();
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
                    fetchSongUrl(
                        songhash,
                        [this, index](const QString &url)
                        {
                            if (!url.isEmpty())
                            {
                                (*m_curplaylist)[index].url = url;
                                m_currentIndex              = index;
                                emit currentIndexChanged(index);
                                startPlayback((*m_curplaylist)[index]);
                            }
                            else
                            {
                                qWarning() << "获取播放 URL 失败";
                            }
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
// 循环播放下一首
void PlaylistManager::playNext()
{
    if (m_currentIndex + 1 < (*m_curplaylist).size())
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
    QMediaPlayer::PlaybackState state = m_player->playbackState();

    if (state == QMediaPlayer::PlayingState)
    {
        // 一起听：本地暂停只影响自己，不告知服务器（房间其他人继续播）
        m_localPaused = true;
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
            qDebug() << "没设置URL，无法播放!";
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
    showplaylist();
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
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].title;
    }
    return "";
}

QString PlaylistManager::currentsingername() const
{
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

bool PlaylistManager::isPaused() const
{
    return m_isPaused;
}

QString PlaylistManager::union_cover() const
{
    if (m_currentIndex >= 0 && m_currentIndex < (*m_curplaylist).size())
    {
        return (*m_curplaylist)[m_currentIndex].union_cover;
    }
    return "";
}

QString PlaylistManager::getpercentstr() const
{
    return m_percentstr;
}

QString PlaylistManager::durationstr()
{
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
    return m_percent;
}

// 边下边播共享逻辑（startPlayback 与 playTogetherSongFromServer 共用）
void PlaylistManager::downloadAndStream(
    const QString &songUrl, const QString &cacheFilePath, const QString &coverUrlForColor, double seekPercent,
    std::function<void()> onStreamStart
)
{
    const qint64 startThreshold = 500 * 1024; // 500KB 后开始播放

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
            QFileInfo fi(cacheFilePath);
            if (fi.size() >= startThreshold && m_player->source().isEmpty())
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

    QObject::connect(
        reply, &QNetworkReply::finished, this,
        [=]()
        {
            tempFile->flush();
            tempFile->close();
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

void PlaylistManager::startPlayback(const SongInfo &song)
{
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

    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = getCacheDir() + "/" + song.title + "-" + song.singername + ".mp3";

    // 本地缓存命中：直接播放
    if (QFile::exists(cacheFilePath))
    {
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;
        m_player->stop();
        m_player->setSource(QUrl::fromLocalFile(cacheFilePath));
        m_player->play();
        m_isPaused = false;
        m_colorExtractor->extract(song.union_cover);
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
        return;
    }

    // 无缓存：边下边播（下载逻辑与一起听路径共用 downloadAndStream）
    // onStreamStart 无需再 emit currentSongChanged（已在入口 emit）
    downloadAndStream(song.url, cacheFilePath, song.union_cover, 0.0, nullptr);
}

// 保存播放列表到本地缓存
void PlaylistManager::savePlaylistToCache()
{
    // TOGETHER 模式下保存切换前的本地索引和进度，而非一起听的
    const int idx   = (type == TOGETHER) ? m_localIndex : m_currentIndex;
    const float pct = (type == TOGETHER) ? m_localPercent : m_percent;
    PlaylistCacheStore::savePlaylist(m_playlist, idx, pct);
}

// 从本地缓存加载播放列表
void PlaylistManager::loadPlaylistFromCache()
{
    int savedIndex     = -1;
    float savedPercent = 0.0f;
    if (!PlaylistCacheStore::loadPlaylist(m_playlist, savedIndex, savedPercent))
        return;

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
                    seekToPercent(seekPercent);
                m_player->pause();
                m_isPaused = true;
                emit isPausedChanged();
                QObject::disconnect(*conn);
            }
        }
    );

    // 优先使用本地缓存文件，避免过期 URL 导致 403
    PlaylistCacheStore::ensureCacheDir();
    QString cacheFilePath = getCacheDir() + "/" + song.title + "-" + song.singername + ".mp3";
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

void PlaylistManager::fetchSongUrl(const QString &hash, std::function<void(QString)> callback)
{
    ApiClient::instance().get(
        QString("https://xjt-togethertracks.top/api/song/url?hash=%1").arg(hash),
        [callback](QByteArray body)
        {
            const QJsonDocument doc = QJsonDocument::fromJson(body);
            if (doc.isObject())
            {
                const QJsonArray urlarray = doc.object()["url"].toArray();
                callback(urlarray.isEmpty() ? QString() : urlarray[0].toString());
            }
            else
            {
                callback(QString());
            }
        },
        [callback](QString err, int)
        {
            Q_UNUSED(err);
            callback(QString());
        },
        10000
    );
}

void PlaylistManager::fetchLyricData(const QString &hash, std::function<void(QString)> callback)
{
    // 第一步：根据 hash 获取歌词信息
    ApiClient::instance().getJson(
        QString("https://xjt-togethertracks.top/api/search/lyric?hash=%1").arg(hash),
        [this, hash, callback](QJsonObject root)
        {
            const QJsonArray candidates = root["candidates"].toArray();
            if (candidates.isEmpty() || !candidates[0].isObject())
            {
                callback(QString());
                return;
            }
            const QJsonObject lyricInfo = candidates[0].toObject();
            const QString id            = lyricInfo["id"].toString();
            const QString accesskey     = lyricInfo["accesskey"].toString();
            if (!id.isEmpty() && !accesskey.isEmpty())
            {
                // 第二步：使用 id 和 accesskey 获取具体歌词内容
                fetchLyricContent(id, accesskey, callback);
                return;
            }
            qWarning() << "未找到有效的id或accesskey";
            callback(QString());
        },
        [callback](QString err, int)
        {
            Q_UNUSED(err);
            callback(QString());
        },
        10000
    );
}

void PlaylistManager::fetchLyricContent(
    const QString &id, const QString &accesskey, std::function<void(QString)> callback
)
{
    const QString urlStr = QString("https://xjt-togethertracks.top/api/lyric?id=%1&accesskey=%2&fmt=krc&decode=true")
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

void PlaylistManager::showplaylist()
{
    for (int index = 0; index < (*m_curplaylist).size(); index++)
    {
        qDebug() << "当前歌曲列表:" << index + 1 << (*m_curplaylist)[index].title;
    }
}
void PlaylistManager::updatePlaybackProgress(qint64 position)
{
    // 歌曲播完后 position 会重置到 0，跳过以避免歌词闪回第一句
    if (m_player->mediaStatus() == QMediaPlayer::EndOfMedia)
        return;

    if (m_player->duration() > 0)
    {
        m_percent    = static_cast<float>(position) / m_player->duration();
        m_percentstr = formatTime(position);
        emit percentChanged();

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
        // 缓冲恢复：下载进度领先播放进度足够多
        if (m_isBuffering && m_downloadProgress - m_percent > 0.1)
        {
            m_isBuffering = false;
            m_player->play();
            emit isBufferingChanged();
            qDebug() << "缓冲完成，恢复播放";
        }
        // 更新歌词
        QString newlyric      = m_lyricParser.getLyricAtTime(position);
        int newCharIndex      = m_lyricParser.getCharIndexAtTime(position);
        float newCharProgress = m_lyricParser.getCharProgressAtTime(position);
        QVariantList newChars = m_lyricParser.getCurrentChars(position);

        // 始终更新进度（用于平滑动画）
        bool progressChanged = qAbs(newCharProgress - m_lyricCharProgress) > 0.001f;
        m_lyricCharProgress  = newCharProgress;

        if (newlyric != currlyric || newCharIndex != m_lyricCharIndex)
        {
            currlyric        = newlyric;
            m_lyricCharIndex = newCharIndex;
            m_lyricChars     = newChars;
            // 更新字符数（用于英文歌词高亮计算）
            m_lyricCharCount = newChars.size();
            emit currlyricChanged();
        }
        else if (progressChanged)
        {
            // 即使索引没变，进度变化也需要通知
            emit currlyricChanged();
        }
    }
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

void PlaylistManager::handlePlayerError(QMediaPlayer::Error error, const QString &errorString)
{
    if (m_isRepairing)
    {
        qWarning() << "正在修复中，忽略重复错误";
        return;
    }

    qWarning() << "播放出错:" << errorString << "错误代码:" << error;

    // FormatError 且正在播放本地缓存文件（非边下边播）-> 删除损坏的缓存并重新下载
    if (error == QMediaPlayer::FormatError && type == TOGETHER)
    {
        QUrl src = m_player->source();
        if (src.isLocalFile())
        {
            QString localPath = src.toLocalFile();
            QFileInfo fi(localPath);
            // 只处理文件不再增长的情况（非边下边播）
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
                    qDebug() << "一起听 - 缓存文件损坏，删除并重新下载:" << localPath;
                    m_player->stop();
                    m_player->setSource(QUrl());
                    QFile::remove(localPath);
                    m_currentTogetherSongHash.clear(); // 允许重新播放同一首歌

                    if (m_currentIndex >= 0 && m_currentIndex < m_togetherplaylist.size())
                    {
                        const SongInfo &song = m_togetherplaylist[m_currentIndex];
                        if (!song.url.isEmpty())
                        {
                            playTogetherSongFromServer(
                                song.url, song.title, song.songhash, song.singername, song.union_cover, song.album_name,
                                song.duration
                            );
                        }
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
        // 修复失败，跳到下一首但不自动播放
        qWarning() << "修复失败，跳过当前歌曲";
        m_repairCount = 0;
        m_isPaused    = true;
        emit isPausedChanged();
        // 只切歌不播放
        int nextIdx = m_currentIndex + 1;
        if (nextIdx >= (*m_curplaylist).size())
            nextIdx = 0;
        if (nextIdx != m_currentIndex && nextIdx < (*m_curplaylist).size())
        {
            m_currentIndex = nextIdx;
            emit currentIndexChanged(nextIdx);
            loadSongPaused(nextIdx);
        }
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
        song.added_by_nickname = obj["added_by_nickname"].toString();
        song.added_by_avatar   = obj["added_by_avatar"].toString();
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
    const QString &coverUrl, const QString &albumName, const QString &duration
)
{
    // 防重入：同一首歌正在播放或下载中，跳过
    if (m_currentTogetherSongHash == songHash)
    {
        qDebug() << "一起听 - 跳过重复播放请求:" << songName;
        return;
    }
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
    QString cacheDir      = getCacheDir();
    QString cacheFileName = songName + "-" + singerName + ".mp3";
    QString cacheFilePath = cacheDir + "/" + cacheFileName;
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
        downloadAndStream(songUrl, cacheFilePath, QString(), seekPercent, nullptr);
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
