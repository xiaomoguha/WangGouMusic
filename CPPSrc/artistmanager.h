#ifndef ARTISTMANAGER_H
#define ARTISTMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

/**
 * @brief 歌手页数据（/api/artist/detail + audios + albums）。
 *
 * 歌手详情（头像/名字/粉丝/简介/歌曲专辑数）、单曲与专辑均独立分页；
 * 进入歌手页时 detail + 第一页单曲/专辑并行拉取。
 */
class ArtistManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap artist READ artist NOTIFY artistChanged)
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(QVariantList albums READ albums NOTIFY albumsChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMoreSongs READ hasMoreSongs NOTIFY songsChanged)
    Q_PROPERTY(bool hasMoreAlbums READ hasMoreAlbums NOTIFY albumsChanged)

public:
    explicit ArtistManager(QObject *parent = nullptr);

    QVariantMap artist() const { return m_artist; }
    QVariantList songs() const { return m_songs; }
    QVariantList albums() const { return m_albums; }
    bool isLoading() const { return m_isLoading; }
    bool hasMoreSongs() const { return m_hasMoreSongs; }
    bool hasMoreAlbums() const { return m_hasMoreAlbums; }

    /// 拉取歌手页全部数据：detail + 单曲/专辑第一页（返回是否发起；加载中拒绝并发）
    Q_INVOKABLE bool fetchArtist(const QString &id);
    /// 单曲/专辑各自加载下一页
    Q_INVOKABLE void fetchMoreSongs();
    Q_INVOKABLE void fetchMoreAlbums();

    /// 按歌手名搜索第一个匹配的歌手（搜索结果页顶部卡片用），结果经 singerFound 发出
    Q_INVOKABLE void searchSinger(const QString &name);

signals:
    void artistChanged();
    void songsChanged();
    void albumsChanged();
    void isLoadingChanged();
    void singerFound(const QVariantMap &singer);

private slots:
    void onDetailData(const QByteArray &data);
    void onAudiosData(const QByteArray &data);
    void onAlbumsData(const QByteArray &data);
    void onSearchData(const QByteArray &data);

private:
    void onFailed(const QString &err);
    void finishOne();   // 并行请求完成一个（归零清 loading）

    HttpGetRequester m_detailRequester;
    HttpGetRequester m_audiosRequester;
    HttpGetRequester m_albumsRequester;
    HttpGetRequester m_searchRequester;

    QString m_artistId;
    int m_pendingCount = 0;   // 并行请求计数（detail+audios+albums），归零时清 loading
    int m_songPage = 0;
    int m_albumPage = 0;
    bool m_hasMoreSongs = false;
    bool m_hasMoreAlbums = false;
    bool m_isLoading = false;

    QVariantMap m_artist;
    QVariantList m_songs;
    QVariantList m_albums;
};

#endif // ARTISTMANAGER_H
