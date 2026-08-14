#include "discovermanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>

namespace
{
const char *const kApiRoot = "https://api.special520.com";
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

void DiscoverManager::fetchPlaylists(const QString &keyword)
{
    if (m_isLoading)
        return;
    m_keyword = keyword;
    m_session.clear(); // 切分类/切回全部：游标重置，从第一页重新拉
    m_total   = 0;
    m_page    = 0;
    m_hasMore = true;
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
    // 全部：top/playlist（sort=2 与首页推荐 sort=1 区分，避免两页内容重复；session 游标翻页）；
    // 分类：playlist/category 按分类名搜索（酷狗无按分类 id 取歌单接口）
    const QString url = m_keyword.isEmpty()
                            ? QStringLiteral("%1/top/playlist?pagesize=30&page=%2&sort=2%3")
                                  .arg(kApiRoot)
                                  .arg(m_page + 1)
                                  .arg(m_session.isEmpty()
                                           ? QString()
                                           : QStringLiteral("&session=%1").arg(m_session))
                            : QStringLiteral("%1/playlist/category?pagesize=30&page=%2&keyword=%3")
                                  .arg(kApiRoot)
                                  .arg(m_page + 1)
                                  .arg(QUrl::toPercentEncoding(m_keyword));
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
    // mobilecdnbj 歌单搜索响应带 <!--KG_TAG_RES_START--> 前缀和 <!--KG_TAG_RES_END--> 后缀，
    // 截取首个 '{' 到最后一个 '}' 之间才是纯 JSON
    const int jsonStart = data.indexOf('{');
    const int jsonEnd   = data.lastIndexOf('}');
    const QByteArray body =
        jsonStart >= 0 && jsonEnd > jsonStart ? data.mid(jsonStart, jsonEnd - jsonStart + 1) : data;
    const QJsonDocument doc = QJsonDocument::fromJson(body, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[DiscoverManager] playlists parse error:" << perr.errorString();
        m_isLoading = false;
        emit isLoadingChanged();
        return;
    }
    const QJsonObject dataObj = doc.object()["data"].toObject();
    // 翻页游标：下一页请求必须带上（top/playlist 无游标时永远返回第一页）
    m_session = dataObj["session"].toString(m_session);
    m_total   = dataObj["total"].toInt(m_total);
    // 全部：special_list[]；分类搜索：info[]（字段名与 special_list 不同）
    QJsonArray list;
    if (dataObj.contains("special_list") && dataObj["special_list"].isArray())
        list = dataObj["special_list"].toArray();
    else if (dataObj.contains("info"))
        list = dataObj["info"].toArray();

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
        item["play_count"]           = pl["playcount"].toInt(pl["play_count"].toInt());
        // 分类搜索无 global_collection_id，用 gid（collection_3_xxx 格式）或 specialid 兜底
        item["global_collection_id"] = pl["global_collection_id"].toString(
            pl["gid"].toString(pl["specialid"].toString()));
        item["nickname"]             = pl["nickname"].toString();
        parsed.append(item);
    }
    // 接口偶发空列表：保留现有数据，避免页面闪空
    if (!parsed.isEmpty())
    {
        const bool isReset = m_page == 0;  // 第一页 = 切分类后的重置；否则是追加
        m_playlists.append(parsed);
        // 全部：has_next；分类搜索：无该字段，用 total 推算（已加载 < 总数则还有下一页）
        m_hasMore = dataObj.contains("has_next") ? dataObj["has_next"].toInt() > 0
                                                 : m_playlists.size() < m_total;
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
