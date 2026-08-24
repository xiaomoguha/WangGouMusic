#ifndef RECOMMENDATION_H
#define RECOMMENDATION_H
#include "HttpGetRequester.h"
#include "models/SongListModel.h"
#include <QObject>
#include <functional>
class Recommendation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList topSongsQml READ getTopSongsQml NOTIFY topSongsChanged)
    Q_PROPERTY(QVariantList topPlaylistsQml READ getTopPlaylistsQml NOTIFY topPlaylistsChanged)
    // 歌单歌曲列表用 QAbstractListModel：增量插入只通知变化行，下拉加载更多不弹顶
    // （QVariantList + NOTIFY 每次整体替换 model，ListView 会重置滚动位置）
    Q_PROPERTY(QObject* playlistTracksModel READ playlistTracksModel CONSTANT)
    Q_PROPERTY(int playlistTotal READ playlistTotal NOTIFY playlistTracksChanged)
    Q_PROPERTY(bool playlistHasMore READ playlistHasMore NOTIFY playlistTracksChanged)
    Q_PROPERTY(bool playlistIsLoading READ playlistIsLoading NOTIFY playlistIsLoadingChanged)
    // 精选歌单请求中（首页「换一批」按钮的旋转时长）
    Q_PROPERTY(bool playlistsLoading READ playlistsLoading NOTIFY playlistsLoadingChanged)

public:
    explicit Recommendation(QObject *parent = nullptr);

    Q_INVOKABLE void fetchTopSongs();
    Q_INVOKABLE void fetchTopPlaylists();
    Q_INVOKABLE void refreshTopPlaylists();
    // 首页「热门推荐换一批」：外部（RankList.randomSongsReady）把随机榜单歌曲注入推荐区
    Q_INVOKABLE void showRankSongs(const QVariantList &songs);
    Q_INVOKABLE void fetchPlaylistTracks(const QString &globalCollectionId);
    Q_INVOKABLE void fetchMorePlaylistTracks();
    Q_INVOKABLE void loadAllPlaylistTracks();
    /// 手动刷新：全量重拉（page 1 起自动连拉到歌单尽头），缓存随每页写穿
    Q_INVOKABLE void refreshPlaylistTracks(const QString &globalCollectionId);
    /// 进页面缓存优先：读到 playlist_<gid>.json 即填充模型并返回 true（无需走网络）
    Q_INVOKABLE bool loadCachedPlaylistTracks(const QString &globalCollectionId);
    // C++ 内部用：按页拉取指定歌单歌曲，结果通过 callback 返回（QVariantList，每项含
    // songname/songhash/singername/union_cover/album_name/duration）
    void fetchPlaylistTracksPage(
        const QString &id, int page, int pagesize, std::function<void(const QVariantList &)> callback
    );

    QVariantList getTopSongsQml() const;
    QVariantList getTopPlaylistsQml() const;
    SongListModel *playlistTracksModel() const
    {
        return m_playlistTracksModel;
    }
    int playlistTotal() const
    {
        return m_playlistTotal;
    }
    bool playlistHasMore() const
    {
        return m_playlistHasMore;
    }
    bool playlistIsLoading() const
    {
        return m_playlistIsLoading;
    }
    bool playlistsLoading() const
    {
        return m_playlistsLoading;
    }

    static QString secondsToMinutesSeconds(int totalSeconds);

signals:
    void topSongsChanged();
    void topPlaylistsChanged();
    void playlistTracksChanged();
    void playlistIsLoadingChanged();
    void playlistsLoadingChanged();

private slots:
    void onTopSongsData(const QByteArray &data);
    void onTopPlaylistsData(const QByteArray &data);
    void onPlaylistTracksData(const QByteArray &data);
    void onLazyTracksData(const QByteArray &data);

private:
    void setPlaylistsLoading(bool loading);
    // 网络失败/超时兜底：重置 loading 态，避免 QML 永久卡在加载中
    void onPlaylistTracksFailed();
    void onLazyTracksFailed();
    HttpGetRequester m_topSongsRequester;
    HttpGetRequester m_topPlaylistsRequester;
    HttpGetRequester m_playlistTracksRequester;
    QVariantList m_topSongs;
    QVariantList m_topPlaylists;
    SongListModel *m_playlistTracksModel = nullptr;
    QString m_currentPlaylistId;
    int m_playlistPage       = 0;
    // 与 UserManager/UserPlaylistPage 的 300/页对齐：30/页时几百首的歌单
    // 滚一次要连发几十个小请求，对风控不友好
    int m_playlistPageSize   = 300;
    int m_playlistTotal      = 0;
    bool m_playlistHasMore   = true;
    bool m_playlistIsLoading = false;
    bool m_fetchAllPages     = false; // refreshPlaylistTracks：拉到一页后自动续拉剩余页
    bool m_playlistsLoading  = false;
    HttpGetRequester m_lazyRequester;
    std::function<void(const QVariantList &)> m_pendingLazyCallback;
};
#endif // RECOMMENDATION_H
