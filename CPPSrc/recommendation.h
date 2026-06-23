#ifndef RECOMMENDATION_H
#define RECOMMENDATION_H
#include <QObject>
#include <functional>
#include "HttpGetRequester.h"
class Recommendation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList topSongsQml READ getTopSongsQml NOTIFY topSongsChanged)
    Q_PROPERTY(QVariantList topPlaylistsQml READ getTopPlaylistsQml NOTIFY topPlaylistsChanged)
    Q_PROPERTY(QVariantList playlistTracksQml READ getPlaylistTracksQml NOTIFY playlistTracksChanged)
    Q_PROPERTY(int playlistTotal READ playlistTotal NOTIFY playlistTracksChanged)
    Q_PROPERTY(bool playlistHasMore READ playlistHasMore NOTIFY playlistTracksChanged)
    Q_PROPERTY(bool playlistIsLoading READ playlistIsLoading NOTIFY playlistIsLoadingChanged)

public:
    explicit Recommendation(QObject *parent = nullptr);

    Q_INVOKABLE void fetchTopSongs();
    Q_INVOKABLE void fetchTopPlaylists();
    Q_INVOKABLE void refreshTopPlaylists();
    Q_INVOKABLE void fetchPlaylistTracks(const QString &globalCollectionId);
    Q_INVOKABLE void fetchMorePlaylistTracks();
    Q_INVOKABLE void loadAllPlaylistTracks();
    // C++ 内部用：按页拉取指定歌单歌曲，结果通过 callback 返回（QVariantList，每项含 songname/songhash/singername/union_cover/album_name/duration）
    void fetchPlaylistTracksPage(const QString &id, int page, int pagesize,
                                 std::function<void(const QVariantList&)> callback);

    QVariantList getTopSongsQml() const;
    QVariantList getTopPlaylistsQml() const;
    QVariantList getPlaylistTracksQml() const;
    int playlistTotal() const { return m_playlistTotal; }
    bool playlistHasMore() const { return m_playlistHasMore; }
    bool playlistIsLoading() const { return m_playlistIsLoading; }

    static QString secondsToMinutesSeconds(int totalSeconds);

signals:
    void topSongsChanged();
    void topPlaylistsChanged();
    void playlistTracksChanged();
    void playlistIsLoadingChanged();

private slots:
    void onTopSongsData(const QByteArray &data);
    void onTopPlaylistsData(const QByteArray &data);
    void onPlaylistTracksData(const QByteArray &data);
    void onLazyTracksData(const QByteArray &data);

private:
    HttpGetRequester m_topSongsRequester;
    HttpGetRequester m_topPlaylistsRequester;
    HttpGetRequester m_playlistTracksRequester;
    QVariantList m_topSongs;
    QVariantList m_topPlaylists;
    QVariantList m_playlistTracks;
    QString m_currentPlaylistId;
    int m_playlistPage = 0;
    int m_playlistPageSize = 30;
    int m_playlistTotal = 0;
    bool m_playlistHasMore = true;
    bool m_playlistIsLoading = false;
    HttpGetRequester m_lazyRequester;
    std::function<void(const QVariantList&)> m_pendingLazyCallback;
};
#endif // RECOMMENDATION_H
