#ifndef DOMINANT_COLOR_EXTRACTOR_H
#define DOMINANT_COLOR_EXTRACTOR_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QMutex>
#include <QString>

// 专辑封面主色调提取器
class DominantColorExtractor : public QObject
{
    Q_OBJECT
public:
    explicit DominantColorExtractor(QObject *parent = nullptr);

    // 提取指定封面图的主色调。结果通过 dominantColorReady 信号异步返回；
    Q_INVOKABLE void extract(const QString &imageUrl);

signals:
    // 主色调就绪（imageUrl = 本次提取的封面，hex color 如 "#FF6B6B"）
    void dominantColorReady(const QString &imageUrl, const QString &hexColor);

private:
    void cacheAndEmit(const QString &imageUrl, const QString &color);

    // LRU 缓存：URL -> hex color（容量上限 64）
    QHash<QString, QString> m_colorCache;
    // 进行中的请求去重
    QSet<QString> m_pendingColorRequests;
    QMutex m_colorCacheMutex;
};

#endif // DOMINANT_COLOR_EXTRACTOR_H
