#ifndef DOMINANT_COLOR_EXTRACTOR_H
#define DOMINANT_COLOR_EXTRACTOR_H

#include <QObject>
#include <QHash>
#include <QSet>
#include <QMutex>
#include <QString>

/**
 * @brief 专辑封面主色调提取器
 *
 * 从 PlaylistManager 拆分而来。负责：
 *  - 下载/读取封面图片
 *  - 计算主色调（缩放采样 + HSV 增饱和）
 *  - 内存 LRU 缓存（避免对同一封面重复计算）
 *  - 后台线程池执行，结果通过信号回到主线程
 *
 * 调用方（PlaylistManager）connect dominantColorReady 到自己的 dominantColorChanged。
 */
class DominantColorExtractor : public QObject
{
    Q_OBJECT
public:
    explicit DominantColorExtractor(QObject *parent = nullptr);

    /// 提取指定封面图的主色调。结果通过 dominantColorReady 信号异步返回；
    /// 空 URL / 缓存命中时同步发射。
    void extract(const QString &imageUrl);

signals:
    /// 主色调就绪（hex color，如 "#FF6B6B"）
    void dominantColorReady(const QString &hexColor);

private:
    void cacheAndEmit(const QString &imageUrl, const QString &color);

    // LRU 缓存：URL -> hex color（容量上限 64）
    QHash<QString, QString> m_colorCache;
    // 进行中的请求去重
    QSet<QString> m_pendingColorRequests;
    QMutex m_colorCacheMutex;
};

#endif // DOMINANT_COLOR_EXTRACTOR_H
