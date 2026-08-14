#include "airecommendmanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>

namespace
{
const char *const kApiRoot = "https://api.special520.com";

QString secondsToMinutesSeconds(int seconds)
{
    if (seconds <= 0)
        return QString();
    const int m = seconds / 60;
    const int s = seconds % 60;
    return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
}
} // namespace

AiRecommendManager::AiRecommendManager(QObject *parent) : QObject(parent)
{
    connect(&m_searchRequester, &HttpGetRequester::dataReceived, this, [this](const QByteArray &data) {
        // 搜索响应：按 hash 匹配 album_audio_id 作为推荐种子
        QJsonParseError perr;
        const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
        QString mxid;
        if (perr.error == QJsonParseError::NoError && doc.isObject())
        {
            const QJsonArray songs = doc.object()["data"].toObject()["info"].toArray();
            for (const QJsonValue &val : songs)
            {
                const QJsonObject s  = val.toObject();
                const QString    h   = s["hash"].toString().toUpper();
                const int        aid = s["album_audio_id"].toInt();
                if (aid <= 0)
                    continue;
                if (h == m_seedHash)
                {
                    mxid = QString::number(aid);
                    break;
                }
            }
        }
        if (mxid.isEmpty())
        {
            qWarning() << "[AiRecommend] 搜索未匹配到种子歌曲 mxid";
            fail(QStringLiteral("未找到该歌曲"));
            return;
        }
        requestRecommend(mxid);
    });

    connect(&m_recommendRequester, &HttpGetRequester::dataReceived, this, [this](const QByteArray &data) {
        parseRecommend(data);
    });

    const auto failSlot    = [this](const QString &err) { fail(err); };
    const auto timeoutSlot = [this]() { fail(QStringLiteral("timeout")); };
    connect(&m_searchRequester, &HttpGetRequester::requestFailed, this, failSlot);
    connect(&m_searchRequester, &HttpGetRequester::requestTimeout, this, timeoutSlot);
    connect(&m_recommendRequester, &HttpGetRequester::requestFailed, this, failSlot);
    connect(&m_recommendRequester, &HttpGetRequester::requestTimeout, this, timeoutSlot);
}

void AiRecommendManager::recommend(const QString &songhash, const QString &songname)
{
    if (songhash.isEmpty() || songname.isEmpty())
        return;
    if (m_busy)
    {
        // 单飞：当前生成未完成时记下请求，完成后接续（最后点击的优先）
        m_pendingHash = songhash.toUpper();
        m_pendingName = songname;
        return;
    }
    startFlow(songhash, songname);
}

void AiRecommendManager::startFlow(const QString &songhash, const QString &songname)
{
    setBusy(true);
    m_seedHash = songhash.toUpper();

    // 酷狗搜索接口支持 album_audio_id 解析：按歌名搜，再按 hash 精确匹配
    QString keyword = songname;
    keyword.replace(QRegularExpression(QStringLiteral(R"(\s*\([^)]*\)\s*$)")), QString());
    QUrl url(QStringLiteral("%1/search").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("keywords", keyword);
    query.addQueryItem("page", "1");
    query.addQueryItem("pagesize", "10");
    url.setQuery(query);
    m_searchRequester.fetchData(url.toString());
}

void AiRecommendManager::drainPending()
{
    if (m_pendingHash.isEmpty())
        return;
    const QString hash = m_pendingHash;
    const QString name = m_pendingName;
    m_pendingHash.clear();
    m_pendingName.clear();
    startFlow(hash, name);
}

void AiRecommendManager::requestRecommend(const QString &mxid)
{
    QUrl url(QStringLiteral("%1/ai/recommend").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("album_audio_id", mxid);
    url.setQuery(query);
    m_recommendRequester.fetchData(url.toString());
}

void AiRecommendManager::parseRecommend(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[AiRecommend] 响应解析失败:" << perr.errorString();
        fail(QStringLiteral("响应解析失败"));
        return;
    }

    const QJsonArray list = doc.object()["data"].toObject()["song_list"].toArray();
    QVariantList songs;
    for (const QJsonValue &val : list)
    {
        const QJsonObject o = val.toObject();
        // 歌手取 singerinfo 第一个
        QString singer;
        const QJsonArray infos = o["singerinfo"].toArray();
        if (!infos.isEmpty())
            singer = infos.first().toObject()["name"].toString();
        // 封面嵌在 relate_goods[0].trans_param.union_cover（带 {size} 占位）
        QString cover;
        const QJsonArray goods = o["relate_goods"].toArray();
        if (!goods.isEmpty())
            cover = goods.first().toObject()["trans_param"].toObject()["union_cover"].toString()
                        .replace(QStringLiteral("{size}"), QStringLiteral("200"));

        QVariantMap s;
        s["songname"]    = o["songname"].toString();
        s["songhash"]    = o["hash"].toString();
        s["singername"]  = singer;
        s["album_name"]  = QString();
        s["duration"]    = secondsToMinutesSeconds(o["time_length"].toInt());
        s["union_cover"] = cover;
        if (s["songhash"].toString().isEmpty())
            continue;
        songs.append(s);
    }

    setBusy(false);
    if (songs.isEmpty())
    {
        qWarning() << "[AiRecommend] 推荐列表为空";
        fail(QStringLiteral("推荐结果为空"));
        return;
    }
    qDebug() << "[AiRecommend] 生成" << songs.size() << "首";
    emit recommendDone(m_seedHash, songs);
    drainPending();
}

void AiRecommendManager::fail(const QString &reason)
{
    setBusy(false);
    emit recommendFailed(m_seedHash, reason);
    drainPending();
}

bool AiRecommendManager::busy() const
{
    return m_busy;
}

void AiRecommendManager::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
