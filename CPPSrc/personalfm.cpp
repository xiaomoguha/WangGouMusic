#include "personalfm.h"
#include "usermanager.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QMap>
#include <QUrlQuery>

void PersonalFM::setUserManager(UserManager *um)
{
    m_userManager = um;
}

PersonalFM::PersonalFM(QObject *parent) : QObject(parent)
{
    connect(&m_requester, &HttpGetRequester::dataReceived, this, &PersonalFM::onData);
    connect(&m_requester, &HttpGetRequester::requestFailed, this, [this](const QString &err)
            {
                qWarning() << "[PersonalFM] fetch error:" << err;
                onFailed();
            });
    connect(&m_requester, &HttpGetRequester::requestTimeout, this, [this]()
            {
                qWarning() << "[PersonalFM] fetch timeout";
                onFailed();
            });
    connect(&m_coverRequester, &HttpGetRequester::dataReceived, this, &PersonalFM::onCoverData);
    connect(&m_coverRequester, &HttpGetRequester::requestFailed, this, &PersonalFM::onCoverFailed);
    connect(&m_coverRequester, &HttpGetRequester::requestTimeout, this, [this]() { onCoverFailed(QString()); });
}

void PersonalFM::fetch()
{
    if (m_isLoading)
        return;
    request(QString());
}

void PersonalFM::fetchNext()
{
    if (m_isLoading || m_songs.isEmpty())
        return;
    // 换一批 = 把本批最后一首歌的 hash 传给服务端，取下一批
    request(m_songs.last().toMap()["songhash"].toString());
}

QString PersonalFM::lastHash() const
{
    return m_songs.isEmpty() ? QString() : m_songs.last().toMap()["songhash"].toString();
}

void PersonalFM::request(const QString &hash)
{
    m_isLoading = true;
    emit isLoadingChanged();

    QUrlQuery query;
    // 登录态提升推荐个性化
    if (m_userManager)
    {
        if (!m_userManager->userid().isEmpty())
            query.addQueryItem("userid", m_userManager->userid());
        if (!m_userManager->token().isEmpty())
            query.addQueryItem("token", m_userManager->token());
    }
    if (!hash.isEmpty())
        query.addQueryItem("hash", hash);

    const QString url = "https://xjt-togethertracks.top/api/personal/fm" + (query.isEmpty() ? "" : "?" + query.toString());
    m_requester.fetchData(url);
}

void PersonalFM::onFailed()
{
    m_isLoading = false;
    emit isLoadingChanged();
}

void PersonalFM::onData(const QByteArray &data)
{
    m_isLoading = false;
    emit isLoadingChanged();

    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError)
    {
        qWarning() << "[PersonalFM] JSON parse error:" << perr.errorString();
        return;
    }
    const QJsonObject root = doc.object();
    if (root["status"].toInt() != 1)
    {
        qWarning() << "[PersonalFM] status != 1";
        return;
    }
    const QJsonArray list = root["data"].toObject()["song_list"].toArray();
    if (list.isEmpty())
    {
        qWarning() << "[PersonalFM] empty song_list";
        return;
    }

    QVariantList songs;
    for (const QJsonValue &val : list)
    {
        const QJsonObject s = val.toObject();
        const QString hash  = s["hash"].toString();
        const QString name  = s["songname"].toString();
        if (hash.isEmpty() || name.isEmpty())
            continue;

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
        item["album_id"]    = s["album_id"].toString();
        // FM 接口不返回时长，留空由 UI 兜底 "--:--"
        item["duration"]    = QString();
        songs.append(item);
    }
    if (songs.isEmpty())
    {
        qWarning() << "[PersonalFM] parsed empty";
        return;
    }
    m_songs = songs;

    // FM 接口无封面：按 album_id 查专辑封面补全（同专辑多首只请求一次）。
    // 队列全部完成后才发 songsChanged，UI 一次性刷新（避免两次闪烁）。
    QMap<QString, QVariantList> byAlbum;
    for (int i = 0; i < m_songs.size(); ++i)
    {
        const QVariantMap item = m_songs[i].toMap();
        if (!item["union_cover"].toString().isEmpty())
            continue;
        const QString albumId = item["album_id"].toString();
        if (albumId.isEmpty())
            continue;
        byAlbum[albumId].append(i);
    }
    QVariantList queue;
    for (auto it = byAlbum.begin(); it != byAlbum.end(); ++it)
    {
        QVariantMap task;
        task["albumId"] = it.key();
        task["indexes"] = it.value();
        queue.append(task);
    }
    m_coverQueue = queue;
    m_coverCursor = 0;

    if (m_coverQueue.isEmpty())
    {
        emit songsChanged();
        qDebug() << "[PersonalFM] 批次加载完成，共" << m_songs.size() << "首（无需补封面）";
        return;
    }
    qDebug() << "[PersonalFM] 批次加载完成，待补封面专辑数:" << m_coverQueue.size();
    requestNextCover();
}

void PersonalFM::requestNextCover()
{
    if (m_coverCursor >= m_coverQueue.size())
    {
        m_coverQueue.clear();
        m_coverCursor = 0;
        emit songsChanged();
        qDebug() << "[PersonalFM] 封面补全完成，共" << m_songs.size() << "首";
        return;
    }
    const QVariantMap task = m_coverQueue[m_coverCursor].toMap();
    const QString url = QString("https://xjt-togethertracks.top/api/album/songs?id=%1").arg(task["albumId"].toString());
    m_coverRequester.fetchData(url);
}

void PersonalFM::onCoverData(const QByteArray &data)
{
    QString cover;
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error == QJsonParseError::NoError)
    {
        const QJsonArray songs = doc.object()["data"].toObject()["songs"].toArray();
        if (!songs.isEmpty())
            cover = songs.first().toObject()["album_info"].toObject()["cover"].toString();
    }
    if (!cover.isEmpty())
    {
        cover.replace("{size}", "200");
        const QVariantMap task = m_coverQueue[m_coverCursor].toMap();
        const QVariantList idxs = task["indexes"].toList();
        for (const QVariant &i : idxs)
        {
            QVariantMap item = m_songs[i.toInt()].toMap();
            item["union_cover"] = cover;
            m_songs[i.toInt()] = item;
        }
    }
    m_coverCursor++;
    requestNextCover();
}

void PersonalFM::onCoverFailed(const QString &err)
{
    if (!err.isEmpty())
        qWarning() << "[PersonalFM] cover fetch error:" << err;
    // 跳过当前专辑继续（失败歌曲保持渐变占位）
    m_coverCursor++;
    requestNextCover();
}
