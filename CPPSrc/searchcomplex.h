#ifndef SEARCHCOMPLEX_H
#define SEARCHCOMPLEX_H

#include <QAbstractListModel>
#include <QJsonObject>
#include <QString>
#include <QVariantMap>

// 复杂搜索（关键词搜索歌曲）
class SearchComplex : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int total READ gettotal NOTIFY totalChanged)
    Q_PROPERTY(int page READ getPage NOTIFY pageChanged)
    Q_PROPERTY(bool hasMore READ getHasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool isLoading READ getIsLoading NOTIFY isLoadingChanged)
public:
    enum Roles
    {
        SongnameRole = Qt::UserRole + 1,
        SingernameRole,
        DurationRole,
        AlbumNameRole,
        SonghashRole,
        UnionCoverRole,
        MvhashRole,
    };
    Q_ENUM(Roles)

    explicit SearchComplex(QObject *parent = nullptr);
    Q_INVOKABLE void fetchComplexData(const QString &keyword);
    Q_INVOKABLE void fetchMore();

    // ── QAbstractListModel ──
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const
    {
        return m_items.size();
    }
    int gettotal() const;
    int getPage() const;
    bool getHasMore() const;
    bool getIsLoading() const;

signals:
    void totalChanged();
    void pageChanged();
    void hasMoreChanged();
    void isLoadingChanged();
    void countChanged();
    void loadFinished();

private:
    void parseAndAppend(const QJsonObject &root, bool isAppend);
    static QString secondsToMinutesSeconds(int totalSeconds);

    QList<QVariantMap> m_items;
    int m_total         = 0;
    int m_page          = 1;
    bool m_hasMore      = false;
    bool m_isLoading    = false;
    bool m_isAppendMode = false;
    QString m_currentKeyword;
    int m_requestSeq = 0;   // 新搜索/翻页时丢弃过期响应
    static const int PAGE_SIZE = 20;
};

#endif // SEARCHCOMPLEX_H
