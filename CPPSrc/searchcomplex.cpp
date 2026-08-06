#include "searchcomplex.h"
#include "ApiClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTime>
#include <QUrl>
#include <QDebug>

SearchComplex::SearchComplex(QObject *parent) : QAbstractListModel{parent} {}

int SearchComplex::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant SearchComplex::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};
    const QVariantMap &m = m_items.at(index.row());
    switch (role)
    {
    case SongnameRole:   return m.value("songname");
    case SingernameRole: return m.value("singername");
    case DurationRole:   return m.value("duration");
    case AlbumNameRole:  return m.value("album_name");
    case SonghashRole:   return m.value("songhash");
    case UnionCoverRole: return m.value("union_cover");
    case MvhashRole:     return m.value("mvhash");
    }
    return {};
}

QHash<int, QByteArray> SearchComplex::roleNames() const
{
    return {
        {SongnameRole, "songname"},
        {SingernameRole, "singername"},
        {DurationRole, "duration"},
        {AlbumNameRole, "album_name"},
        {SonghashRole, "songhash"},
        {UnionCoverRole, "union_cover"},
        {MvhashRole, "mvhash"},
    };
}

void SearchComplex::fetchComplexData(const QString &keyword)
{
    if (keyword.isEmpty())
    {
        qWarning() << "Empty keyword provided";
        return;
    }

    m_currentKeyword = keyword;
    m_page           = 1;
    m_isAppendMode   = false;

    // 新搜索：整体重置并清空旧结果（视图回到顶部，并立刻进入加载态）
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();

    const QString url =
        QString("https://xjt-togethertracks.top/api/search?keywords=%1&page=1&pagesize=%2").arg(keyword).arg(PAGE_SIZE);

    m_isLoading = true;
    emit isLoadingChanged();
    emit pageChanged();

    ApiClient::instance().getJson(
        url, [this](QJsonObject root) { parseAndAppend(root, false); },
        [this](QString err, int code)
        {
            qWarning() << "[SearchComplex] fetch error:" << err << "code:" << code;
            m_isLoading = false;
            emit isLoadingChanged();
            emit loadFinished();
        },
        10000
    );
}

void SearchComplex::fetchMore()
{
    if (m_isLoading || !m_hasMore || m_currentKeyword.isEmpty())
        return;

    m_page++;
    m_isAppendMode = true;
    m_isLoading    = true;
    emit isLoadingChanged();
    emit pageChanged();

    const QString url = QString("https://xjt-togethertracks.top/api/search?keywords=%1&page=%2&pagesize=%3")
                            .arg(m_currentKeyword)
                            .arg(m_page)
                            .arg(PAGE_SIZE);

    ApiClient::instance().getJson(
        url, [this](QJsonObject root) { parseAndAppend(root, true); },
        [this](QString err, int code)
        {
            qWarning() << "[SearchComplex] fetchMore error:" << err << "code:" << code;
            m_isLoading = false;
            emit isLoadingChanged();
            emit loadFinished();
        },
        10000
    );
}

void SearchComplex::parseAndAppend(const QJsonObject &root, bool isAppend)
{
    Q_UNUSED(isAppend);
    m_isLoading = false;
    emit isLoadingChanged();
    emit loadFinished();

    const int errorCode = root["errcode"].toInt();
    if (errorCode != 0)
    {
        qWarning() << "[SearchComplex] errcode:" << errorCode;
        return;
    }

    const QJsonObject jsondata = root["data"].toObject();
    m_total                    = jsondata["total"].toInt();
    const QJsonArray infoObj   = jsondata["info"].toArray();

    auto buildItem = [](const QJsonValue &v) -> QVariantMap {
        const QJsonObject trans_param = v["trans_param"].toObject();
        QString union_cover           = trans_param["union_cover"].toString();
        union_cover.replace("{size}", "720");
        QVariantMap m;
        m["songname"]    = v["songname"].toString();
        m["singername"]  = v["singername"].toString();
        m["duration"]    = SearchComplex::secondsToMinutesSeconds(v["duration"].toInt());
        m["album_name"]  = v["album_name"].toString();
        m["songhash"]    = v["hash"].toString();
        m["union_cover"] = union_cover;
        m["mvhash"]      = v["mvhash"].toString();
        return m;
    };

    const bool appendMode = m_isAppendMode;
    m_isAppendMode        = false;

    if (!appendMode)
    {
        // 新搜索：整体重置，装载第一批（fetchComplexData 已先清空，这里 reset 装入新数据）
        beginResetModel();
        m_items.clear();
        for (const QJsonValue &v : infoObj)
            m_items.append(buildItem(v));
        endResetModel();
    }
    else if (!infoObj.isEmpty())
    {
        // 加载更多：增量插入新行（不重置视图、不弹回顶部、不重建已有 delegate）
        const int first = m_items.size();
        beginInsertRows(QModelIndex(), first, first + infoObj.size() - 1);
        for (const QJsonValue &v : infoObj)
            m_items.append(buildItem(v));
        endInsertRows();
    }

    m_hasMore = m_items.size() < m_total;
    emit totalChanged();
    emit hasMoreChanged();
    emit countChanged();
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

QString SearchComplex::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0);
    time = time.addSecs(totalSeconds);
    return time.toString("mm:ss");
}
