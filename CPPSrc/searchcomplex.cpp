#include "searchcomplex.h"
#include "ApiClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTime>
#include <QUrl>
#include <QDebug>

SearchComplex::SearchComplex(QObject *parent)
    : QObject{parent}
{
}

void SearchComplex::fetchComplexData(const QString &keyword)
{
    if (keyword.isEmpty()) {
        qWarning() << "Empty keyword provided";
        return;
    }

    m_currentKeyword = keyword;
    m_page = 1;
    m_items.clear();
    m_isAppendMode = false;

    const QString url = QString("https://xjt-togethertracks.top/api/search?keywords=%1&page=1&pagesize=%2")
                          .arg(keyword).arg(PAGE_SIZE);

    m_isLoading = true;
    emit isLoadingChanged();
    emit pageChanged();
    emit complexsearchitemsChanged();

    ApiClient::instance().getJson(url,
        [this](QJsonObject root) { parseAndAppend(root, false); },
        [this](QString err, int code) {
            qWarning() << "[SearchComplex] fetch error:" << err << "code:" << code;
            m_isLoading = false;
            emit isLoadingChanged();
            emit loadFinished();
        },
        10000);
}

void SearchComplex::fetchMore()
{
    if (m_isLoading || !m_hasMore || m_currentKeyword.isEmpty()) return;

    m_page++;
    m_isAppendMode = true;
    m_isLoading = true;
    emit isLoadingChanged();
    emit pageChanged();

    const QString url = QString("https://xjt-togethertracks.top/api/search?keywords=%1&page=%2&pagesize=%3")
                          .arg(m_currentKeyword).arg(m_page).arg(PAGE_SIZE);

    ApiClient::instance().getJson(url,
        [this](QJsonObject root) { parseAndAppend(root, true); },
        [this](QString err, int code) {
            qWarning() << "[SearchComplex] fetchMore error:" << err << "code:" << code;
            m_isLoading = false;
            emit isLoadingChanged();
            emit loadFinished();
        },
        10000);
}

void SearchComplex::parseAndAppend(const QJsonObject &root, bool isAppend)
{
    Q_UNUSED(isAppend);
    m_isLoading = false;
    emit isLoadingChanged();
    emit loadFinished();

    const int errorCode = root["errcode"].toInt();
    if (errorCode != 0) {
        qWarning() << "[SearchComplex] errcode:" << errorCode;
        return;
    }

    // 首次搜索时清空，加载更多时不清空
    if (!m_isAppendMode) {
        m_items.clear();
    }

    const QJsonObject jsondata = root["data"].toObject();
    m_total = jsondata["total"].toInt();
    const QJsonArray infoObj = jsondata["info"].toArray();

    for (const QJsonValue &infoValues : infoObj) {
        const QString songname  = infoValues["songname"].toString();
        const QString singername = infoValues["singername"].toString();
        const int duration       = infoValues["duration"].toInt();
        const QString durstr     = secondsToMinutesSeconds(duration);
        const QString album_name = infoValues["album_name"].toString();
        const QString songhash   = infoValues["hash"].toString();

        const QJsonObject trans_param = infoValues["trans_param"].toObject();
        QString union_cover = trans_param["union_cover"].toString();
        union_cover.replace("{size}", "720");

        QVariantMap item;
        item["songname"]    = songname;
        item["singername"]  = singername;
        item["duration"]    = durstr;
        item["album_name"]  = album_name;
        item["songhash"]    = songhash;
        item["union_cover"] = union_cover;

        m_items.append(item);
    }

    m_hasMore = m_items.size() < m_total;
    m_isAppendMode = false;

    emit complexsearchitemsChanged();
    emit totalChanged();
    emit hasMoreChanged();
}

QVariantList SearchComplex::getcomplexsearchitems() const { return m_items; }
int SearchComplex::gettotal() const { return m_total; }
int SearchComplex::getPage() const { return m_page; }
bool SearchComplex::getHasMore() const { return m_hasMore; }
bool SearchComplex::getIsLoading() const { return m_isLoading; }

QString SearchComplex::secondsToMinutesSeconds(int totalSeconds)  // 旧实现保留兼容（避免外部依赖）
{
    QTime time(0, 0);
    time = time.addSecs(totalSeconds);
    return time.toString("mm:ss");
}
