#include "playlistmanager.h"
#include <QDebug>
#include <QTimer>
#include <memory>
PlaylistManager::PlaylistManager(Recommendation *recommendation, QObject *parent) : QObject(parent), m_recommendation(recommendation)
{
    player->setAudioOutput(audioOutput);
    audioOutput->setVolume(1.0);
    loadPlaylistFromCache();
    loadRecentFromCache();
    // lyricParser();
    //  连接 mediaStatusChanged 信号
    QObject::connect(player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status)
                     {
        if (status == QMediaPlayer::EndOfMedia)
        {
            m_isPaused = true;
            emit isPausedChanged();
            if (type == LOCAL)
            {
                QTimer::singleShot(200, this, [this]() {
                    this->playNext();
                });
            }
        }
        else if (status == QMediaPlayer::LoadedMedia)
        {
            qint64 totalDuration = player->duration();
            m_duration = formatTime(totalDuration);
            emit durationChanged();
            // TOGETHER 模式下，歌曲加载完成后 seek 到目标进度
            if (type == TOGETHER && m_togetherSeekPercent > 0)
            {
                qint64 targetPos = static_cast<qint64>(m_togetherSeekPercent * totalDuration);
                player->setPosition(targetPos);
                m_togetherSeekPercent = 0;
            }
        } });
    // 连接播放进度变化信号
    connect(player, &QMediaPlayer::positionChanged, this, &PlaylistManager::updatePlaybackProgress);
    connect(player, &QMediaPlayer::errorOccurred, this, &PlaylistManager::handlePlayerError);
    connect(&lyricParser, &LyricParser::parselyricsuc, this, &PlaylistManager::parselyricsuc);
}

void PlaylistManager::addSong(const QString &title, const QString &songhash, const QString &singername, const QString &union_cover, const QString &album_name, const QString &duration)
{
    for (int index = 0; index < (*m_curplaylist).size(); index++)
    {
        if ((*m_curplaylist)[index].songhash == songhash)
        {
            return;
        }
    }
    (*m_curplaylist).append({title, songhash, "", singername, union_cover, album_name, duration, ""});
    showplaylist();
    if (type == LOCAL)
    {
        savePlaylistToCache();
        emit playlistUpdated();
    }
    else if (type == TOGETHER)
    {
        emit togetherplaylistUpdated();
    }
}

void PlaylistManager::addSongNext(const QString &title, const QString &songhash, const QString &singername, const QString &union_cover, const QString &album_name, const QString &duration)
{
    for (int i = 0; i < m_playlist.size(); i++) {
        if (m_playlist[i].songhash == songhash)
            return;
    }
    SongInfo song = {title, songhash, "", singername, union_cover, album_name, duration, ""};
    int insertIndex = m_currentIndex + 1;
    if (insertIndex >= m_playlist.size())
        m_playlist.append(song);
    else
        m_playlist.insert(insertIndex, song);
    savePlaylistToCache();
    emit playlistUpdated();
}
void PlaylistManager::removeSong(int index)
{
    if (index >= 0 && index < (*m_curplaylist).size())
    {
        (*m_curplaylist).removeAt(index);
        if (type == LOCAL) savePlaylistToCache();
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
    if (type == LOCAL) savePlaylistToCache();
    emit playlistUpdated();
    emit currentIndexChanged(-1);
}

QString PlaylistManager::getCacheDir() const
{
#ifdef Q_OS_WIN
    return "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/网狗音乐缓存目录";
#else
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/网狗音乐缓存目录";
#endif
}

void PlaylistManager::ensureCacheDir() const
{
    QDir dir(getCacheDir());
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            qCritical() << "无法创建缓存目录:" << getCacheDir();
        }
    }
}

QString PlaylistManager::getPlaylistCachePath() const
{
    return getCacheDir() + "/playlist_cache.json";
}

QString PlaylistManager::getRecentCachePath() const
{
    return getCacheDir() + "/recent_cache.json";
}

QList<SongInfo> PlaylistManager::recentPlaylist() const
{
    return m_recentPlaylist;
}

void PlaylistManager::addToRecent(const SongInfo &song)
{
    if (song.songhash.isEmpty()) return;

    // 如果已存在则先移除
    for (int i = 0; i < m_recentPlaylist.size(); ++i) {
        if (m_recentPlaylist[i].songhash == song.songhash) {
            m_recentPlaylist.removeAt(i);
            break;
        }
    }

    // 插入到头部
    m_recentPlaylist.prepend(song);

    // 超出上限则移除最旧的
    while (m_recentPlaylist.size() > MAX_RECENT_SIZE) {
        m_recentPlaylist.removeLast();
    }

    saveRecentToCache();
    emit recentPlaylistUpdated();
}

void PlaylistManager::saveRecentToCache()
{
    ensureCacheDir();
    QJsonArray arr;
    for (const SongInfo &song : m_recentPlaylist) {
        QJsonObject obj;
        obj["title"] = song.title;
        obj["songhash"] = song.songhash;
        obj["singername"] = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"] = song.album_name;
        obj["duration"] = song.duration;
        arr.append(obj);
    }
    QJsonDocument doc(arr);
    QFile file(getRecentCachePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
    }
}

void PlaylistManager::loadRecentFromCache()
{
    QFile file(getRecentCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) return;

    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray()) return;

    m_recentPlaylist.clear();
    QJsonArray arr = doc.array();
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title = obj["title"].toString();
        song.songhash = obj["songhash"].toString();
        song.singername = obj["singername"].toString();
        song.union_cover = obj["union_cover"].toString();
        song.album_name = obj["album_name"].toString();
        song.duration = obj["duration"].toString();
        m_recentPlaylist.append(song);
    }
}

// 判断是否有缓存文件
int PlaylistManager::is_have_cache(const SongInfo &song, const int index)
{
    ensureCacheDir();
    QString cacheDir = getCacheDir();
    // 先判断本地是否有歌曲缓存
    QString cacheFileName = song.title + "-" + song.singername + ".mp3";
    QString cacheFilePath = cacheDir + "/" + cacheFileName;

    QFile cacheFile(cacheFilePath);

    if (cacheFile.exists())
    {
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;

        // 播放本地缓存文件
        player->stop();
        player->setSource(QUrl::fromLocalFile(cacheFilePath));
        player->play();
        m_isPaused = false;
        m_currentIndex = index;
        // 提取专辑封面主色调
        extractDominantColor(song.union_cover);
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
    return lyricParser.getLyrics();
}

void PlaylistManager::parselyricsuc()
{
    emit parlyricsuc();
}

qint64 PlaylistManager::lyricsindexget()
{
    return lyricParser.getcurindex();
}

// 根据index播放
void PlaylistManager::loadSongPaused(int index)
{
    if (index < 0 || index >= (*m_curplaylist).size())
        return;

    const SongInfo &song = (*m_curplaylist)[index];
    m_currentIndex = index;
    emit currentIndexChanged(index);

    // 加载歌词
    if (song.lyric.isEmpty())
    {
        QString cachedLyric = loadLyricFromCache(song.songhash);
        if (!cachedLyric.isEmpty()) {
            (*m_curplaylist)[index].lyric = cachedLyric;
            lyricParser.parseKRCLyrics(cachedLyric);
        } else {
            fetchLyricData(song.songhash, [this, index](const QString &lyric) {
                if (!lyric.isEmpty()) {
                    (*m_curplaylist)[index].lyric = lyric;
                    saveLyricToCache((*m_curplaylist)[index].songhash, lyric);
                    lyricParser.parseKRCLyrics(lyric);
                }
            });
        }
    } else {
        lyricParser.parseKRCLyrics(song.lyric);
    }

    // 加载音频到播放器，不播放
    player->stop();
    player->setSource(QUrl());

    ensureCacheDir();
    QString cacheFilePath = getCacheDir() + "/" + song.title + "-" + song.singername + ".mp3";

    if (QFile::exists(cacheFilePath))
    {
        player->setSource(QUrl::fromLocalFile(cacheFilePath));
    }
    else if (!song.url.isEmpty())
    {
        player->setSource(QUrl(song.url));
    }
    else
    {
        // 异步获取 URL 后加载
        fetchSongUrl(song.songhash, [this, index](const QString &url) {
            if (!url.isEmpty()) {
                (*m_curplaylist)[index].url = url;
                if (m_currentIndex == index) {
                    player->setSource(QUrl(url));
                }
            }
        });
    }

    extractDominantColor(song.union_cover);
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
                fetchSongUrl((*m_curplaylist)[index].songhash, [this, index](const QString &url)
                             {
                                 if (!url.isEmpty())
                                 {
                                     (*m_curplaylist)[index].url = url;
                                     m_currentIndex = index;
                                     emit currentIndexChanged(index);
                                     startPlayback((*m_curplaylist)[index]);
                                 } else
                                 {
                                     qWarning() << "获取播放 URL 失败";
                                 } });
            }
        }
        if ((*m_curplaylist)[index].lyric == "")
        {
            // 先尝试从本地缓存加载歌词
            QString cachedLyric = loadLyricFromCache((*m_curplaylist)[index].songhash);
            if (!cachedLyric.isEmpty()) {
                (*m_curplaylist)[index].lyric = cachedLyric;
                lyricParser.parseKRCLyrics(cachedLyric);
                qDebug() << "从本地缓存加载歌词";
            } else {
                fetchLyricData((*m_curplaylist)[index].songhash, [this, index](const QString &lyric)
                               {
                                   if (!lyric.isEmpty())
                                   {
                                       (*m_curplaylist)[index].lyric = lyric;
                                       saveLyricToCache((*m_curplaylist)[index].songhash, lyric);
                                       lyricParser.parseKRCLyrics(lyric);
                                   }
                                   else
                                   {
                                       qWarning() << "获取lyric失败";
                                   } });
            }
        }
        else
        {
            lyricParser.parseKRCLyrics((*m_curplaylist)[index].lyric);
            qDebug() << "已有歌词";
        }
    }
    else
    {
        qDebug() << "索引出错！";
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
                    fetchSongUrl(songhash, [this, index](const QString &url)
                                 {
                                     if (!url.isEmpty())
                                     {
                                         (*m_curplaylist)[index].url = url;
                                         m_currentIndex = index;
                                         emit currentIndexChanged(index);
                                         startPlayback((*m_curplaylist)[index]);
                                     } else
                                     {
                                         qWarning() << "获取播放 URL 失败";
                                     } });
                }
            }
            if ((*m_curplaylist)[index].lyric == "")
            {
                // 先尝试从本地缓存加载歌词
                QString cachedLyric = loadLyricFromCache(songhash);
                if (!cachedLyric.isEmpty()) {
                    (*m_curplaylist)[index].lyric = cachedLyric;
                    lyricParser.parseKRCLyrics(cachedLyric);
                    qDebug() << "从本地缓存加载歌词";
                } else {
                    fetchLyricData(songhash, [this, index, songhash](const QString &lyric)
                                   {
                                       if (!lyric.isEmpty())
                                       {
                                           (*m_curplaylist)[index].lyric = lyric;
                                           saveLyricToCache(songhash, lyric);
                                           lyricParser.parseKRCLyrics(lyric);
                                       }
                                       else
                                       {
                                           qWarning() << "获取lyric失败";
                                       } });
                }
            }
            else
            {
                qDebug() << "已有歌词";
                lyricParser.parseKRCLyrics((*m_curplaylist)[index].lyric);
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
    QMediaPlayer::PlaybackState state = player->playbackState();

    if (state == QMediaPlayer::PlayingState)
    {
        player->pause();
        m_isPaused = true;
        emit isPausedChanged();
    }
    else
    {
        // 如果没有设置有效 URL，不允许播放
        if (player->source().isValid())
        {
            player->play();
            m_isPaused = false;
            emit isPausedChanged();
        }
        else
        {
            qDebug() << "没设置URL，无法播放!";
        }
    }
}

// 添加到播放列表并且立即播放
void PlaylistManager::addandplay(const QString &title, const QString &songhash, const QString &singername, const QString &union_cover, const QString &album_name, const QString &duration)
{
    addSong(title, songhash, singername, union_cover, album_name, duration);
    playSongbyhasg(songhash);
}

void PlaylistManager::setposistion(float positionvalue)
{
    qint64 position = positionvalue * player->duration();
    QMediaPlayer::PlaybackState state = player->playbackState();
    if (state == QMediaPlayer::PlayingState)
    {
        player->setPosition(position);
    }
    else if (player->source().isValid())
    {
        player->setPosition(position);
        player->play();
        m_isPaused = false;
        emit isPausedChanged();
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
        result.append(SongInfo{
            map["songname"].toString(),
            map["songhash"].toString(),
            "",
            map["singername"].toString(),
            map["union_cover"].toString(),
            map["album_name"].toString(),
            map["duration"].toString(),
            ""});
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

int PlaylistManager::count() const
{
    return (*m_curplaylist).size();
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
    return player->duration();
}

QList<SongInfo> PlaylistManager::playlist()
{
    return m_playlist;
}

QList<SongInfo> PlaylistManager::togetherplaylist()
{
    return m_togetherplaylist;
}

void PlaylistManager::clearTogetherSongHash()
{
    m_currentTogetherSongHash.clear();
}

int PlaylistManager::playlistcount() const
{
    return (*m_curplaylist).size();
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

playlist_type PlaylistManager::getplaylist_type() const
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

void PlaylistManager::changeplaylisttype(enum playlist_type changetype)
{
    if (changetype == type)
    {
        return;
    }
    if (changetype == TOGETHER)
    {
        // 切到一起听前，暂停并保存本地播放状态
        player->pause();
        m_isPaused = true;
        emit isPausedChanged();
        m_localIndex = m_currentIndex;
        m_localPercent = m_percent;
        type = TOGETHER;
        m_curplaylist = &m_togetherplaylist;
        m_currentIndex = -1;
        emit currentIndexChanged(-1);
    }
    else if (changetype == LOCAL)
    {
        type = LOCAL;
        m_currentTogetherSongHash.clear();
        m_curplaylist = &m_playlist;
        // 恢复本地播放索引并加载歌曲（暂停状态）
        if (m_localIndex >= 0 && m_localIndex < m_playlist.size())
        {
            m_currentIndex = m_localIndex;
            loadSongPaused(m_localIndex);
        }
    }
    emit playlistUpdated();
    emit playlist_typeChanged();
}

float PlaylistManager::getpercent() const
{
    return m_percent;
}

void PlaylistManager::startPlayback(const SongInfo &song)
{
    // 记录到最近播放
    addToRecent(song);

    // 停止播放器，防止文件句柄未释放
    player->stop();
    player->setSource(QUrl());

    // 重置下载状态
    m_downloadProgress = 1.0;
    m_isBuffering = false;
    m_downloadedBytes = 0;
    m_totalDownloadBytes = 0;
    emit downloadProgressChanged();
    emit isBufferingChanged();

    // 初始播放阈值（字节），例如 500KB
    const qint64 startThreshold = 500 * 1024;

    ensureCacheDir();
    QString cacheDir = getCacheDir();
    QString cacheFileName = song.title + "-" + song.singername + ".mp3";
    QString cacheFilePath = cacheDir + "/" + cacheFileName;

    QFile cacheFile(cacheFilePath);
    if (cacheFile.exists())
    {
        qDebug() << "缓存文件已存在，直接播放:" << cacheFilePath;

        // 播放本地缓存文件
        player->stop();
        player->setSource(QUrl::fromLocalFile(cacheFilePath));
        player->play();
        m_isPaused = false;
        // 提取专辑封面主色调
        extractDominantColor(song.union_cover);
        emit currentSongChanged();
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";

        return; // 跳过下载
    }

    // 创建临时文件
    QFile *tempFile = new QFile(cacheFilePath, this);
    if (!tempFile->open(QIODevice::WriteOnly))
    {
        qCritical() << "Cannot open cache file:" << cacheFilePath;
        return;
    }

    QNetworkAccessManager *mgr = new QNetworkAccessManager(this);
    QNetworkReply *reply = mgr->get(QNetworkRequest(QUrl(song.url)));

    // 下载进度追踪
    m_downloadProgress = 0.0;
    m_downloadedBytes = 0;
    m_totalDownloadBytes = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
    emit downloadProgressChanged();

    QObject::connect(reply, &QNetworkReply::readyRead, this, [=, this]()
                     {
        QByteArray chunk = reply->readAll();
        if (!chunk.isEmpty()) {
            tempFile->write(chunk);
            tempFile->flush();
            m_downloadedBytes += chunk.size();
            if (m_totalDownloadBytes > 0) {
                m_downloadProgress = static_cast<qreal>(m_downloadedBytes) / m_totalDownloadBytes;
                emit downloadProgressChanged();
            }
        }

        // 可以在达到一定缓存大小后播放，实现边下边播
        QFileInfo fi(cacheFilePath);
        if (fi.size() >= startThreshold && player->source().isEmpty()) {
            player->setSource(QUrl::fromLocalFile(cacheFilePath));
            player->play();
            m_isPaused = false;
            // 提取专辑封面主色调
            extractDominantColor(song.union_cover);
            emit currentSongChanged();
            emit isPausedChanged();
            qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
            qDebug() << "开始播放边下边播:" << cacheFilePath;
        } });

    QObject::connect(reply, &QNetworkReply::finished, this, [=, this]()
                     {
        tempFile->flush();
        tempFile->close();
        m_downloadProgress = 1.0;
        m_downloadedBytes = m_totalDownloadBytes;
        emit downloadProgressChanged();
        if (m_isBuffering) {
            m_isBuffering = false;
            player->play();
            emit isBufferingChanged();
        }
        qDebug() << "下载完成:" << cacheFilePath; });
}

// 保存播放列表到本地缓存
void PlaylistManager::savePlaylistToCache()
{
    ensureCacheDir();
    QJsonArray arr;
    for (const SongInfo &song : m_playlist) {
        QJsonObject obj;
        obj["title"] = song.title;
        obj["songhash"] = song.songhash;
        obj["url"] = song.url;
        obj["singername"] = song.singername;
        obj["union_cover"] = song.union_cover;
        obj["album_name"] = song.album_name;
        obj["duration"] = song.duration;
        arr.append(obj);
    }
    QJsonObject root;
    root["playlist"] = arr;
    // TOGETHER 模式下保存切换前的本地索引和进度，而非一起听的
    root["currentIndex"] = (type == TOGETHER) ? m_localIndex : m_currentIndex;
    root["percent"] = (type == TOGETHER) ? m_localPercent : m_percent;
    QJsonDocument doc(root);
    QFile file(getPlaylistCachePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
        qDebug() << "播放列表已缓存，共" << m_playlist.size() << "首歌曲";
    } else {
        qWarning() << "无法写入播放列表缓存:" << getPlaylistCachePath();
    }
}

// 从本地缓存加载播放列表
void PlaylistManager::loadPlaylistFromCache()
{
    QFile file(getPlaylistCachePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        qDebug() << "无播放列表缓存文件，跳过加载";
        return;
    }
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);

    QJsonArray arr;
    int savedIndex = -1;
    float savedPercent = 0.0f;

    if (doc.isObject()) {
        QJsonObject root = doc.object();
        arr = root["playlist"].toArray();
        savedIndex = root["currentIndex"].toInt(-1);
        savedPercent = static_cast<float>(root["percent"].toDouble(0.0));
    } else if (doc.isArray()) {
        arr = doc.array();
    } else {
        qWarning() << "播放列表缓存格式错误";
        return;
    }

    m_playlist.clear();
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) continue;
        QJsonObject obj = val.toObject();
        SongInfo song;
        song.title = obj["title"].toString();
        song.songhash = obj["songhash"].toString();
        song.url = obj["url"].toString();
        song.singername = obj["singername"].toString();
        song.union_cover = obj["union_cover"].toString();
        song.album_name = obj["album_name"].toString();
        song.duration = obj["duration"].toString();
        song.lyric = "";
        m_playlist.append(song);
    }
    emit playlistUpdated();

    // 恢复上次播放的歌曲和进度
    if (savedIndex >= 0 && savedIndex < m_playlist.size()) {
        m_currentIndex = savedIndex;
        m_restorePercent = savedPercent;
        emit currentIndexChanged(savedIndex);
        emit currentSongChanged();
        qDebug() << "从缓存恢复播放: index=" << savedIndex << "percent=" << savedPercent;
    } else {
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
    m_restorePercent = -1.0f;

    int index = m_currentIndex;
    SongInfo song = m_playlist[index];

    // 加载歌词
    if (song.lyric.isEmpty()) {
        QString cachedLyric = loadLyricFromCache(song.songhash);
        if (!cachedLyric.isEmpty()) {
            m_playlist[index].lyric = cachedLyric;
            lyricParser.parseKRCLyrics(cachedLyric);
        } else {
            fetchLyricData(song.songhash, [this](const QString &lyric) {
                if (!lyric.isEmpty())
                    lyricParser.parseKRCLyrics(lyric);
            });
        }
    } else {
        lyricParser.parseKRCLyrics(song.lyric);
    }

    extractDominantColor(song.union_cover);
    emit currentIndexChanged(index);
    emit currentSongChanged();

    // 加载歌曲但不播放
    player->stop();
    player->setSource(QUrl());

    auto conn = std::make_shared<QMetaObject::Connection>();
    *conn = connect(player, &QMediaPlayer::mediaStatusChanged, this,
        [this, seekPercent, conn](QMediaPlayer::MediaStatus status) {
            if (status == QMediaPlayer::LoadedMedia) {
                if (seekPercent > 0 && seekPercent < 1.0)
                    seekToPercent(seekPercent);
                player->pause();
                m_isPaused = true;
                emit isPausedChanged();
                QObject::disconnect(*conn);
            }
        });

    // 优先使用本地缓存文件，避免过期 URL 导致 403
    ensureCacheDir();
    QString cacheFilePath = getCacheDir() + "/" + song.title + "-" + song.singername + ".mp3";
    if (QFile::exists(cacheFilePath)) {
        player->setSource(QUrl::fromLocalFile(cacheFilePath));
    } else {
        fetchSongUrl(song.songhash, [this](const QString &url) {
            if (!url.isEmpty())
                player->setSource(QUrl(url));
        });
    }
}

// 保存歌词到本地缓存
void PlaylistManager::saveLyricToCache(const QString &songhash, const QString &lyric)
{
    if (songhash.isEmpty() || lyric.isEmpty()) return;
    ensureCacheDir();
    QString path = getCacheDir() + "/lyrics_" + songhash + ".json";
    QFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonObject obj;
        obj["songhash"] = songhash;
        obj["lyric"] = lyric;
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        file.close();
        qDebug() << "歌词已缓存:" << songhash;
    }
}

// 从本地缓存加载歌词
QString PlaylistManager::loadLyricFromCache(const QString &songhash)
{
    if (songhash.isEmpty()) return QString();
    QString path = getCacheDir() + "/lyrics_" + songhash + ".json";
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) return QString();
    QByteArray data = file.readAll();
    file.close();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return QString();
    return doc.object()["lyric"].toString();
}

void PlaylistManager::fetchSongUrl(const QString &hash, std::function<void(QString)> callback)
{
    QNetworkRequest request(QUrl("http://xjt-togethertracks.top/api/song/url?hash=" + hash));
    QNetworkReply *reply = m_networkManager.get(request);

    connect(reply, &QNetworkReply::finished, this, [reply, callback]()
            {
        if (reply->error() != QNetworkReply::NoError)
        {
            qWarning() << "请求失败:" << reply->errorString();
            callback(QString());
            reply->deleteLater();
            return;
        }

        QByteArray response = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(response);

        if (doc.isObject())
        {
            QJsonObject root = doc.object();
            QJsonArray urlarray = root["url"].toArray();
            callback(urlarray[0].toString());
        } else
        {
            callback(QString());  // 失败
        }
        reply->deleteLater(); });
}

void PlaylistManager::fetchLyricData(const QString &hash, std::function<void(QString)> callback)
{
    // 第一步：根据hash获取歌词信息
    QNetworkRequest request(QUrl("https://xjt-togethertracks.top/api/search/lyric?hash=" + hash));
    QNetworkReply *reply = m_networkManager.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, hash, callback]()
            {
        if (reply->error() != QNetworkReply::NoError)
        {
            qWarning() << "歌词信息请求失败:" << reply->errorString();
            callback(QString());
            reply->deleteLater();
            return;
        }

        QByteArray response = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(response);
        reply->deleteLater();

        if (!doc.isObject())
        {
            qWarning() << "返回数据不是JSON对象";
            callback(QString());
            return;
        }

        QJsonObject root = doc.object();

        QJsonArray candidates = root["candidates"].toArray();

        if (!candidates.isEmpty() && candidates[0].isObject())
        {
            QJsonObject lyricInfo = candidates[0].toObject();
            // 提取id和accesskey
            QString id = lyricInfo["id"].toString();
            QString accesskey = lyricInfo["accesskey"].toString();
            if (!id.isEmpty() && !accesskey.isEmpty())
            {
                // 第二步：使用id和accesskey获取具体歌词内容
                fetchLyricContent(id, accesskey, callback);
                return;
            }
            else
            {
                qWarning() << "未找到有效的id或accesskey";
            }
            qWarning() << "解析歌词信息失败";
            callback(QString());
        } });
}

void PlaylistManager::fetchLyricContent(const QString &id, const QString &accesskey, std::function<void(QString)> callback)
{
    // 构建歌词内容请求URL
    QString urlStr = QString("https://xjt-togethertracks.top/api/lyric?id=%1&accesskey=%2&fmt=krc&decode=true").arg(id).arg(accesskey);

    QUrl contentUrl(urlStr);
    QNetworkRequest request;
    request.setUrl(contentUrl);

    QNetworkReply *reply = m_networkManager.get(request);

    connect(reply, &QNetworkReply::finished, this, [reply, callback]()
            {
        if (reply->error() != QNetworkReply::NoError)
        {
            qWarning() << "歌词内容请求失败:" << reply->errorString();
            callback(QString());
            reply->deleteLater();
            return;
        }

        QByteArray response = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(response);
        reply->deleteLater();

        if (!doc.isObject())
        {
            qWarning() << "歌词内容返回数据不是JSON对象";
            callback(QString());
            return;
        }

        QJsonObject root = doc.object();

        QString decodeContent = root["decodeContent"].toString();
        callback(decodeContent); });
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
    if (player->mediaStatus() == QMediaPlayer::EndOfMedia)
        return;

    if (player->duration() > 0)
    {
        m_percent = static_cast<float>(position) / player->duration();
        m_percentstr = formatTime(position);
        emit percentChanged();

        // 缓冲检测：正在边下边播且播放追上下载进度
        if (m_downloadProgress > 0 && m_downloadProgress < 1.0)
        {
            if (!m_isBuffering && m_percent >= m_downloadProgress - 0.03f)
            {
                m_isBuffering = true;
                player->pause();
                emit isBufferingChanged();
                qDebug() << "缓冲中: 播放进度" << m_percent << "下载进度" << m_downloadProgress;
            }
        }
        // 缓冲恢复：下载进度领先播放进度足够多
        if (m_isBuffering && m_downloadProgress - m_percent > 0.1)
        {
            m_isBuffering = false;
            player->play();
            emit isBufferingChanged();
            qDebug() << "缓冲完成，恢复播放";
        }
        // 更新歌词
        QString newlyric = lyricParser.getLyricAtTime(position);
        int newCharIndex = lyricParser.getCharIndexAtTime(position);
        float newCharProgress = lyricParser.getCharProgressAtTime(position);
        QVariantList newChars = lyricParser.getCurrentChars(position);

        // 始终更新进度（用于平滑动画）
        bool progressChanged = qAbs(newCharProgress - m_lyricCharProgress) > 0.001f;
        m_lyricCharProgress = newCharProgress;

        if (newlyric != currlyric || newCharIndex != m_lyricCharIndex)
        {
            currlyric = newlyric;
            m_lyricCharIndex = newCharIndex;
            m_lyricChars = newChars;
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

void PlaylistManager::handlePlayerError(QMediaPlayer::Error error, const QString &errorString)
{
    if (m_isRepairing)
    {
        qWarning() << "正在修复中，忽略重复错误";
        return;
    }

    qWarning() << "播放出错:" << errorString << "错误代码:" << error;

    // FormatError 且正在播放本地缓存文件（非边下边播）→ 删除损坏的缓存并重新下载
    if (error == QMediaPlayer::FormatError && type == TOGETHER)
    {
        QUrl src = player->source();
        if (src.isLocalFile())
        {
            QString localPath = src.toLocalFile();
            QFileInfo fi(localPath);
            // 只处理文件不再增长的情况（非边下边播）
            qint64 size1 = fi.size();
            QTimer::singleShot(200, this, [this, localPath, size1]() {
                QFileInfo fi2(localPath);
                if (fi2.size() != size1 || size1 < 10240)
                {
                    return;
                }
                qDebug() << "一起听 - 缓存文件损坏，删除并重新下载:" << localPath;
                player->stop();
                player->setSource(QUrl());
                QFile::remove(localPath);
                m_currentTogetherSongHash.clear(); // 允许重新播放同一首歌

                if (m_currentIndex >= 0 && m_currentIndex < m_togetherplaylist.size())
                {
                    const SongInfo &song = m_togetherplaylist[m_currentIndex];
                    if (!song.url.isEmpty())
                    {
                        playTogetherSongFromServer(song.url, song.title, song.songhash,
                                                   song.singername, song.union_cover,
                                                   song.album_name, song.duration);
                    }
                }
            });
            return;
        }
    }

    // 检查是否是FFmpeg解复用错误
    if ((errorString.contains("Demuxing failed") || errorString.contains("AV_NOPTS_VALUE")) && m_repairCount < MAX_REPAIR_ATTEMPTS)
    {
        m_isRepairing = true;
        m_repairCount++;

        qDebug() << "尝试第" << m_repairCount << "次重新播放...";

        qint64 lastPos = player->position();
        QString currentUrl = m_playlist[m_currentIndex].url;

        // 先停止并清空当前播放
        player->stop();
        player->setSource(QUrl());
        m_isPaused = true;
        emit isPausedChanged();
        // 延迟后重试
        QTimer::singleShot(50, this, [=]()
                           {
                               player->setSource(QUrl(currentUrl));
                               player->play();

                               connect(player, &QMediaPlayer::mediaStatusChanged, this,
                                       [=](QMediaPlayer::MediaStatus status) {
                                           if (status == QMediaPlayer::LoadedMedia)
                                            {
                                               player->setPosition(lastPos);
                                           }
                                       }, Qt::SingleShotConnection);
                               m_isPaused = false;
                               emit isPausedChanged();
                               m_isRepairing = false; });
    }
    else
    {
        // 修复失败，跳到下一首但不自动播放
        qWarning() << "修复失败，跳过当前歌曲";
        m_repairCount = 0;
        m_isPaused = true;
        emit isPausedChanged();
        // 只切歌不播放
        int nextIdx = m_currentIndex + 1;
        if (nextIdx >= (*m_curplaylist).size()) nextIdx = 0;
        if (nextIdx != m_currentIndex && nextIdx < (*m_curplaylist).size()) {
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

// 提取图片主色调
void PlaylistManager::extractDominantColor(const QString &imageUrl)
{
    // 如果是本地资源或网络图片
    if (imageUrl.startsWith("qrc:/"))
    {
        // 本地资源
        QString path = imageUrl;
        path.remove("qrc:");
        QImage image(path);
        if (!image.isNull())
        {
            QColor color = getAverageColor(image);
            m_dominantColor = color.name(QColor::HexRgb).toUpper();
            emit dominantColorChanged();
        }
    }
    else if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://"))
    {
        // 网络图片 - 异步下载
        QNetworkRequest request{QUrl(imageUrl)};
        QNetworkReply *reply = m_networkManager.get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply]()
                {
            if (reply->error() == QNetworkReply::NoError) {
                QByteArray data = reply->readAll();
                QImage image = QImage::fromData(data);
                if (!image.isNull()) {
                    QColor color = getAverageColor(image);
                    m_dominantColor = color.name(QColor::HexRgb).toUpper();
                    emit dominantColorChanged();
                }
            }
            reply->deleteLater(); });
    }
    else
    {
        // 尝试作为本地文件路径
        QImage image(imageUrl);
        if (!image.isNull())
        {
            QColor color = getAverageColor(image);
            m_dominantColor = color.name(QColor::HexRgb).toUpper();
            emit dominantColorChanged();
        }
    }
}

// 计算图片的平均颜色
QColor PlaylistManager::getAverageColor(const QImage &image)
{
    if (image.isNull())
    {
        return QColor("#FF6B6B");
    }

    // 缩小图片以加快处理速度
    QImage smallImage = image.scaled(50, 50, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    long totalR = 0, totalG = 0, totalB = 0;
    int pixelCount = 0;

    // 遍历所有像素
    for (int y = 0; y < smallImage.height(); ++y)
    {
        for (int x = 0; x < smallImage.width(); ++x)
        {
            QColor color = smallImage.pixelColor(x, y);

            // 忽略太暗或太亮的像素
            int brightness = (color.red() + color.green() + color.blue()) / 3;
            if (brightness > 20 && brightness < 235)
            {
                totalR += color.red();
                totalG += color.green();
                totalB += color.blue();
                pixelCount++;
            }
        }
    }

    if (pixelCount == 0)
    {
        return QColor("#FF6B6B");
    }

    // 计算平均值
    int avgR = totalR / pixelCount;
    int avgG = totalG / pixelCount;
    int avgB = totalB / pixelCount;

    // 增加饱和度，使颜色更鲜艳
    QColor avgColor(avgR, avgG, avgB);
    int h, s, v;
    avgColor.getHsv(&h, &s, &v);

    // 提高饱和度和亮度
    s = qMin(255, s + 50);
    v = qMin(255, v + 30);

    QColor finalColor;
    finalColor.setHsv(h, s, v);

    return finalColor;
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
        song.title = obj["songname"].toString();
        song.songhash = obj["songhash"].toString();
        song.singername = obj["singername"].toString();
        song.album_name = obj["album_name"].toString();
        song.duration = obj["duration"].toString();
        song.union_cover = obj["cover_url"].toString();
        song.added_by_nickname = obj["added_by_nickname"].toString();
        song.added_by_avatar = obj["added_by_avatar"].toString();
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

    emit togetherplaylistUpdated();
}

void PlaylistManager::playTogetherSongFromServer(const QString &songUrl, const QString &songName,
                                                   const QString &songHash, const QString &singerName,
                                                   const QString &coverUrl, const QString &albumName,
                                                   const QString &duration)
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
        recentSong.title = songName;
        recentSong.songhash = songHash;
        recentSong.singername = singerName;
        recentSong.union_cover = coverUrl;
        recentSong.album_name = albumName;
        recentSong.duration = duration;
        addToRecent(recentSong);
    }

    // 查找或创建歌曲条目
    int playIndex = -1;
    for (int i = 0; i < m_togetherplaylist.size(); i++)
    {
        if (m_togetherplaylist[i].songhash == songHash)
        {
            m_togetherplaylist[i].url = songUrl;
            playIndex = i;
            break;
        }
    }
    if (playIndex < 0)
    {
        SongInfo song;
        song.title = songName;
        song.songhash = songHash;
        song.url = songUrl;
        song.singername = singerName;
        song.union_cover = coverUrl;
        song.album_name = albumName;
        song.duration = duration;
        m_togetherplaylist.append(song);
        playIndex = m_togetherplaylist.size() - 1;
        emit togetherplaylistUpdated();
    }
    m_currentIndex = playIndex;
    emit currentIndexChanged(playIndex);

    player->stop();
    player->setSource(QUrl());

    // 重置下载状态
    m_downloadProgress = 1.0;
    m_isBuffering = false;
    m_downloadedBytes = 0;
    m_totalDownloadBytes = 0;
    emit downloadProgressChanged();
    emit isBufferingChanged();

    ensureCacheDir();
    QString cacheDir = getCacheDir();
    QString cacheFileName = songName + "-" + singerName + ".mp3";
    QString cacheFilePath = cacheDir + "/" + cacheFileName;
    bool useCache = false;
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
        player->setSource(QUrl::fromLocalFile(cacheFilePath));

        if (m_togetherSeekPercent > 0)
        {
            double seekPercent = m_togetherSeekPercent;
            m_togetherSeekPercent = 0;
            auto conn = std::make_shared<QMetaObject::Connection>();
            *conn = connect(player, &QMediaPlayer::mediaStatusChanged, this,
                [this, seekPercent, conn](QMediaPlayer::MediaStatus status) {
                    if (status == QMediaPlayer::LoadedMedia)
                    {
                        seekToPercent(seekPercent);
                        player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                        QObject::disconnect(*conn);
                    }
                });
        }
        else
        {
            player->play();
            m_isPaused = false;
            emit isPausedChanged();
        }
    }
    else if (!songUrl.isEmpty())
    {
        // 无缓存 - 边下边播，保存到本地缓存文件
        const qint64 startThreshold = 500 * 1024;

        QFile *tempFile = new QFile(cacheFilePath, this);
        if (!tempFile->open(QIODevice::WriteOnly))
        {
            qCritical() << "Cannot open cache file:" << cacheFilePath;
            player->setSource(QUrl(songUrl));
            player->play();
            m_isPaused = false;
            emit isPausedChanged();
        }
        else
        {
            QNetworkAccessManager *mgr = new QNetworkAccessManager(this);
            QNetworkReply *reply = mgr->get(QNetworkRequest(QUrl(songUrl)));

            m_downloadProgress = 0.0;
            m_downloadedBytes = 0;
            m_totalDownloadBytes = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong();
            emit downloadProgressChanged();

            double seekPercent = m_togetherSeekPercent;
            m_togetherSeekPercent = 0;

            QObject::connect(reply, &QNetworkReply::readyRead, this, [=, this]() {
                QByteArray chunk = reply->readAll();
                if (!chunk.isEmpty()) {
                    tempFile->write(chunk);
                    tempFile->flush();
                    m_downloadedBytes += chunk.size();
                    if (m_totalDownloadBytes > 0) {
                        m_downloadProgress = static_cast<qreal>(m_downloadedBytes) / m_totalDownloadBytes;
                        emit downloadProgressChanged();
                    }
                }

                QFileInfo fi(cacheFilePath);
                if (fi.size() >= startThreshold && player->source().isEmpty()) {
                    player->setSource(QUrl::fromLocalFile(cacheFilePath));
                    if (seekPercent > 0) {
                        auto conn = std::make_shared<QMetaObject::Connection>();
                        *conn = connect(player, &QMediaPlayer::mediaStatusChanged, this,
                            [this, seekPercent, conn](QMediaPlayer::MediaStatus status) {
                                if (status == QMediaPlayer::LoadedMedia)
                                {
                                    seekToPercent(seekPercent);
                                    player->play();
                                    m_isPaused = false;
                                    emit isPausedChanged();
                                    QObject::disconnect(*conn);
                                }
                            });
                    } else {
                        player->play();
                        m_isPaused = false;
                        emit isPausedChanged();
                    }
                }
            });

            QObject::connect(reply, &QNetworkReply::finished, this, [=, this]() {
                tempFile->flush();
                tempFile->close();
                m_downloadProgress = 1.0;
                m_downloadedBytes = m_totalDownloadBytes;
                emit downloadProgressChanged();
                if (m_isBuffering) {
                    m_isBuffering = false;
                    player->play();
                    emit isBufferingChanged();
                }
                qDebug() << "一起听 - 下载完成:" << cacheFilePath;

                // 文件太小没触发阈值时，手动设置源并播放
                if (player->source().isEmpty() && QFile::exists(cacheFilePath)) {
                    player->setSource(QUrl::fromLocalFile(cacheFilePath));
                    player->play();
                    m_isPaused = false;
                    emit isPausedChanged();
                }

                reply->deleteLater();
                mgr->deleteLater();
                tempFile->deleteLater();
            });
        }
    }
    else
    {
        // URL 为空，通过 hash 获取播放链接
        m_isPaused = true;
        double seekPercent = m_togetherSeekPercent;
        m_togetherSeekPercent = 0;
        fetchSongUrl(songHash, [this, songHash, seekPercent](const QString &url) {
            if (!url.isEmpty())
            {
                player->setSource(QUrl(url));
                if (seekPercent > 0) {
                    auto conn = std::make_shared<QMetaObject::Connection>();
                    *conn = connect(player, &QMediaPlayer::mediaStatusChanged, this,
                        [this, seekPercent, conn](QMediaPlayer::MediaStatus status) {
                            if (status == QMediaPlayer::LoadedMedia)
                            {
                                seekToPercent(seekPercent);
                                player->play();
                                m_isPaused = false;
                                emit isPausedChanged();
                                QObject::disconnect(*conn);
                            }
                        });
                } else {
                    player->play();
                    m_isPaused = false;
                    emit isPausedChanged();
                }
            }
            else
            {
                qWarning() << "一起听模式 - 无法获取歌曲URL，hash:" << songHash;
            }
        });
    }

    extractDominantColor(coverUrl);
    emit currentSongChanged();
    emit isPausedChanged();

    fetchLyricData(songHash, [this](const QString &lyric)
    {
        if (!lyric.isEmpty())
        {
            lyricParser.parseKRCLyrics(lyric);
            qDebug() << "一起听模式 - 歌词获取成功，长度:" << lyric.length();
        }
        else
        {
            qWarning() << "一起听模式 - 获取歌词失败";
        }
    });
}

void PlaylistManager::seekToPercent(double percent)
{
    if (player->duration() > 0)
    {
        qint64 targetPos = static_cast<qint64>(percent * player->duration());
        player->setPosition(targetPos);
    }
}

void PlaylistManager::setTogetherSeekPercent(double percent)
{
    m_togetherSeekPercent = percent;
}

void PlaylistManager::setPaused(bool paused)
{
    if (paused && player->playbackState() == QMediaPlayer::PlayingState)
    {
        player->pause();
        m_isPaused = true;
        emit isPausedChanged();
    }
    else if (!paused && player->playbackState() != QMediaPlayer::PlayingState)
    {
        player->play();
        m_isPaused = false;
        emit isPausedChanged();
    }
}
