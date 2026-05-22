#ifndef RECOMMENDATION_H
#define RECOMMENDATION_H
#include <QObject>
#include "HttpGetRequester.h"
class Recommendation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList topSongsQml READ getTopSongsQml NOTIFY topSongsChanged)
    Q_PROPERTY(QVariantList topPlaylistsQml READ getTopPlaylistsQml NOTIFY topPlaylistsChanged)
    Q_PROPERTY(QVariantList playlistTracksQml READ getPlaylistTracksQml NOTIFY playlistTracksChanged)

public:
    explicit Recommendation(QObject *parent = nullptr);

    Q_INVOKABLE void fetchTopSongs();
    Q_INVOKABLE void fetchTopPlaylists();
    Q_INVOKABLE void refreshTopPlaylists();
    Q_INVOKABLE void fetchPlaylistTracks(const QString &globalCollectionId);

    QVariantList getTopSongsQml() const;
    QVariantList getTopPlaylistsQml() const;
    QVariantList getPlaylistTracksQml() const;

    static QString secondsToMinutesSeconds(int totalSeconds);

signals:
    void topSongsChanged();
    void topPlaylistsChanged();
    void playlistTracksChanged();

private slots:
    void onTopSongsData(const QByteArray &data);
    void onTopPlaylistsData(const QByteArray &data);
    void onPlaylistTracksData(const QByteArray &data);

private:
    HttpGetRequester m_topSongsRequester;
    HttpGetRequester m_topPlaylistsRequester;
    HttpGetRequester m_playlistTracksRequester;
    QVariantList m_topSongs;
    QVariantList m_topPlaylists;
    QVariantList m_playlistTracks;
};
#endif // RECOMMENDATION_H
