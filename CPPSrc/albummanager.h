#ifndef ALBUMMANAGER_H
#define ALBUMMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

/**
 * @brief 专辑页数据（/api/album/detail + /api/album/songs 分页）。
 */
class AlbumManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap album READ album NOTIFY albumChanged)
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY songsChanged)

public:
    explicit AlbumManager(QObject *parent = nullptr);

    QVariantMap album() const { return m_album; }
    QVariantList songs() const { return m_songs; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }

    /// 拉取专辑详情 + 歌曲第一页（返回是否发起；加载中拒绝并发）
    Q_INVOKABLE bool fetchAlbum(const QString &id);
    Q_INVOKABLE void fetchMoreSongs();

signals:
    void albumChanged();
    void songsChanged();
    void isLoadingChanged();

private slots:
    void onDetailData(const QByteArray &data);
    void onSongsData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    void finishOne();

    HttpGetRequester m_detailRequester;
    HttpGetRequester m_songsRequester;

    QString m_albumId;
    int m_pendingCount = 0;
    int m_page = 0;
    bool m_hasMore = false;
    bool m_isLoading = false;

    QVariantMap m_album;
    QVariantList m_songs;
};

#endif // ALBUMMANAGER_H
