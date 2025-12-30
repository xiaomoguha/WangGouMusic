#include "gethostsearch.h"

GetHostSearch::GetHostSearch(QObject *parent): QObject{parent}
{
    connect(&m_manager, &QNetworkAccessManager::finished,
            this, &GetHostSearch::onReplyFinished);
}
void GetHostSearch::fetchhostserachData(const QString &url)
{
    if (url.isEmpty())
    {
        qWarning() << "Empty URL provided";
        return;
    }
    QNetworkRequest request = QNetworkRequest(QUrl(url));
    m_manager.get(request);
}
void GetHostSearch::onReplyFinished(QNetworkReply *reply)
{
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
    // 提取基本字段
    int errorCode = root["errcode"].toInt();
    if(errorCode!=0)
    {
        qWarning() << "errorCode:" << errorCode;
        reply->deleteLater();
        return;
    }
    // 清空或初始化 m_items
    m_items.clear();

    // 提取data数组
    QJsonObject jsondata = root["data"].toObject();
    QJsonArray categoryObj = jsondata["list"].toArray();
    QJsonObject hostsearchdata = categoryObj[0].toObject();
    const QJsonArray keywords = hostsearchdata["keywords"].toArray();
    // 遍历每条记录
    for (const QJsonValue &keywordValue : keywords)
    {
        const QString keyword = keywordValue.toObject()["keyword"].toString();
        QVariantMap item;
        item["keyword"] = keyword;
        m_items.append(item);  // 添加到 QVariantList
    }
    // 通知 QML 数据已更新
    emit hostsearchitemsChanged();
    reply->deleteLater();
}

QVariantList GetHostSearch::gethostserachitems() const
{
    return m_items;
}
