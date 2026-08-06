#ifndef SEARCHCOMPLEX_H
#define SEARCHCOMPLEX_H

#include <QAbstractListModel>
#include <QJsonObject>
#include <QString>
#include <QVariantMap>

/**
 * @brief 复杂搜索（关键词搜索歌曲）
 *
 * 作为 QAbstractListModel 直接供 QML ListView 绑定：
 *  - 新搜索（fetchComplexData）走 beginResetModel → 视图回到顶部（符合新搜索预期）；
 *  - 下拉加载更多（fetchMore）走 beginInsertRows → 增量插入新行，
 *    不重置视图、不弹回顶部、不重建已有 delegate（避免闪烁）。
 *
 * 外部属性 total/page/hasMore/isLoading/count 保持语义不变。
 */
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
    static const int PAGE_SIZE = 20;
};

#endif // SEARCHCOMPLEX_H
