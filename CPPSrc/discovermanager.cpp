#include "discovermanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>

namespace
{
const char *const kApiRoot = "https://xjt-togethertracks.top/api";
} // namespace

DiscoverManager::DiscoverManager(QObject *parent) : QObject(parent)
{
    connect(&m_tagsRequester, &HttpGetRequester::dataReceived, this, &DiscoverManager::onTagsData);
    connect(&m_playlistsRequester, &HttpGetRequester::dataReceived, this, &DiscoverManager::onPlaylistsData);
    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_tagsRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_tagsRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_playlistsRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_playlistsRequester, &HttpGetRequester::requestTimeout, this, timeout);
}

void DiscoverManager::fetchTags()
{
    m_tagsRequester.fetchData(QStringLiteral("%1/playlist/tags").arg(kApiRoot));
}

void DiscoverManager::fetchPlaylists(const QString &categoryId)
{
    if (m_isLoading)
        return;
    m_categoryId = categoryId;
    m_page       = 0;
    m_hasMore    = true;
    m_playlists.clear();
    emit playlistsChanged();
    fetchMorePlaylists();
}

void DiscoverManager::fetchMorePlaylists()
{
    if (m_isLoading || !m_hasMore)
        return;
    m_isLoading = true;
    emit isLoadingChanged();
    // category_id=0 传空即可（服务端默认全部）
    const QString url = QStringLiteral("%1/top/playlist?pagesize=30&page=%2%3")
                            .arg(kApiRoot)
                            .arg(m_page + 1)
                            .arg(m_categoryId.isEmpty() || m_categoryId == QLatin1String("0")
                                     ? QString()
                                     : QStringLiteral("&category_id=%1").arg(m_categoryId));
    m_playlistsRequester.fetchData(url);
}

void DiscoverManager::onTagsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[DiscoverManager] tags parse error:" << perr.errorString();
        return;
    }
    QVariantList tags;
    const QJsonArray arr = doc.object()["data"].toArray();
    for (const QJsonValue &v : arr)
    {
        const QJsonObject o = v.toObject();
        // 只取一级分类（parent_id == "0"）；若接口无该字段则全部取
        const QString parentId = o["parent_id"].toString();
        if (!parentId.isEmpty() && parentId != QLatin1String("0"))
            continue;
        QVariantMap t;
        t["tag_id"]   = o["tag_id"].toString();
        t["tag_name"] = o["tag_name"].toString();
        if (!t["tag_id"].toString().isEmpty())
            tags.append(t);
    }
    // 一级分类过滤后为空（部分分类层级标记不同）时兜底全量展示
    if (tags.isEmpty())
    {
        for (const QJsonValue &v : arr)
        {
            const QJsonObject o = v.toObject();
            QVariantMap t;
            t["tag_id"]   = o["tag_id"].toString();
            t["tag_name"] = o["tag_name"].toString();
            if (!t["tag_id"].toString().isEmpty())
                tags.append(t);
        }
    }
    m_tags = tags;
    emit tagsChanged();
}

void DiscoverManager::onPlaylistsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[DiscoverManager] playlists parse error:" << perr.errorString();
        m_isLoading = false;
        emit isLoadingChanged();
        return;
    }
    const QJsonObject dataObj = doc.object()["data"].toObject();
    const QJsonArray list     = dataObj["special_list"].toArray();

    QVariantList parsed;
    for (const QJsonValue &v : list)
    {
        const QJsonObject pl = v.toObject();
        QString imgurl       = pl["imgurl"].toString();
        imgurl.replace(QStringLiteral("{size}"), QStringLiteral("400"));
        QVariantMap item;
        item["specialname"]          = pl["specialname"].toString();
        item["imgurl"]               = imgurl;
        item["intro"]                = pl["intro"].toString();
        item["play_count"]           = pl["play_count"].toInt();
        item["global_collection_id"] = pl["global_collection_id"].toString();
        item["nickname"]             = pl["nickname"].toString();
        parsed.append(item);
    }
    // 接口偶发空列表：保留现有数据，避免页面闪空
    if (!parsed.isEmpty())
    {
        const bool isReset = m_page == 0;  // 第一页 = 切分类后的重置；否则是追加
        m_playlists.append(parsed);
        m_hasMore = dataObj["has_next"].toInt() > 0;
        m_page++;
        if (isReset)
            emit playlistsReset(parsed);
        else
            emit playlistsAppended(parsed);
    }
    m_isLoading = false;
    emit isLoadingChanged();
    emit playlistsChanged();
}

void DiscoverManager::onFailed(const QString &err)
{
    qWarning() << "[DiscoverManager] request error:" << err;
    m_isLoading = false;
    emit isLoadingChanged();
}
