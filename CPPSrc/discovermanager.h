#ifndef DISCOVERMANAGER_H
#define DISCOVERMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

/**
 * @brief 歌单发现页数据源。
 *
 * 分类标签：GET /playlist/tags（data[] 顶层 parent 一级分类，如场景/语种/风格）。
 * 歌单列表：
 *  - 全部：GET /top/playlist?category_id=&page=&pagesize=30（data.special_list[]，has_next 翻页）
 *  - 分类：GET /playlist/category?keyword={分类名}（服务端转发 mobilecdnbj 歌单搜索，
 *    酷狗无按分类 id 取歌单的可用接口，官方做法即按分类名搜索，data.info[]，has_next 翻页）
 */
class DiscoverManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList tagsQml READ tagsQml NOTIFY tagsChanged)
    Q_PROPERTY(QVariantList playlistsQml READ playlistsQml NOTIFY playlistsChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY playlistsChanged)

public:
    explicit DiscoverManager(QObject *parent = nullptr);

    QVariantList tagsQml() const { return m_tags; }
    QVariantList playlistsQml() const { return m_playlists; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }

    Q_INVOKABLE void fetchTags();
    /// 切换分类：清空已有歌单重新拉第一页（keyword 空 = 全部，非空 = 按分类名搜索）
    Q_INVOKABLE void fetchPlaylists(const QString &keyword);
    /// 下拉加载更多：同一分类翻下一页
    Q_INVOKABLE void fetchMorePlaylists();

signals:
    void tagsChanged();
    void playlistsChanged();
    void isLoadingChanged();
    void playlistsReset(const QVariantList &songs);   // 切分类：清空 + 填充第一页
    void playlistsAppended(const QVariantList &songs); // 下拉加载：追加新页（ListView 不弹跳）

private slots:
    void onTagsData(const QByteArray &data);
    void onPlaylistsData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    HttpGetRequester m_tagsRequester;
    HttpGetRequester m_playlistsRequester;

    QVariantList m_tags;
    QVariantList m_playlists;
    QString m_keyword;
    QString m_session; // 酷狗特殊推荐翻页游标（返回的 session 传给下一页，不传则永远第一页）
    int m_total = 0;   // 分类搜索总结果数（搜索接口无 has_next，用 total 推算是否还有下一页）
    int m_page      = 0;
    bool m_hasMore  = true;
    bool m_isLoading = false;
};

#endif // DISCOVERMANAGER_H
