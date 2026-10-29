#include "dailyrecommend.h"
#include "SongInfo.h"
#include "recommendation.h" // secondsToMinutesSeconds
#include "usermanager.h"

#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QTime>
#include <QUrlQuery>

void DailyRecommend::setUserManager(UserManager *um)
{
    m_userManager = um;
}

DailyRecommend::DailyRecommend(QObject *parent) : QObject(parent)
{
    connect(&m_requester, &HttpGetRequester::dataReceived, this, &DailyRecommend::onData);
    connect(&m_requester, &HttpGetRequester::requestFailed, this, [this](const QString &err)
            {
                qWarning() << "[DailyRecommend] fetch error:" << err;
                onFailed();
            });
    connect(&m_requester, &HttpGetRequester::requestTimeout, this, [this]()
            {
                qWarning() << "[DailyRecommend] fetch timeout";
                onFailed();
            });

    // 跨天自动刷新：客户端常驻（不重启）时第二天仍会显示前一天那份，
    // 到点自己重拉，不需要用户点刷新
    m_refreshTimer.setSingleShot(true);
    connect(&m_refreshTimer, &QTimer::timeout, this, &DailyRecommend::refreshIfStale);
}

void DailyRecommend::refreshIfStale()
{
    // m_date 是上游给的推荐日期（yyyyMMdd）。空 = 从没拉到过（首次进入页面）。
    if (m_date == QDate::currentDate().toString(QStringLiteral("yyyyMMdd")))
        return;
    fetch();
}

// 下一次自动检查的时机：
//  - 手上已经是今天的 → 定到次日本地 0 点过后几秒
//  - 还不是今天的 → 10 分钟后重试。上游翻页时间不保证在 0 点整（可能晚几分钟），
//    定死"次日 0 点"会漏掉这种：0 点拉到的还是昨天那份，就要再等一整天
void DailyRecommend::scheduleNextRefresh()
{
    const QString today = QDate::currentDate().toString(QStringLiteral("yyyyMMdd"));
    if (m_date != today)
    {
        m_refreshTimer.start(10 * 60 * 1000);
        return;
    }

    const QDateTime nextMidnight = QDate::currentDate().addDays(1).startOfDay();
    const qint64 ms              = QDateTime::currentDateTime().msecsTo(nextMidnight) + 5000;
    m_refreshTimer.start(static_cast<int>(qBound<qint64>(1000, ms, 24LL * 3600 * 1000)));
}

void DailyRecommend::fetch()
{
    if (m_isLoading)
        return;
    m_isLoading = true;
    emit isLoadingChanged();

    // 登录态注入 userid/token → 服务端并入 cookie → 酷狗上游按账号个性化
    QUrlQuery query;
    if (m_userManager)
    {
        if (!m_userManager->userid().isEmpty())
            query.addQueryItem("userid", m_userManager->userid());
        if (!m_userManager->token().isEmpty())
            query.addQueryItem("token", m_userManager->token());
    }
    const QString url = "https://api.special520.com/everyday/recommend"
                        + (query.isEmpty() ? "" : "?" + query.toString());
    m_requester.fetchData(url);
}

void DailyRecommend::onFailed()
{
    m_isLoading = false;
    emit isLoadingChanged();
    // 失败也要排下一次：跨天那次失败（断网/服务端抖动）时 10 分钟后再试，
    // 避免整晚停在昨天那份
    scheduleNextRefresh();
}

void DailyRecommend::onData(const QByteArray &data)
{
    m_isLoading = false;
    emit isLoadingChanged();

    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError)
    {
        qWarning() << "[DailyRecommend] JSON parse error:" << perr.errorString();
        return;
    }
    const QJsonObject root = doc.object();
    if (root["status"].toInt() != 1)
        return;
    const QJsonObject dataObj = root["data"].toObject();

    m_date     = dataObj["creation_date"].toString();
    m_coverUrl = dataObj["cover_img_url"].toString();
    m_coverUrl.replace("{size}", "400");

    QVariantList songs;
    const QJsonArray list = dataObj["song_list"].toArray();
    for (const QJsonValue &val : list)
    {
        const QJsonObject s = val.toObject();
        const QString hash  = s["hash"].toString();
        const QString name  = s["songname"].toString();
        if (hash.isEmpty() || name.isEmpty())
            continue;
        SongInfo::rememberMxidFromJson(s, hash);

        // 歌手：singerinfo 数组 → 逗号拼接；兜底用 filename "歌手 - 歌名"
        QString singername;
        const QJsonArray singers = s["singerinfo"].toArray();
        if (!singers.isEmpty())
        {
            QStringList names;
            for (const QJsonValue &si : singers)
                names << si.toObject()["name"].toString();
            singername = names.join(", ");
        }
        if (singername.isEmpty())
        {
            const QString filename = s["filename"].toString();
            const int dash         = filename.indexOf(" - ");
            if (dash > 0)
                singername = filename.left(dash);
        }

        QString cover = s["trans_param"].toObject()["union_cover"].toString();
        if (cover.isEmpty())
            cover = s["cover"].toString();
        cover.replace("{size}", "400");

        QVariantMap item;
        item["songname"]    = name;
        item["songhash"]    = hash;
        item["singername"]  = singername;
        item["union_cover"] = cover;
        item["album_name"]  = s["album_name"].toString();
        // 时长字段是 time_length（秒，非毫秒），直接格式化；缺失时留空由 UI 兜底 "--:--"
        item["duration"]    = Recommendation::secondsToMinutesSeconds(s["time_length"].toInt(0));
        songs.append(item);
    }
    m_songs = songs;
    emit songsChanged();
    // 拿到这份之后排下一次：是今天的就等跨天，还是昨天那份就 10 分钟后再看
    scheduleNextRefresh();
}
