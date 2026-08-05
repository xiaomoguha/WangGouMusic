#ifndef SONGCOMMENTS_H
#define SONGCOMMENTS_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

/**
 * @brief 歌曲评论（/api/comment/music + /api/comment/count）。
 *
 * 评论接口需要 mixsongid（歌名搜索结果的 album_audio_id），播放队列只存 hash，
 * 因此先按歌名搜索、用 hash 精确匹配解析 mixsongid（同歌缓存复用），再拉评论分页。
 * 评论总数按 hash 单独请求，与列表并行。
 */
class SongComments : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList comments READ comments NOTIFY commentsChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY commentsChanged)
    // 展开某条评论的回复列表（repliesCommentId = 回复所属的评论 id）
    Q_PROPERTY(QVariantList replies READ replies NOTIFY repliesChanged)
    Q_PROPERTY(QString repliesCommentId READ repliesCommentId NOTIFY repliesChanged)
    Q_PROPERTY(bool repliesLoading READ repliesLoading NOTIFY repliesLoadingChanged)

public:
    explicit SongComments(QObject *parent = nullptr);

    QVariantList comments() const { return m_comments; }
    int totalCount() const { return m_totalCount; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }
    QVariantList replies() const { return m_replies; }
    QString repliesCommentId() const { return m_repliesCommentId; }
    bool repliesLoading() const { return m_repliesLoading; }

    /// 拉取指定歌曲评论：内部解析 mixsongid → 拉第一页（总数取列表响应里的 count）。
    /// 返回是否真正发起（正在加载中会拒绝并发请求）
    Q_INVOKABLE bool fetchComments(const QString &title, const QString &hash);
    /// 加载下一页评论（hasMore 时）
    Q_INVOKABLE void fetchMore();
    /// 展开某条评论的回复：audioId=评论里的 special_child_id（歌曲 audio_id），
    /// commentId=评论 id；mixsongid 用内部已解析值
    Q_INVOKABLE void fetchReplies(const QString &audioId, const QString &commentId);

signals:
    void commentsChanged();
    void totalCountChanged();
    void isLoadingChanged();
    void repliesChanged();
    void repliesLoadingChanged();

private slots:
    void onSearchData(const QByteArray &data);
    void onCommentsData(const QByteArray &data);
    void onRepliesData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    void requestComments(const QString &mixsongid, int page);

    HttpGetRequester m_searchRequester;
    HttpGetRequester m_requester;
    HttpGetRequester m_repliesRequester;

    QVariantList m_comments;
    QVariantList m_replies;
    QString m_repliesCommentId;   // 当前回复列表所属的评论 id
    bool m_repliesLoading = false;
    int m_totalCount = 0;
    int m_page = 0;
    bool m_hasMore = false;
    bool m_isLoading = false;

    QString m_title;
    QString m_hash;
    QString m_mixsongid;      // 已解析的 mixsongid
    QString m_mixsongidHash;  // 该 mixsongid 对应的歌曲 hash（缓存判断）
};

#endif // SONGCOMMENTS_H
