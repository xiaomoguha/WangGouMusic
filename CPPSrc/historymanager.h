#ifndef HISTORYMANAGER_H
#define HISTORYMANAGER_H

#include "HttpGetRequester.h"
#include <QHash>
#include <QObject>
#include <QTimer>
#include <QVariantList>

class UserManager;

/**
 * @brief 听歌历史同步。
 *
 * 播放上报：播放超过 30 秒后上报（main.cpp 触发），批量解析 mxid 后上传
 * /playhistory/upload。pc 是覆盖语义（会覆盖云端次数），故上传前必须知道云端基线：
 * 拉取 playhistory 全量时构建 mxid→pc 缓存，上报 pc = 基线 + 会话内次数（单曲循环计数）。
 *
 * 历史展示：playhistory 全量（bp 游标分页翻完，与酷狗 APP 听歌历史页一致）。
 */
class HistoryManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY historyChanged)
    Q_PROPERTY(bool uploadWorking READ uploadWorking NOTIFY uploadWorkingChanged)
    Q_PROPERTY(int total READ total NOTIFY totalChanged)  // 云端历史总数（后台翻页计数得出）

public:
    explicit HistoryManager(QObject *parent = nullptr);

    /// 注入用户管理器：读取/上传历史都需要 userid+token 鉴权（酷狗接口强制）
    void setUserManager(UserManager *um);

    QVariantList history() const { return m_history; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }
    bool uploadWorking() const { return m_uploadWorking; }
    int total() const { return m_total; }

    /// 播放歌曲时上报（入队，延迟批量处理；未登录忽略）
    Q_INVOKABLE void reportPlayed(const QString &title, const QString &hash);
    /// 拉取云端听歌历史：首屏第一页 + 后台静默翻页数总数（记游标不存歌）
    Q_INVOKABLE void fetchHistory();
    /// 下拉加载更多：按已记录游标逐页追加（与搜索页一致）
    Q_INVOKABLE void fetchMoreHistory();

signals:
    void historyChanged();
    void isLoadingChanged();
    void uploadWorkingChanged();
    void historyReset(const QVariantList &songs);  // 首屏：清空 + 填充第一页
    void historyAppended(const QVariantList &songs);  // 下拉加载：追加新页
    void totalChanged();

private slots:
    void flushQueue();
    void onPrivilegeData(const QByteArray &data);
    void onPlayhistoryData(const QByteArray &data);
    void onUploadDone(const QByteArray &data);

private:
    void onFailed(const QString &err);
    void doUpload(const QVariantList &songs);
    QString authQuery() const;     // 拼接 userid+token 鉴权参数（无登录返回空）
    void loadHistoryFromCache();   // 启动时加载本地缓存（点进去前先展示）
    void saveHistoryToCache();     // 同步云端首页后落本地缓存
    void fetchPlayhistoryPage(const QString &bp);  // 拉一页 playhistory（链式翻页）
    // 解析 playhistory 响应（data.songs[]，info 嵌套），填 outSongs 并更新 pc 缓存；失败返回 false
    bool parsePlayhistoryData(const QByteArray &data, QVariantList &outSongs, bool &hasMore, QString &nextBp);

    HttpGetRequester m_privilegeRequester;  // 用 hash 批量查 album_audio_id（mxid）
    HttpGetRequester m_uploadRequester;
    HttpGetRequester m_historyRequester;

    UserManager *m_userManager = nullptr;

    QTimer m_flushTimer;
    QVariantList m_pending;        // 待上报的 {hash, time}
    bool m_uploadWorking = false;
    QHash<QString, qint64> m_lastReport;  // hash→上次上报时间：30 秒窗口内同歌不重复（单曲循环每圈 >30s 可再报）

    QVariantList m_history;
    bool m_hasMore = false;
    bool m_isLoading = false;

    // playhistory 分页状态（全量内存 + 按批展示）
    static constexpr int kPageSize = 50;   // 展示批大小（首屏/下拉每批）
    QVariantList m_playSongs;      // 当前已展示的歌曲（分批追加）
    QStringList m_bpList;          // 翻页游标（全量拉取用）
    int m_total = 0;               // 云端历史总数
    int m_loadedPages = 0;         // 已展示批数
    bool m_loadingMore = false;    // 下拉加载中标志（当前为内存切批，保留语义）
    int m_loadedTotalPages() const;  // 全量数据可分多少批
    bool m_pcReady = false;        // mxid→pc 基线缓存是否已构建（上传前必须就绪，否则 pc 覆盖会毁数据）
    QHash<qint64, int> m_pcCache;  // mxid→云端 pc 基线
    QHash<QString, int> m_sessionCount;  // hash→本次会话播放次数（单曲循环累加）
};

#endif // HISTORYMANAGER_H
