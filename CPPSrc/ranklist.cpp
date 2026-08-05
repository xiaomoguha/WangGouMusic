#include "ranklist.h"
#include "recommendation.h" // secondsToMinutesSeconds

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRandomGenerator>

namespace
{
const char *const kApiRoot = "https://xjt-togethertracks.top/api";
}

RankList::RankList(QObject *parent) : QObject(parent)
{
    connect(&m_ranksRequester, &HttpGetRequester::dataReceived, this, &RankList::onRanksData);
    connect(&m_infoRequester, &HttpGetRequester::dataReceived, this, &RankList::onInfoData);
    connect(&m_songsRequester, &HttpGetRequester::dataReceived, this, &RankList::onSongsData);

    const auto failHandler = [this](const QString &err) { onRequestFailed(err); };
    const auto timeoutHandler = [this]() { onRequestFailed(QStringLiteral("timeout")); };
    connect(&m_ranksRequester, &HttpGetRequester::requestFailed, this, failHandler);
    connect(&m_ranksRequester, &HttpGetRequester::requestTimeout, this, timeoutHandler);
    connect(&m_infoRequester, &HttpGetRequester::requestFailed, this, failHandler);
    connect(&m_infoRequester, &HttpGetRequester::requestTimeout, this, timeoutHandler);
    connect(&m_songsRequester, &HttpGetRequester::requestFailed, this, failHandler);
    connect(&m_songsRequester, &HttpGetRequester::requestTimeout, this, timeoutHandler);
}

void RankList::setLoading(bool loading)
{
    if (m_isLoading == loading)
        return;
    m_isLoading = loading;
    emit isLoadingChanged();
}

void RankList::onRequestFailed(const QString &err)
{
    qWarning() << "[RankList] request error:" << err;
    m_pendingRandom = false;
    m_pendingRandomFetch = false;
    setLoading(false);
}

void RankList::fetchRanks()
{
    m_ranksRequester.fetchData(QString("%1/rank/list").arg(kApiRoot));
}

void RankList::fetchRankSongs(const QString &rankid)
{
    if (rankid.isEmpty() || m_isLoading)
        return;
    m_currentRankId = rankid;
    setLoading(true);
    m_infoRequester.fetchData(QString("%1/rank/info?rankid=%2").arg(kApiRoot, rankid));
}

void RankList::fetchRandomRankSongs()
{
    m_pendingRandom = true;
    if (m_ranks.isEmpty())
    {
        // 榜单列表还没拉过：先拉列表，成功后再随机续接
        m_pendingRandomFetch = true;
        fetchRanks();
    }
    else
    {
        const QVariantMap rank = m_ranks[QRandomGenerator::global()->bounded(m_ranks.size())].toMap();
        fetchRankSongs(rank["rankid"].toString());
    }
}

void RankList::onRanksData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[RankList] rank list parse error:" << perr.errorString();
        onRequestFailed(perr.errorString());
        return;
    }
    const QJsonArray info = doc.object()["data"].toObject()["info"].toArray();
    QVariantList ranks;
    for (const QJsonValue &val : info)
    {
        const QJsonObject r = val.toObject();
        // rankid 在响应里是数字（8888），toString() 对数字返回空串 → 必须用 toInt 读
        const QString rankid = QString::number(r["rankid"].toInt());
        const QString name   = r["rankname"].toString();
        if (rankid.isEmpty() || name.isEmpty())
            continue;
        QString img = r["img_9"].toString();
        if (img.isEmpty())
            img = r["album_img_9"].toString();
        img.replace("{size}", "400");

        QVariantMap item;
        item["rankid"]   = rankid;
        item["rankname"] = name;
        item["imgurl"]   = img;
        ranks.append(item);
    }
    if (ranks.isEmpty())
    {
        qWarning() << "[RankList] rank list empty";
        onRequestFailed("empty");
        return;
    }
    m_ranks = ranks;
    emit ranksChanged();
    qDebug() << "[RankList] 榜单列表加载完成，共" << m_ranks.size() << "个";

    // 随机模式的等待链：榜单已就绪 → 随机挑一个续接
    if (m_pendingRandomFetch)
    {
        m_pendingRandomFetch = false;
        const QVariantMap rank = m_ranks[QRandomGenerator::global()->bounded(m_ranks.size())].toMap();
        fetchRankSongs(rank["rankid"].toString());
    }
}

void RankList::onInfoData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[RankList] rank info parse error:" << perr.errorString();
        onRequestFailed(perr.errorString());
        return;
    }
    const QJsonObject info = doc.object()["data"].toObject();
    m_rankName = info["rankname"].toString();
    // 封面：banner 优先，退回 logo
    m_rankCover = info["banner_9"].toString();
    if (m_rankCover.isEmpty())
        m_rankCover = info["custom_logo"].toString();
    m_rankCover.replace("{size}", "400");
    emit rankInfoChanged();

    m_songsRequester.fetchData(QString("%1/rank/audio?rankid=%2&pagesize=100").arg(kApiRoot, m_currentRankId));
}

void RankList::onSongsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[RankList] rank songs parse error:" << perr.errorString();
        onRequestFailed(perr.errorString());
        return;
    }
    const QJsonArray list = doc.object()["data"].toObject()["songlist"].toArray();
    QVariantList songs;
    for (const QJsonValue &val : list)
    {
        const QJsonObject s   = val.toObject();
        const QString    name = s["songname"].toString();
        const QJsonObject audioInfo = s["audio_info"].toObject();
        // 该接口无顶层 hash，可播 hash 在 audio_info 里（128 优先，依次降级）
        const QString hash = audioInfo["hash_128"].toString().isEmpty()
                                 ? audioInfo["hash_high"].toString()
                                 : audioInfo["hash_128"].toString();
        if (name.isEmpty() || hash.isEmpty())
            continue;

        QStringList singers;
        const QJsonArray authors = s["authors"].toArray();
        for (const QJsonValue &a : authors)
            singers << a.toObject()["author_name"].toString();

        QString cover = s["trans_param"].toObject()["union_cover"].toString();
        if (cover.isEmpty())
            cover = s["album_info"].toObject()["sizable_cover"].toString();
        cover.replace("{size}", "400");

        QVariantMap item;
        item["songname"]    = name;
        item["songhash"]    = hash;
        item["singername"]  = singers.join(", ");
        item["union_cover"] = cover;
        item["album_name"]  = s["album_info"].toObject()["album_name"].toString();
        // duration_128 毫秒 → mm:ss；缺失时留空由 UI 兜底 "--:--"
        item["duration"]    = Recommendation::secondsToMinutesSeconds(audioInfo["duration_128"].toInt(0) / 1000);
        songs.append(item);
    }
    if (songs.isEmpty())
    {
        qWarning() << "[RankList] rank songs empty";
        onRequestFailed("empty");
        return;
    }
    m_songs = songs;
    emit songsChanged();
    qDebug() << "[RankList] 榜单歌曲加载完成，共" << m_songs.size() << "首";

    const bool randomMode = m_pendingRandom;
    m_pendingRandom = false;
    setLoading(false);
    if (randomMode)
        emit randomSongsReady(m_songs);
}
