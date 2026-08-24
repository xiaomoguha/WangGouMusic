#ifndef PLAYLISTCOLLECTION_H
#define PLAYLISTCOLLECTION_H

#include "HttpGetRequester.h"
#include <QJsonArray>
#include <QObject>
#include <QVariantMap>
#include <functional>

class UserManager;

/**
 * @brief 歌单收藏 / 管理（收藏歌单、取消收藏、新建歌单、加歌、删歌）
 *
 * 依赖 UserManager 提供登录态（token / userid），接口来自酷狗 cloudlist 服务。
 * 收藏歌单 = 把别人歌单加入自己的歌单列表（type=1）；新建 = type=0。
 */
class PlaylistCollection : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isWorking READ isWorking NOTIFY isWorkingChanged)
    // 「我喜欢」hash 集合（QML 绑定依赖它监听 favoriteHashesChanged，红心状态才会刷新）
    Q_PROPERTY(QVariantList favoriteHashes READ favoriteHashes NOTIFY favoriteHashesChanged)

public:
    explicit PlaylistCollection(QObject *parent = nullptr);

    bool isWorking() const { return m_isWorking; }
    QVariantList favoriteHashes() const;

    // 绑定登录态来源（main.cpp 里 userManager 构造后调用）
    void setUserManager(UserManager *um);

    // 收藏歌单（type=1）：需要原歌单的创建者 userid / 原 listid / 原 gid
    Q_INVOKABLE void collectPlaylist(
        const QString &name, const QString &createUserid, const QString &createListid, const QString &createGid
    );
    // 取消收藏（type=1 的收藏项用收藏后的 listid 删除）
    Q_INVOKABLE void uncollectPlaylist(const QString &listid);
    // 新建歌单（type=0），返回新歌单 listid 通过 signal
    Q_INVOKABLE void createPlaylist(const QString &name);
    // 往歌单加歌：songs 每项含 songname/songhash/album_id/mixsongid
    Q_INVOKABLE void addTracks(const QString &listid, const QVariantList &songs);
    // 从歌单删歌：fileids 为数字 id 数组
    Q_INVOKABLE void removeTracks(const QString &listid, const QVariantList &fileids);
    // 添加到「我喜欢」：从歌单缓存找名字含「我喜欢」的歌单，把歌加进去
    Q_INVOKABLE void addToFavorite(const QString &songname, const QString &songhash, const QString &singername,
                                   const QVariantList &freshPlaylists = {});
    // 拉取「我喜欢」歌单的歌曲 hash 集合（红心状态用），成功后发 favoriteHashesChanged
    Q_INVOKABLE void refreshFavoriteHashes();
    // 当前 hash 是否已在「我喜欢」（红心是否点亮）
    Q_INVOKABLE bool containsHash(const QString &songhash) const;

    /// gid "collection_3_1439409719_4_0" → 创建者 userid "1439409719"
    static Q_INVOKABLE QString createUserIdFromGid(const QString &gid);
    /// gid "collection_3_1439409719_4_0" → 原 listid "4"
    static Q_INVOKABLE QString createListIdFromGid(const QString &gid);

signals:
    void isWorkingChanged();
    // success: 操作是否成功；message: 用户可读结果（成功/失败原因）
    void operationFinished(bool success, const QString &message);
    // 「我喜欢」歌曲 hash 集合已更新（红心状态刷新）
    void favoriteHashesChanged();

private:
    void setWorking(bool working);
    void postForm(
        const QString &path, const QList<QPair<QString, QString>> &params, std::function<void(QJsonObject)> onSuccess,
        std::function<void(QString, int)> onError, int timeoutMs = 10000
    );
    // 统一结果回调：status==1 或 error_code==0 视为成功
    void parseResult(QJsonObject root, const QString &successMsg);
    void onFavoriteHashesData(const QByteArray &data);
    void requestFavPage(int page);
    // 红心 hash 集合本地缓存：启动即显示，网络刷新后台更新
    void loadFavoriteHashesFromCache();
    void saveFavoriteHashesToCache();
    /// 统一定位「我喜欢」歌单：名字精确 → 系统 gid(_2_0) → 名字包含 →
    /// 默认收藏 gid(_1_0) → 默认收藏名字。老账号只有「默认收藏」、
    /// 部分账号列表命名不同，单按名字匹配会误报「未找到」
    bool findFavorite(QString &listid, QString &gid, const QVariantList &freshPlaylists = {}) const;
    /// 红心重试：缓存未命中时现场拉一次歌单列表（信号到达时缓存已落盘）再试
    void onUserPlaylistsForRetry(const QVariantMap &data);

    UserManager *m_userManager = nullptr;
    HttpGetRequester m_favRequester;
    QStringList m_favoriteHashes; // 大写 hash
    QString m_favGid;             // 「我喜欢」歌单的 gid（缓存里找到才拉）
    int m_favPage   = 0;          // 分页拉全（接口单页上限 300）
    int m_favTotal  = 0;
    QJsonArray m_favSongsAccum;   // 同步过程中顺带累积的全量歌曲（落盘成歌单详情缓存）
    bool m_isWorking = false;
    bool m_favRetryPending = false;  // 已发起现场拉取等重试（防循环）
    QString m_favPendingName, m_favPendingHash, m_favPendingSinger;
};

#endif // PLAYLISTCOLLECTION_H
