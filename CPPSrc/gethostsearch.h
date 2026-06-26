#ifndef GETHOSTSEARCH_H
#define GETHOSTSEARCH_H
#include <QObject>
#include <QString>
#include <QVariantList>
#include <functional>

/**
 * @brief 热搜词获取
 *
 * 内部已迁移到 ApiClient 单例，不再持有 QNetworkAccessManager。
 * 外部信号/属性保持不变。
 */
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

private:
    QVariantList m_items;
};

#endif // GETHOSTSEARCH_H
