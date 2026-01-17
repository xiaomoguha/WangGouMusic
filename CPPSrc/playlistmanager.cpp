#include "playlistmanager.h"
#include <QDebug>
PlaylistManager::PlaylistManager(Recommendation *recommendation, QObject *parent) : QObject(parent), m_recommendation(recommendation)
{
    player->setAudioOutput(audioOutput);
    audioOutput->setVolume(1.0);
    // lyricParser();
    //  连接 mediaStatusChanged 信号
    QObject::connect(player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status)
                     {
        if (status == QMediaPlayer::EndOfMedia)
        {

            // 停止播放器，防止文件句柄未释放
            player->stop();
            player->setSource(QUrl());

            m_isPaused = true;
            emit isPausedChanged();
            this->playNext();
        }
        else if (status == QMediaPlayer::LoadedMedia)
        {
            qint64 totalDuration = player->duration();
            m_duration = formatTime(totalDuration);
            emit durationChanged();
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
            qDebug() << "歌曲已存在列表中，跳过添加";
            return;
        }
    }
    (*m_curplaylist).append({title, songhash, "", singername, union_cover, album_name, duration, ""});
    showplaylist();
    if(type == LOCAL)
    {
        emit playlistUpdated();
    }
    else if(type == TOGETHER)
    {
        emit togetherplaylistUpdated();
    }

}
void PlaylistManager::removeSong(int index)
{
    if (index >= 0 && index < (*m_curplaylist).size())
    {
        (*m_curplaylist).removeAt(index);
        emit playlistUpdated();
        if (index == m_currentIndex)
        {
            m_currentIndex = -1;
            emit currentIndexChanged(m_currentIndex);
        }
    }
}

//判断是否有缓存文件
int PlaylistManager::is_have_cache(const SongInfo &song,const int index)
{
    QString cacheDir;
#ifdef Q_OS_WIN
    cacheDir = "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    // 获取用户下载目录
    QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    cacheDir = downloadsPath + "/网狗音乐缓存目录";
#endif
    // 确保目录存在
    QDir dir(cacheDir);
    if (!dir.exists())
    {
        if (!dir.mkpath("."))
        {
            qCritical() << "无法创建缓存目录:" << cacheDir;
        }
        return 0;
    }
    //先判断本地是否有歌曲缓存
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
        emit currentIndexChanged(index);
        emit currentSongChanged();
        emit isPausedChanged();
        qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
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
void PlaylistManager::playSongbyindex(int index)
{
    if (index >= 0 && index < (*m_curplaylist).size())
    {
        //先判断是否可以用本地缓存播放
        if(!is_have_cache((*m_curplaylist)[index],index))
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
            fetchLyricData((*m_curplaylist)[index].songhash, [this, index](const QString &lyric)
                           {
                               if (!lyric.isEmpty())
                               {
                                   (*m_curplaylist)[index].lyric = lyric;
                                   lyricParser.parseLyrics(lyric);
                               }
                               else
                               {
                                   qWarning() << "获取lyric失败";
                               } });
        }
        else
        {
            lyricParser.parseLyrics((*m_curplaylist)[index].lyric);
            qDebug() << "已有歌词";
        }
    }
    else
    {
        qDebug()<<"索引出错！";
    }
}
// 根据hash值播放
void PlaylistManager::playSongbyhasg(const QString &songhash)
{
    for (int index = 0; index < (*m_curplaylist).size(); index++)
    {
        if ((*m_curplaylist)[index].songhash == songhash)
        {
            //先判断是否可以用本地缓存播放
            if(!is_have_cache((*m_curplaylist)[index],index))
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
                fetchLyricData(songhash, [this, index](const QString &lyric)
                               {
                                   if (!lyric.isEmpty())
                                   {
                                       (*m_curplaylist)[index].lyric = lyric;
                                       lyricParser.parseLyrics(lyric);
                                   }
                                   else
                                   {
                                       qWarning() << "获取lyric失败";
                                   } });
            }
            else
            {
                qDebug() << "已有歌词";
                lyricParser.parseLyrics((*m_curplaylist)[index].lyric);
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
    QMediaPlayer::PlaybackState state = player->playbackState();
    if (state == QMediaPlayer::PlayingState)
    {
        qint64 position = positionvalue * player->duration();
        player->setPosition(position);
    }
    else
    {
        qDebug() << "未在播放状态";
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
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size())
    {
        return (*m_curplaylist)[m_currentIndex].title;
    }
    return "";
}

QString PlaylistManager::currentsingername() const
{
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size())
    {
        return (*m_curplaylist)[m_currentIndex].singername;
    }
    return "";
}

QString PlaylistManager::currentSongHash() const
{
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size())
    {
        return (*m_curplaylist)[m_currentIndex].songhash;
    }
    return "";
}

int PlaylistManager::count() const
{
    return m_playlist.size();
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

QList<SongInfo> PlaylistManager::playlist()
{
    return m_playlist;
}

QList<SongInfo> PlaylistManager::togetherplaylist()
{
    return m_togetherplaylist;
}

int PlaylistManager::playlistcount() const
{
    return m_playlist.size();
}

QString PlaylistManager::getcurrlyric() const
{
    return currlyric;
}

playlist_type PlaylistManager::getplaylist_type() const
{
    return type;
}

void PlaylistManager::changeplaylisttype(enum playlist_type changetype)
{
    if (changetype == type)
    {
        return;
    }
    if (changetype == TOGETHER)
    {
        type = TOGETHER;
        m_curplaylist = &m_togetherplaylist;
    }
    else if(changetype == LOCAL)
    {
        type = LOCAL;
        m_curplaylist->clear();
        m_curplaylist = &m_playlist;
    }

}

float PlaylistManager::getpercent() const
{
    return m_percent;
}

void PlaylistManager::startPlayback(const SongInfo &song)
{
    // 停止播放器，防止文件句柄未释放
    player->stop();
    player->setSource(QUrl());

    // 初始播放阈值（字节），例如 500KB
    const qint64 startThreshold = 500 * 1024;

    QString cacheDir;
#ifdef Q_OS_WIN
    cacheDir = "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    // 获取用户下载目录
    QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    cacheDir = downloadsPath + "/网狗音乐缓存目录";
#endif
    // 确保目录存在
    QDir dir(cacheDir);
    if (!dir.exists())
    {
        if (!dir.mkpath("."))
        {
            qCritical() << "无法创建缓存目录:" << cacheDir;
            return;
        }
    }
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

    QObject::connect(reply, &QNetworkReply::readyRead, this, [=]()
                     {
        QByteArray chunk = reply->readAll();
        if (!chunk.isEmpty()) {
            tempFile->write(chunk);
            tempFile->flush();
        }

        // 可以在达到一定缓存大小后播放，实现边下边播
        QFileInfo fi(cacheFilePath);
        if (fi.size() >= startThreshold && player->source().isEmpty()) {
            player->setSource(QUrl::fromLocalFile(cacheFilePath));
            player->play();
            m_isPaused = false;
            emit currentSongChanged();
            emit isPausedChanged();
            qDebug() << "正在播放:" << song.title << "(" << song.url << ")";
            qDebug() << "开始播放边下边播:" << cacheFilePath;
        } });

    QObject::connect(reply, &QNetworkReply::finished, this, [=]()
                     {
        tempFile->flush();
        tempFile->close();
        qDebug() << "下载完成:" << cacheFilePath; });
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
    QString urlStr = QString("https://xjt-togethertracks.top/api/lyric?id=%1&accesskey=%2&fmt=lrc&decode=true").arg(id).arg(accesskey);

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
    if (player->duration() > 0)
    {
        m_percent = static_cast<float>(position) / player->duration();
        m_percentstr = formatTime(position);
        emit percentChanged();
        // 更新歌词
        QString newlyric = lyricParser.getLyricAtTime(position);
        if (newlyric != currlyric)
        {
            currlyric = newlyric;
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
        // 修复失败，跳过当前歌曲
        qWarning() << "修复失败，跳过当前歌曲";
        m_isPaused = true;
        emit isPausedChanged();
        this->playNext();
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
