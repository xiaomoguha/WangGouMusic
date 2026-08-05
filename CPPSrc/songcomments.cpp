#include "songcomments.h"

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
const char *const kApiRoot = "https://xjt-togethertracks.top/api";
}

SongComments::SongComments(QObject *parent) : QObject(parent)
{
    connect(&m_searchRequester, &HttpGetRequester::dataReceived, this, &SongComments::onSearchData);
    connect(&m_requester, &HttpGetRequester::dataReceived, this, &SongComments::onCommentsData);
    connect(&m_repliesRequester, &HttpGetRequester::dataReceived, this, &SongComments::onRepliesData);

    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_searchRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_searchRequester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_requester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_requester, &HttpGetRequester::requestTimeout, this, timeout);
    connect(&m_repliesRequester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_repliesRequester, &HttpGetRequester::requestTimeout, this, timeout);
}

bool SongComments::fetchComments(const QString &title, const QString &hash)
{
    if (title.isEmpty() || hash.isEmpty() || m_isLoading)
        return false;
    m_isLoading = true;
    emit isLoadingChanged();

    m_title = title;
    m_hash  = hash.toUpper();
    m_page  = 0;
    m_comments.clear();
    m_hasMore = false;
    emit commentsChanged();

    // 同一首歌已解析过 mixsongid → 跳过搜索直接拉
    if (m_mixsongidHash == m_hash && !m_mixsongid.isEmpty())
    {
        requestComments(m_mixsongid, 1);
        return true;
    }

    // 按歌名搜索 → hash 精确匹配拿 album_audio_id（即 mixsongid）。
    // 去掉结尾的 "(Explicit)" 等括号注释，提高命中率
    QString keyword = title;
    keyword.replace(QRegularExpression(QStringLiteral(R"(\s*\([^)]*\)\s*$)")), QString());
    QUrl url(QStringLiteral("%1/search").arg(kApiRoot));
    QUrlQuery query;
    query.addQueryItem("keywords", keyword);
    query.addQueryItem("page", "1");
    query.addQueryItem("pagesize", "10");
    url.setQuery(query);
    m_searchRequester.fetchData(url.toString());
    return true;
}

void SongComments::fetchMore()
{
    if (!m_hasMore || m_isLoading)
        return;
    requestComments(m_mixsongid, m_page + 1);
}

void SongComments::fetchReplies(const QString &audioId, const QString &commentId)
{
    if (m_mixsongid.isEmpty() || audioId.isEmpty() || commentId.isEmpty())
        return;
    if (m_repliesCommentId == commentId && !m_repliesLoading)
        return; // 已展开过同一评论
    m_repliesCommentId = commentId;
    m_repliesLoading   = true;
    emit repliesLoadingChanged();
    const QString url =
        QStringLiteral("%1/comment/floor?mixsongid=%2&special_id=%3&tid=%4&page=1&pagesize=10")
            .arg(kApiRoot, m_mixsongid, audioId, commentId);
    m_repliesRequester.fetchData(url);
}

void SongComments::requestComments(const QString &mixsongid, int page)
{
    m_page = page;
    m_requester.fetchData(QStringLiteral("%1/comment/music?mixsongid=%2&page=%3&pagesize=30")
                              .arg(kApiRoot, mixsongid).arg(page));
}

void SongComments::onSearchData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonArray songs = doc.object()["data"].toObject()["info"].toArray();

    QString mixsongid;
    for (const QJsonValue &val : songs)
    {
        const QJsonObject s  = val.toObject();
        const QString    h   = s["hash"].toString().toUpper();
        const QString    aid = QString::number(s["album_audio_id"].toInt());
        if (aid.isEmpty() || aid == QLatin1String("0"))
            continue;
        if (h == m_hash)
        {
            mixsongid = aid;
            break;
        }
        if (mixsongid.isEmpty())
            mixsongid = aid; // 兜底：首条结果
    }
    if (mixsongid.isEmpty())
    {
        qWarning() << "[SongComments] mixsongid 解析失败, title:" << m_title;
        onFailed(QStringLiteral("no mixsongid"));
        return;
    }
    m_mixsongid     = mixsongid;
    m_mixsongidHash = m_hash;
    requestComments(mixsongid, 1);
}

void SongComments::onCommentsData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        onFailed(perr.errorString());
        return;
    }
    const QJsonObject root  = doc.object();
    const QJsonArray  list  = root["list"].toArray();
    // 评论总数以列表响应为准（comment/count 接口数值偏差大，弃用）
    const int         count = root["count"].toInt(0);
    const int         maxPage = root["maxPage"].toInt(1);
    if (count > 0 && count != m_totalCount)
    {
        m_totalCount = count;
        emit totalCountChanged();
    }

    for (const QJsonValue &val : list)
    {
        const QJsonObject o = val.toObject();
        QVariantMap c;
        c["content"]    = o["content"].toString();
        c["user_name"]  = o["user_name"].toString();
        c["user_pic"]   = o["user_pic"].toString();
        c["addtime"]    = o["addtime"].toString();
        c["reply_num"]  = o["reply_num"].toInt();
        c["like_count"] = o["like"].toObject()["count"].toInt();
        // 展开回复用：评论 id（响应里是数字，toString() 对数字返回空 → 用 toInt）+
        // 歌曲 audio_id（响应里是字符串，comment/floor 的 childrenid）
        c["id"]       = o["id"].toInt();
        c["audio_id"] = o["special_child_id"].toString();
        m_comments.append(c);
    }
    m_hasMore = m_page < maxPage && !list.isEmpty();
    m_isLoading = false;
    emit commentsChanged();
    emit isLoadingChanged();
    qDebug() << "[SongComments] 评论加载完成, 共" << m_comments.size() << "条 / 总数" << count;
}

void SongComments::onRepliesData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    m_repliesLoading = false;
    emit repliesLoadingChanged();
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return;
    const QJsonArray list = doc.object()["list"].toArray();
    QVariantList replies;
    for (const QJsonValue &val : list)
    {
        const QJsonObject o = val.toObject();
        QVariantMap r;
        r["content"]    = o["content"].toString();
        r["user_name"]  = o["user_name"].toString();
        r["user_pic"]   = o["user_pic"].toString();
        r["addtime"]    = o["addtime"].toString();
        r["like_count"] = o["like"].toObject()["count"].toInt();
        replies.append(r);
    }
    m_replies = replies;
    emit repliesChanged();
    qDebug() << "[SongComments] 回复加载完成, comment:" << m_repliesCommentId << "共" << replies.size() << "条";
}

void SongComments::onFailed(const QString &err)
{
    qWarning() << "[SongComments] request error:" << err;
    if (m_isLoading)
    {
        m_isLoading = false;
        emit isLoadingChanged();
    }
}
