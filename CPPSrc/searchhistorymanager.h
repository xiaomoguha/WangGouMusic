#ifndef SEARCHHISTORYMANAGER_H
#define SEARCHHISTORYMANAGER_H

#include <QObject>
#include <QStringList>
#include <QVariantList>

/**
 * @brief 搜索历史本地持久化（最多 MAX_HISTORY_SIZE 条）
 *
 * 形状照搬 LyricsConfigManager：QObject + Q_PROPERTY + Q_INVOKABLE，
 * 构造时 load、析构时 save、每次变更也 save。
 * 文件：PlaylistCacheStore::cacheDir() + "/search_history.json"（数组根 JSON）。
 * QML 绑定 searchHistory.history（QString 列表）；调用 addSearch/removeSearch/clearHistory。
 */
class SearchHistoryManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)

public:
    explicit SearchHistoryManager(QObject *parent = nullptr);
    ~SearchHistoryManager();

    QVariantList history() const;

    /// 记录一次搜索：去重后前插（最近搜索置顶），截断到上限，落盘
    Q_INVOKABLE void addSearch(const QString &keyword);
    /// 删除单条
    Q_INVOKABLE void removeSearch(const QString &keyword);
    /// 清空全部
    Q_INVOKABLE void clearHistory();

signals:
    void historyChanged();

private:
    QString filePath() const;
    void load();
    void save();

    QStringList m_history;
    static const int MAX_HISTORY_SIZE = 10;
};

#endif // SEARCHHISTORYMANAGER_H
