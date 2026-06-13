#include "searchcomplex.h"
#include <QTime>
SearchComplex::SearchComplex(QObject *parent)
    : QObject{parent}
{
    connect(&m_manager, &QNetworkAccessManager::finished,
            this, &SearchComplex::onReplyFinished);
}

void SearchComplex::fetchComplexData(const QString &keyword)
{
    if (keyword.isEmpty())
    {
        qWarning() << "Empty keyword provided";
        return;
    }

    m_currentKeyword = keyword;
    m_page = 1;
    m_items.clear();
    m_isAppendMode = false;

    QNetworkRequest request = QNetworkRequest(QUrl(
        "https://xjt-togethertracks.top/api/search?keywords=" + keyword + "&page=1&pagesize=" + QString::number(PAGE_SIZE)));

    m_isLoading = true;
    emit isLoadingChanged();
    emit pageChanged();
    emit complexsearchitemsChanged();
    m_manager.get(request);
}

void SearchComplex::fetchMore()
{
    if (m_isLoading || !m_hasMore || m_currentKeyword.isEmpty()) return;

    m_page++;
    m_isAppendMode = true;

    QNetworkRequest request = QNetworkRequest(QUrl(
        "https://xjt-togethertracks.top/api/search?keywords=" + m_currentKeyword + "&page=" + QString::number(m_page) + "&pagesize=" + QString::number(PAGE_SIZE)));

    m_isLoading = true;
    emit isLoadingChanged();
    emit pageChanged();
    m_manager.get(request);
}

QVariantList SearchComplex::getcomplexsearchitems() const
{
    return m_items;
}

int SearchComplex::gettotal() const
{
    return m_total;
}

int SearchComplex::getPage() const
{
    return m_page;
}

bool SearchComplex::getHasMore() const
{
    return m_hasMore;
}

bool SearchComplex::getIsLoading() const
{
    return m_isLoading;
}

void SearchComplex::onReplyFinished(QNetworkReply *reply)
{
    m_isLoading = false;
    emit isLoadingChanged();
    emit loadFinished();

    if (reply->error() != QNetworkReply::NoError)
    {
        qWarning() << "Network error:" << reply->errorString();
        reply->deleteLater();
        return;
    }

    const QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);

    if (doc.isNull())
    {
        qDebug() << "Failed to parse JSON";
        reply->deleteLater();
        return;
    }
    QJsonObject root = doc.object();
    int errorCode = root["errcode"].toInt();
    if (errorCode != 0)
    {
        qWarning() << "errcode:" << errorCode;
        reply->deleteLater();
        return;
    }

    // 首次搜索时清空，加载更多时不清空
    if (!m_isAppendMode)
    {
        m_items.clear();
    }

    QJsonObject jsondata = root["data"].toObject();
    m_total = jsondata["total"].toInt();
    const QJsonArray infoObj = jsondata["info"].toArray();

    for (const QJsonValue &infoValues : infoObj)
    {
        const QString songname = infoValues["songname"].toString();
        const QString singername = infoValues["singername"].toString();
        const int duration = infoValues["duration"].toInt();
        const QString durationstr = secondsToMinutesSeconds(duration);
        const QString album_name = infoValues["album_name"].toString();
        const QString songhash = infoValues["hash"].toString();

        const QJsonObject trans_param = infoValues["trans_param"].toObject();
        QString union_cover = trans_param["union_cover"].toString();

        QVariantMap item;
        item["songname"] = songname;
        item["singername"] = singername;
        item["duration"] = durationstr;
        item["album_name"] = album_name;
        item["songhash"] = songhash;
        item["union_cover"] = union_cover.replace("{size}", "720");

        m_items.append(item);
    }

    // 判断是否还有更多
    m_hasMore = m_items.size() < m_total;

    m_isAppendMode = false;

    emit complexsearchitemsChanged();
    emit totalChanged();
    emit hasMoreChanged();
    reply->deleteLater();
}

QString SearchComplex::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0);
    time = time.addSecs(totalSeconds);
    return time.toString("mm:ss");
}
