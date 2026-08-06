#include "searchhistorymanager.h"
#include "PlaylistCacheStore.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>

SearchHistoryManager::SearchHistoryManager(QObject *parent) : QObject(parent)
{
    load();
}

SearchHistoryManager::~SearchHistoryManager()
{
    save();
}

QVariantList SearchHistoryManager::history() const
{
    QVariantList list;
    for (const QString &s : m_history)
        list.append(s);
    return list;
}

void SearchHistoryManager::addSearch(const QString &keyword)
{
    const QString trimmed = keyword.trimmed();
    if (trimmed.isEmpty())
        return;

    // 去重：已存在则移除，随后前插 → 最近搜索置顶
    m_history.removeAll(trimmed);
    m_history.prepend(trimmed);

    // 截断到上限（保留最近的 MAX_HISTORY_SIZE 条）
    while (m_history.size() > MAX_HISTORY_SIZE)
        m_history.removeLast();

    save();
    emit historyChanged();
}

void SearchHistoryManager::removeSearch(const QString &keyword)
{
    if (m_history.removeAll(keyword) > 0)
    {
        save();
        emit historyChanged();
    }
}

void SearchHistoryManager::clearHistory()
{
    if (m_history.isEmpty())
        return;
    m_history.clear();
    save();
    emit historyChanged();
}

QString SearchHistoryManager::filePath() const
{
    return PlaylistCacheStore::configPath("search_history.json");
}

void SearchHistoryManager::load()
{
    QFile file(filePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly))
        return;

    const QByteArray data = file.readAll();
    file.close();

    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray())
    {
        if (!doc.isNull())
            qWarning() << "[SearchHistory] 文件格式错误，期望 JSON 数组:" << filePath();
        return;
    }

    m_history.clear();
    const QJsonArray arr = doc.array();
    for (const QJsonValue &v : arr)
    {
        const QString s = v.toString();
        if (!s.isEmpty())
            m_history.append(s);
    }
    qDebug() << "[SearchHistory] 已加载" << m_history.size() << "条历史";
}

void SearchHistoryManager::save()
{
    PlaylistCacheStore::ensureCacheDir();

    QJsonArray arr;
    for (const QString &s : m_history)
        arr.append(s);

    QFile file(filePath());
    if (file.open(QIODevice::WriteOnly))
    {
        QJsonDocument doc(arr);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
    }
    else
    {
        qWarning() << "[SearchHistory] 无法保存到:" << filePath();
    }
}
