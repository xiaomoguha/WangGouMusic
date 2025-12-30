#ifndef GETHOSTSEARCH_H
#define GETHOSTSEARCH_H
#include <QNetworkAccessManager>
#include <QObject>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QString>
class GetHostSearch : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ gethostserachitems NOTIFY hostsearchitemsChanged)

public:
    explicit GetHostSearch(QObject *parent = nullptr);
    Q_INVOKABLE void fetchhostserachData(const QString &url);
    QVariantList gethostserachitems() const;
signals:
    void hostsearchitemsChanged();

private slots:
    void onReplyFinished(QNetworkReply *reply);  // 处理网络响应

private:
    QNetworkAccessManager m_manager;  // Qt内置网络请求管理器
    QVariantList m_items;             // 提供给 QML 的模型数据
};

#endif // GETHOSTSEARCH_H
