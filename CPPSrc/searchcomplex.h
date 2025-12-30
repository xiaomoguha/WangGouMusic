#ifndef SEARCHCOMPLEX_H
#define SEARCHCOMPLEX_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QString>
class SearchComplex : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ getcomplexsearchitems NOTIFY complexsearchitemsChanged)
    Q_PROPERTY(int total READ gettotal NOTIFY totalChanged)
public:
    explicit SearchComplex(QObject *parent = nullptr);
    Q_INVOKABLE void fetchComplexData(const QString &url);
    QVariantList getcomplexsearchitems() const;
    int gettotal() const;
signals:
    void complexsearchitemsChanged();
    void totalChanged();
    void loadFinished();

private slots:
    void onReplyFinished(QNetworkReply *reply);  // 处理网络响应

private:
    QString secondsToMinutesSeconds(int totalSeconds);
    QNetworkAccessManager m_manager;  // Qt内置网络请求管理器
    QVariantList m_items;             // 提供给 QML 的模型数据
    int m_total =0;
};

#endif // SEARCHCOMPLEX_H
