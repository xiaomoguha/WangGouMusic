#include "personalfm.h"
#include "SongInfo.h"
#include "usermanager.h"

#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QMap>
#include <QSet>
#include <QSettings>
#include <QUrlQuery>

void PersonalFM::setUserManager(UserManager *um)
{
    m_userManager = um;
}

PersonalFM::PersonalFM(QObject *parent) : QObject(parent)
{
    QSettings settings;
    m_mode = qBound(0, settings.value("personal_fm_mode", 0).toInt(), 3);
    m_pool = qBound(0, settings.value("personal_fm_pool", 0).toInt(), 2);

    connect(&m_requester, &HttpGetRequester::dataReceived, this, &PersonalFM::onData);
    connect(&m_requester, &HttpGetRequester::requestFailed, this, [this](const QString &err)
            {
                qWarning() << "[PersonalFM] fetch error:" << err;
                onFailed();
            });
    connect(&m_requester, &HttpGetRequester::requestTimeout, this, [this]()
            {
                qWarning() << "[PersonalFM] fetch timeout";
                onFailed();
            });
    connect(&m_feedbackRequester, &HttpGetRequester::dataReceived, this, &PersonalFM::onFeedbackData);
    connect(&m_feedbackRequester, &HttpGetRequester::requestFailed, this, &PersonalFM::onFeedbackFailed);
    connect(&m_feedbackRequester, &HttpGetRequester::requestTimeout, this, [this]() { onFeedbackFailed(QString()); });
    connect(&m_coverRequester, &HttpGetRequester::dataReceived, this, &PersonalFM::onCoverData);
    connect(&m_coverRequester, &HttpGetRequester::requestFailed, this, &PersonalFM::onCoverFailed);
    connect(&m_coverRequester, &HttpGetRequester::requestTimeout, this, [this]() { onCoverFailed(QString()); });
}

void PersonalFM::fetch()
{
    if (m_isLoading)
        return;
    request(QString(), QStringLiteral("play"), false);
}

void PersonalFM::fetchNext()
{
    if (m_isLoading || m_songs.isEmpty())
        return;
    // 换一批 = 把本批最后一首歌的 hash 传给服务端，取下一批
    request(m_songs.last().toMap()["songhash"].toString(), QStringLiteral("play"), false);
}

void PersonalFM::startQueue()
{
    if (!m_queueMode)
    {
        m_queueMode = true;
        emit queueModeChanged();
    }

    m_fillAttempts = 0;

    // 首次进入连续 FM：先用首页已经拿到的 5 首，立即可播，不用等网络
    if (m_queue.isEmpty() && !m_songs.isEmpty())
        appendToQueue(m_songs);

    if (m_queue.isEmpty())
    {
        if (m_isLoading)
        {
            // 正在请求的那批直接作为首批写入队列
            m_appendBatch = true;
        }
        else
        {
            request(QString(), QStringLiteral("play"), true);
        }
    }
    else if (m_queue.size() < 10)
    {
        // 接口每批 5 首，连取两批把右侧队列填到 10 首
        if (m_isLoading)
            m_appendBatch = true;
        else
            requestMore();
    }
}

void PersonalFM::stopQueue()
{
    if (!m_queueMode)
        return;
    m_queueMode = false;
    m_fillAttempts = 0;
    // 正在飞的请求回来时只更新卡片，不再向队列追加
    m_appendBatch = false;
    emit queueModeChanged();
}

void PersonalFM::requestMore()
{
    if (!m_queueMode || m_isLoading)
        return;
    QString hash = m_queue.isEmpty() ? lastHash() : m_queue.last().toMap()["songhash"].toString();
    request(hash, QStringLiteral("play"), true);
}

void PersonalFM::refreshQueue()
{
    if (!m_queueMode)
    {
        m_queueMode = true;
        emit queueModeChanged();
    }

    m_queue.clear();
    m_fillAttempts = 0;
    emit queueChanged();

    if (m_isLoading)
    {
        // 正在飞的请求直接作为新队列首批
        m_appendBatch = true;
    }
    else
    {
        request(QString(), QStringLiteral("play"), true);
    }
}

void PersonalFM::setMode(int mode)
{
    mode = qBound(0, mode, 3);
    if (mode == m_mode)
        return;
    m_mode = mode;
    QSettings().setValue("personal_fm_mode", mode);
    emit modeChanged();

    // 切推荐模式立即换一批；正在请求时等回来后再换，避免打断
    if (m_isLoading)
        m_reloadAfterLoad = true;
    else
        request(QString(), QStringLiteral("play"), m_queueMode);
}

void PersonalFM::setPool(int pool)
{
    pool = qBound(0, pool, 2);
    if (pool == m_pool)
        return;
    m_pool = pool;
    QSettings().setValue("personal_fm_pool", pool);
    emit poolChanged();

    if (m_isLoading)
        m_reloadAfterLoad = true;
    else
        request(QString(), QStringLiteral("play"), m_queueMode);
}

void PersonalFM::like(const QString &hash)
{
    if (!hash.isEmpty())
        requestFeedback(hash, QStringLiteral("click_red"));
}

void PersonalFM::dislike(const QString &hash)
{
    if (!hash.isEmpty())
        requestFeedback(hash, QStringLiteral("garbage"));
}

void PersonalFM::banSinger(const QString &hash)
{
    if (!hash.isEmpty())
        requestFeedback(hash, QStringLiteral("black_singer"));
}

QString PersonalFM::lastHash() const
{
    return m_songs.isEmpty() ? QString() : m_songs.last().toMap()["songhash"].toString();
}

QString PersonalFM::modeString() const
{
    switch (m_mode)
    {
    case 1: return QStringLiteral("small");
    case 2: return QStringLiteral("peak");
    case 3: return QStringLiteral("radio");
    default: return QStringLiteral("normal");
    }
}

void PersonalFM::request(const QString &hash, const QString &action, bool append)
{
    m_isLoading = true;
    m_appendBatch = append;
    emit isLoadingChanged();

    QUrlQuery query;
    // 登录态参与推荐（匿名也能听，只是推荐会弱一些）
    if (m_userManager)
    {
        if (!m_userManager->userid().isEmpty())
            query.addQueryItem("userid", m_userManager->userid());
        if (!m_userManager->token().isEmpty())
            query.addQueryItem("token", m_userManager->token());
    }
    if (!hash.isEmpty())
        query.addQueryItem("hash", hash);
    if (!action.isEmpty())
        query.addQueryItem("action", action);
    query.addQueryItem("mode", modeString());
    query.addQueryItem("song_pool_id", QString::number(m_pool));

    const QString url = "https://api.special520.com/personal/fm" + (query.isEmpty() ? "" : "?" + query.toString());
    m_requester.fetchData(url);
}

void PersonalFM::requestFeedback(const QString &hash, const QString &action)
{
    m_feedbackAction = action;

    QUrlQuery query;
    if (m_userManager)
    {
        if (!m_userManager->userid().isEmpty())
            query.addQueryItem("userid", m_userManager->userid());
        if (!m_userManager->token().isEmpty())
            query.addQueryItem("token", m_userManager->token());
    }
    query.addQueryItem("hash", hash);
    query.addQueryItem("action", action);
    query.addQueryItem("mode", modeString());
    query.addQueryItem("song_pool_id", QString::number(m_pool));
    if (!m_curMark.isEmpty())
        query.addQueryItem("cur_mark", m_curMark);

    const QString url = "https://api.special520.com/personal/fm?" + query.toString();
    m_feedbackRequester.fetchData(url);
}

void PersonalFM::onFailed()
{
    m_isLoading = false;
    emit isLoadingChanged();
    emit errorOccurred(QStringLiteral("个人FM 加载失败，请稍后重试"));

    if (m_reloadAfterLoad)
    {
        m_reloadAfterLoad = false;
        request(QString(), QStringLiteral("play"), m_queueMode);
    }
}

void PersonalFM::onFeedbackFailed(const QString &err)
{
    if (!err.isEmpty())
        qWarning() << "[PersonalFM] feedback error:" << err;
    m_feedbackAction.clear();
    emit errorOccurred(QStringLiteral("推荐反馈提交失败"));
}

QVariantList PersonalFM::parseSongs(const QJsonArray &list) const
{
    QVariantList songs;
    for (const QJsonValue &val : list)
    {
        const QJsonObject s = val.toObject();
        const QString hash = s["hash"].toString();
        const QString name = s["songname"].toString();
        if (hash.isEmpty() || name.isEmpty())
            continue;
        SongInfo::rememberMxidFromJson(s, hash);

        QString singername;
        const QJsonArray singers = s["singerinfo"].toArray();
        if (!singers.isEmpty())
        {
            QStringList names;
            for (const QJsonValue &si : singers)
            {
                const QString n = si.toObject()["name"].toString();
                if (!n.isEmpty())
                    names << n;
            }
            singername = names.join(", ");
        }
        if (singername.isEmpty())
            singername = s["author_name"].toString();
        if (singername.isEmpty())
        {
            const QString filename = s["filename"].toString();
            const int dash = filename.indexOf(" - ");
            if (dash > 0)
                singername = filename.left(dash);
        }

        QString cover = s["trans_param"].toObject()["union_cover"].toString();
        if (cover.isEmpty())
            cover = s["info"].toObject()["image"].toString();
        if (cover.isEmpty())
            cover = s["cover"].toString();
        cover.replace("{size}", "400");

        const QJsonObject rec = s["rec_song_info"].toObject();
        const int fmSec = s["time_length"].toVariant().toInt();

        QVariantMap item;
        item["songname"] = name;
        item["songhash"] = hash;
        item["singername"] = singername;
        item["union_cover"] = cover;
        item["album_name"] = s["album_name"].toString();
        item["album_id"] = s["album_id"].toVariant().toString();
        item["songid"] = s["songid"].toVariant().toString();
        item["rec_desc"] = rec["rec_desc"].toString();
        item["similar_desc"] = rec["similar_desc"].toString();
        // FM 接口的 song_list 已带 time_length（秒），缺失时留空，
        // 下一次列表会以 "--:--" 显示；播放器本身仍可按 240s 兜底
        item["duration"] = fmSec > 0
                               ? QStringLiteral("%1:%2").arg(fmSec / 60).arg(fmSec % 60, 2, 10, QLatin1Char('0'))
                               : QString();
        songs.append(item);
    }
    return songs;
}

int PersonalFM::appendToQueue(const QVariantList &songs)
{
    if (songs.isEmpty())
        return 0;

    QSet<QString> existing;
    for (const QVariant &v : m_queue)
        existing.insert(v.toMap()["songhash"].toString());

    QVariantList added;
    for (const QVariant &v : songs)
    {
        const QVariantMap item = v.toMap();
        const QString hash = item["songhash"].toString();
        if (hash.isEmpty() || existing.contains(hash))
            continue;
        existing.insert(hash);
        m_queue.append(item);
        added.append(item);
    }

    if (added.isEmpty())
        return 0;

    emit queueChanged();
    emit songsAppended(added);
    return added.size();
}

void PersonalFM::onData(const QByteArray &data)
{
    m_isLoading = false;
    emit isLoadingChanged();

    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError)
    {
        qWarning() << "[PersonalFM] JSON parse error:" << perr.errorString();
        emit errorOccurred(QStringLiteral("个人FM 数据解析失败"));
        return;
    }
    const QJsonObject root = doc.object();
    if (root["status"].toInt() != 1)
    {
        qWarning() << "[PersonalFM] status != 1";
        emit errorOccurred(QStringLiteral("个人FM 服务暂时不可用"));
        return;
    }

    const QJsonObject dataObj = root["data"].toObject();
    const QString mark = dataObj["cur_mark"].toVariant().toString();
    if (!mark.isEmpty())
        m_curMark = mark;

    const QJsonArray list = dataObj["song_list"].toArray();
    if (list.isEmpty())
    {
        qWarning() << "[PersonalFM] empty song_list";
        emit errorOccurred(QStringLiteral("个人FM 暂无推荐"));
        return;
    }

    const QVariantList batch = parseSongs(list);
    if (batch.isEmpty())
    {
        qWarning() << "[PersonalFM] parsed empty";
        emit errorOccurred(QStringLiteral("个人FM 暂无推荐"));
        return;
    }

    const bool append = m_appendBatch && m_queueMode;
    int added = 0;
    if (!append || m_songs.isEmpty())
    {
        m_songs = batch;
        emit songsChanged();
    }
    if (append)
        added = appendToQueue(batch);

    beginCoverFetch(batch);
    m_appendBatch = false;

    qDebug() << "[PersonalFM] 本批" << batch.size() << "首，队列" << m_queue.size() << "首，排队模式" << m_queueMode;

    if (m_reloadAfterLoad)
    {
        m_reloadAfterLoad = false;
        request(QString(), QStringLiteral("play"), m_queueMode);
        return;
    }

    // 接口每批 5 首：首次进 FM 页自动再补一批，把队列填到 10 首
    if (append && m_queueMode && added > 0 && m_queue.size() < 10 && m_fillAttempts < 2)
    {
        m_fillAttempts++;
        requestMore();
    }
}

void PersonalFM::onFeedbackData(const QByteArray &data)
{
    const QString action = m_feedbackAction;
    m_feedbackAction.clear();

    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError)
    {
        emit errorOccurred(QStringLiteral("推荐反馈失败"));
        return;
    }
    const QJsonObject root = doc.object();
    if (root["status"].toInt() != 1)
    {
        emit errorOccurred(QStringLiteral("推荐反馈失败"));
        return;
    }

    const QJsonObject dataObj = root["data"].toObject();
    const QString mark = dataObj["cur_mark"].toVariant().toString();
    if (!mark.isEmpty())
        m_curMark = mark;

    QString message;
    if (action == QLatin1String("click_red"))
        message = QStringLiteral("已喜欢，后续会多推荐类似歌曲");
    else if (action == QLatin1String("garbage"))
        message = dataObj["tooltip"].toString().isEmpty()
                      ? QStringLiteral("已优化后续推荐")
                      : dataObj["tooltip"].toString();
    else if (action == QLatin1String("black_singer"))
        message = QStringLiteral("已屏蔽该歌手，后续不再推荐");

    // 不喜欢 / 屏蔽歌手返回的是后续推荐，直接补进当前 FM 队列
    if (m_queueMode && action != QLatin1String("click_red"))
    {
        const QVariantList batch = parseSongs(dataObj["song_list"].toArray());
        if (!batch.isEmpty())
        {
            appendToQueue(batch);
            beginCoverFetch(batch);
        }
    }

    if (!message.isEmpty())
        emit notice(message);
}

void PersonalFM::beginCoverFetch(const QVariantList &songs)
{
    QMap<QString, QStringList> byAlbum;
    for (const QVariant &v : songs)
    {
        const QVariantMap item = v.toMap();
        if (!item["union_cover"].toString().isEmpty())
            continue;
        const QString albumId = item["album_id"].toString();
        const QString hash = item["songhash"].toString();
        if (albumId.isEmpty() || hash.isEmpty())
            continue;
        byAlbum[albumId].append(hash);
    }

    for (auto it = byAlbum.constBegin(); it != byAlbum.constEnd(); ++it)
    {
        QVariantMap task;
        task["albumId"] = it.key();
        task["hashes"] = it.value();
        m_coverQueue.append(task);
    }

    if (!m_coverFetching)
        requestNextCover();
}

void PersonalFM::requestNextCover()
{
    if (m_coverFetching)
        return;
    if (m_coverCursor >= m_coverQueue.size())
    {
        m_coverQueue.clear();
        m_coverCursor = 0;
        return;
    }
    m_coverFetching = true;
    const QVariantMap task = m_coverQueue[m_coverCursor].toMap();
    const QString url = QString("https://api.special520.com/album/songs?id=%1").arg(task["albumId"].toString());
    m_coverRequester.fetchData(url);
}

void PersonalFM::updateCoverForHashes(const QStringList &hashes, const QString &cover)
{
    if (hashes.isEmpty() || cover.isEmpty())
        return;

    bool changed = false;
    QSet<QString> wanted;
    for (const QString &hash : hashes)
        wanted.insert(hash);

    for (QVariant &v : m_songs)
    {
        QVariantMap item = v.toMap();
        if (wanted.contains(item["songhash"].toString()))
        {
            item["union_cover"] = cover;
            v = item;
            changed = true;
        }
    }
    for (QVariant &v : m_queue)
    {
        QVariantMap item = v.toMap();
        if (wanted.contains(item["songhash"].toString()))
        {
            item["union_cover"] = cover;
            v = item;
            changed = true;
        }
    }

    if (changed)
    {
        emit songsChanged();
        emit queueChanged();
    }
}

void PersonalFM::onCoverData(const QByteArray &data)
{
    QString cover;
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error == QJsonParseError::NoError)
    {
        const QJsonArray songs = doc.object()["data"].toObject()["songs"].toArray();
        if (!songs.isEmpty())
            cover = songs.first().toObject()["album_info"].toObject()["cover"].toString();
    }
    if (!cover.isEmpty())
    {
        cover.replace("{size}", "400");
        const QVariantMap task = m_coverQueue[m_coverCursor].toMap();
        updateCoverForHashes(task["hashes"].toStringList(), cover);
    }
    m_coverFetching = false;
    m_coverCursor++;
    requestNextCover();
}

void PersonalFM::onCoverFailed(const QString &err)
{
    if (!err.isEmpty())
        qWarning() << "[PersonalFM] cover fetch error:" << err;
    m_coverFetching = false;
    m_coverCursor++;
    requestNextCover();
}
