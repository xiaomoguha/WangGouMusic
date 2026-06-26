#ifndef SEARCHCOMPLEX_H
#define SEARCHCOMPLEX_H

#include <QObject>
#include <QJsonObject>
#include <QString>
#include <QVariantList>
#include <functional>

/**
 * @brief 复杂搜索（关键词搜索歌曲）
 *
 * 内部已迁移到 ApiClient 单例，不再持有 QNetworkAccessManager。
 * 外部信号/属性保持不变。
 */
class SearchComplex : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ getcomplexsearchitems NOTIFY complexsearchitemsChanged)
    Q_PROPERTY(int total READ gettotal NOTIFY totalChanged)
    Q_PROPERTY(int page READ getPage NOTIFY pageChanged)
    Q_PROPERTY(bool hasMore READ getHasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(bool isLoading READ getIsLoading NOTIFY isLoadingChanged)
public:
    explicit SearchComplex(QObject *parent = nullptr);
    Q_INVOKABLE void fetchComplexData(const QString &keyword);
    Q_INVOKABLE void fetchMore();
    QVariantList getcomplexsearchitems() const;
    int gettotal() const;
    int getPage() const;
    bool getHasMore() const;
    bool getIsLoading() const;

signals:
    void complexsearchitemsChanged();
    void totalChanged();
    void pageChanged();
    void hasMoreChanged();
    void isLoadingChanged();
    void loadFinished();

private:
    void parseAndAppend(const QJsonObject &root, bool isAppend);
    static QString secondsToMinutesSeconds(int totalSeconds);

    QVariantList m_items;
    int m_total = 0;
    int m_page = 1;
    bool m_hasMore = false;
    bool m_isLoading = false;
    bool m_isAppendMode = false;
    QString m_currentKeyword;
    static const int PAGE_SIZE = 20;
};

#endif // SEARCHCOMPLEX_H
