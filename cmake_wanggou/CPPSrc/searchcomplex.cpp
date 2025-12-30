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
        qWarning() << "Empty URL provided";
        return;
    }
    QNetworkRequest request = QNetworkRequest(QUrl("http://47.112.6.94:3000/search?keywords="+keyword+"&page=1"));
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
void SearchComplex::onReplyFinished(QNetworkReply *reply)
{
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
    // 提取基本字段
    int errorCode = root["errcode"].toInt();
    if(errorCode!=0)
    {
        qWarning() << "errcode:" << errorCode;
        reply->deleteLater();
        return;
    }
    // 清空或初始化 m_items
    m_items.clear();

    // 提取data数组
    QJsonObject jsondata = root["data"].toObject();
    const int total = jsondata["total"].toInt();             //搜索结果个数
    const QJsonArray infoObj = jsondata["info"].toArray();

    m_total = total;
    // 遍历每条记录
    for (const QJsonValue &infoValues : infoObj)
    {
        const QString songname = infoValues["songname"].toString();         //歌曲名字
        const QString singername = infoValues["singername"].toString();     //歌手名字
        const int duration = infoValues["duration"].toInt();                //总时长
        const QString durationstr = secondsToMinutesSeconds(duration);
        const QString album_name = infoValues["album_name"].toString();     //专辑名字
        const QString songhash = infoValues["hash"].toString();             //歌曲hash值

        const QJsonObject trans_param = infoValues["trans_param"].toObject();
        QString union_cover = trans_param["union_cover"].toString();  //封面图

        QVariantMap item;
        item["songname"] = songname;
        item["singername"] = singername;
        item["duration"] = durationstr;
        item["album_name"] = album_name;
        item["songhash"] = songhash;
        item["union_cover"] = union_cover.replace("{size}","768");

        m_items.append(item);  // 添加到 QVariantList
    }
    // 通知 QML 数据已更新
    emit complexsearchitemsChanged();
    emit totalChanged();
    reply->deleteLater();
}

QString SearchComplex::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0); // 初始化为 00:00:00
    time = time.addSecs(totalSeconds); // 添加秒数
    return time.toString("mm:ss"); // 格式化为 "分钟:秒"
}
