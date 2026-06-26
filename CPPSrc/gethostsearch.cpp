#include "gethostsearch.h"
#include "ApiClient.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

GetHostSearch::GetHostSearch(QObject *parent) : QObject{parent}
{
}

void GetHostSearch::fetchhostserachData(const QString &url)
{
    if (url.isEmpty()) {
        qWarning() << "Empty URL provided";
        return;
    }

    ApiClient::instance().getJson(url,
        [this](QJsonObject root) {
            const int errorCode = root["errcode"].toInt();
            if (errorCode != 0) {
                qWarning() << "[GetHostSearch] errcode:" << errorCode;
                return;
            }
            m_items.clear();

            const QJsonObject jsondata = root["data"].toObject();
            const QJsonArray categoryObj = jsondata["list"].toArray();
            if (categoryObj.isEmpty()) {
                emit hostsearchitemsChanged();
                return;
            }
            const QJsonObject hostsearchdata = categoryObj[0].toObject();
            const QJsonArray keywords = hostsearchdata["keywords"].toArray();

            for (const QJsonValue &keywordValue : keywords) {
                const QString keyword = keywordValue.toObject()["keyword"].toString();
                QVariantMap item;
                item["keyword"] = keyword;
                m_items.append(item);
            }
            emit hostsearchitemsChanged();
        },
        [this](QString err, int code) {
            Q_UNUSED(code);
            qWarning() << "[GetHostSearch] fetch error:" << err;
        },
        10000);
}

QVariantList GetHostSearch::gethostserachitems() const
{
    return m_items;
}
