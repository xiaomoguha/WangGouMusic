#ifndef DISCOVERMANAGER_H
#define DISCOVERMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

/**
 * @brief 歌单发现页数据源。
 *
 * 分类标签：GET /playlist/tags（data[] 顶层 parent 一级分类，如场景/语种/风格）。
 * 歌单列表：GET /top/playlist?category_id=&page=&pagesize=30（data.special_list[]，
 * has_next 翻页，字段与首页精选歌单同源，见 Recommendation::onTopPlaylistsData）。
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
    /// 切换分类：清空已有歌单重新拉第一页
    Q_INVOKABLE void fetchPlaylists(const QString &categoryId);
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
    QString m_categoryId;
    int m_page      = 0;
    bool m_hasMore  = true;
    bool m_isLoading = false;
};

#endif // DISCOVERMANAGER_H
