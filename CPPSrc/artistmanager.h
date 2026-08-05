#ifndef ARTISTMANAGER_H
#define ARTISTMANAGER_H

#include "HttpGetRequester.h"
#include "artistlistmodel.h"
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
    Q_PROPERTY(ArtistListModel *songsModel READ songsModel CONSTANT)
    Q_PROPERTY(ArtistListModel *albumsModel READ albumsModel CONSTANT)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMoreSongs READ hasMoreSongs NOTIFY hasMoreSongsChanged)
    Q_PROPERTY(bool hasMoreAlbums READ hasMoreAlbums NOTIFY hasMoreAlbumsChanged)
    Q_PROPERTY(bool songsLoading READ songsLoading NOTIFY songsLoadingChanged)
    Q_PROPERTY(bool albumsLoading READ albumsLoading NOTIFY albumsLoadingChanged)

public:
    explicit ArtistManager(QObject *parent = nullptr);

    QVariantMap artist() const { return m_artist; }
    ArtistListModel *songsModel() const { return const_cast<ArtistListModel *>(&m_songsModel); }
    ArtistListModel *albumsModel() const { return const_cast<ArtistListModel *>(&m_albumsModel); }
    bool isLoading() const { return m_isLoading; }
    bool hasMoreSongs() const { return m_hasMoreSongs; }
    bool hasMoreAlbums() const { return m_hasMoreAlbums; }
    bool songsLoading() const { return m_loadingSongs; }
    bool albumsLoading() const { return m_loadingAlbums; }

    /// 拉取歌手页全部数据：detail + 单曲/专辑第一页（返回是否发起；加载中拒绝并发）
    Q_INVOKABLE bool fetchArtist(const QString &id);
    /// 单曲/专辑各自加载下一页
    Q_INVOKABLE void fetchMoreSongs();
    Q_INVOKABLE void fetchMoreAlbums();

    /// 按歌手名搜索第一个匹配的歌手（搜索结果页顶部卡片用），结果经 singerFound 发出
    Q_INVOKABLE void searchSinger(const QString &name);

signals:
    void artistChanged();
    void isLoadingChanged();
    void hasMoreSongsChanged();
    void hasMoreAlbumsChanged();
    void songsLoadingChanged();
    void albumsLoadingChanged();
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
    bool m_loadingSongs = false;   // 单曲分页请求在途（防滚动重复触发）
    bool m_loadingAlbums = false;  // 专辑分页请求在途
    bool m_hasMoreSongs = false;
    bool m_hasMoreAlbums = false;
    bool m_isLoading = false;

    QVariantMap m_artist;
    ArtistListModel m_songsModel;
    ArtistListModel m_albumsModel;
};

#endif // ARTISTMANAGER_H
