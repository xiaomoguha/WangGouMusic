#ifndef RANKLIST_H
#define RANKLIST_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

/**
 * @brief 排行榜（/api/rank/list + /api/rank/info + /api/rank/audio）。
 *
 * 三路请求：榜单列表、榜单详情（名称/封面）、榜单歌曲（audio_info 嵌套 hash/时长）。
 * fetchRandomRankSongs() 供首页「热门推荐换一批」：随机挑一个榜单，把歌曲以
 * randomSongsReady 信号交给 UI 侧注入推荐区。
 */
class RankList : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList ranks READ ranks NOTIFY ranksChanged)
    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(QString rankName READ rankName NOTIFY rankInfoChanged)
    Q_PROPERTY(QString rankCover READ rankCover NOTIFY rankInfoChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)

public:
    explicit RankList(QObject *parent = nullptr);

    QVariantList ranks() const { return m_ranks; }
    QVariantList songs() const { return m_songs; }
    QString rankName() const { return m_rankName; }
    QString rankCover() const { return m_rankCover; }
    bool isLoading() const { return m_isLoading; }

    /// 拉取榜单列表
    Q_INVOKABLE void fetchRanks();
    /// 拉取指定榜单的详情 + 歌曲（详情完成后自动接歌曲请求）
    Q_INVOKABLE void fetchRankSongs(const QString &rankid);
    /// 随机挑一个榜单并拉取其歌曲；完成后发 randomSongsReady
    Q_INVOKABLE void fetchRandomRankSongs();

signals:
    void ranksChanged();
    void songsChanged();
    void rankInfoChanged();
    void isLoadingChanged();
    void randomSongsReady(const QVariantList &songs);

private slots:
    void onRanksData(const QByteArray &data);
    void onInfoData(const QByteArray &data);
    void onSongsData(const QByteArray &data);

private:
    void onRequestFailed(const QString &err);
    void setLoading(bool loading);

    HttpGetRequester m_ranksRequester;
    HttpGetRequester m_infoRequester;
    HttpGetRequester m_songsRequester;
    QVariantList m_ranks;
    QVariantList m_songs;
    QString m_rankName;
    QString m_rankCover;
    QString m_currentRankId;
    bool m_isLoading = false;
    // fetchRandomRankSongs 模式下，歌曲解析完成后补发 randomSongsReady
    bool m_pendingRandom = false;
    // fetchRandomRankSongs 且榜单列表还没拉过 → 拉完榜单后自动随机续接
    bool m_pendingRandomFetch = false;
};

#endif // RANKLIST_H
