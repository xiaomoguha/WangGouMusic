#include "dailyrecommend.h"
#include "recommendation.h" // secondsToMinutesSeconds
#include "usermanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
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
}
