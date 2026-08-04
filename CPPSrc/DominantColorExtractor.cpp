#include "DominantColorExtractor.h"

#include <QEventLoop>
#include <QImage>
#include <QMediaPlayer> // 仅为触发 QImage 完整包含（实际只需 QImage）
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRunnable>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>

namespace
{

constexpr int kCacheCapacity = 64;
const QString kFallbackColor = QStringLiteral("#FF6B6B");

// 算法核心：缩放 + 过滤 + 取平均 + HSV 增饱和
// 作为匿名命名空间自由函数，供 ColorExtractTask 和 DominantColorExtractor 共用
QString computeColor(const QImage &image)
{
    if (image.isNull())
        return kFallbackColor;

    QImage small = image.scaled(50, 50, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    // 全图平均会把黑边/白字/暗灰混进主色导致色相失真。
    // 改为：同时统计全像素与「有彩色像素」（饱和度 ≥50）两套均值，
    // 有彩色像素占比足够时优先用它——那才是视觉主色区域。
    long totalR = 0, totalG = 0, totalB = 0;
    long vividR = 0, vividG = 0, vividB = 0;
    int pixelCount = 0, vividCount = 0;
    for (int y = 0; y < small.height(); ++y)
    {
        for (int x = 0; x < small.width(); ++x)
        {
            QColor color   = small.pixelColor(x, y);
            int brightness = (color.red() + color.green() + color.blue()) / 3;
            // 忽略过暗（<20）或过亮（>235）的像素，避免黑/白边干扰
            if (brightness <= 20 || brightness >= 235)
                continue;
            totalR += color.red();
            totalG += color.green();
            totalB += color.blue();
            ++pixelCount;
            int h, s, v;
            color.getHsv(&h, &s, &v);
            if (s >= 50)
            {
                vividR += color.red();
                vividG += color.green();
                vividB += color.blue();
                ++vividCount;
            }
        }
    }
    if (pixelCount == 0)
        return kFallbackColor;

    // 有彩色像素占比 ≥1/7 时优先用它们（黑边白字不参与）；纯黑白封面退回全像素平均
    const bool useVivid = vividCount > 0 && vividCount * 7 >= pixelCount;
    const long r = useVivid ? vividR / vividCount : totalR / pixelCount;
    const long g = useVivid ? vividG / vividCount : totalG / pixelCount;
    const long b = useVivid ? vividB / vividCount : totalB / pixelCount;

    QColor avg(static_cast<int>(r), static_cast<int>(g), static_cast<int>(b));
    int h, s, v;
    avg.getHsv(&h, &s, &v);
    // 增强让主色更鲜活（vivid 分支本身已高饱和，统一小幅增强）
    s = qMin(255, s + 60); // 提高饱和度
    v = qMin(255, v + 40); // 提高亮度
    QColor finalColor;
    finalColor.setHsv(h, s, v);
    return finalColor.name(QColor::HexRgb).toUpper();
}

// 后台任务：下载网络图片并计算主色调（运行在线程池工作线程）
class ColorExtractTask : public QRunnable
{
public:
    ColorExtractTask(const QString &url, std::function<void(const QString &, const QString &)> cb)
        : m_url(url), m_cb(std::move(cb))
    {
    }

    void run() override
    {
        QString resultColor = kFallbackColor;
        QNetworkAccessManager nam;
        // 必须设超时：缺省无超时，网络挂起会永久占用线程池线程，任务越积越多
        // 全部卡死（曾导致取色大量 fallback 粉色）。transferTimeout 只覆盖传输
        // 阶段，连接/DNS 挂起不受管 → 用 QTimer + abort() 强制打断任何阶段。
        QNetworkRequest request{QUrl(m_url)};
        request.setTransferTimeout(6000);
        QNetworkReply *reply = nam.get(request);
        if (!reply)
        {
            m_cb(m_url, resultColor);
            return;
        }

        QTimer timer;
        timer.setSingleShot(true);
        QObject::connect(&timer, &QTimer::timeout, reply, &QNetworkReply::abort);
        timer.start(6000);

        QEventLoop loop;
        QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        loop.exec();

        if (reply->error() == QNetworkReply::NoError)
        {
            QImage image = QImage::fromData(reply->readAll());
            if (!image.isNull())
                resultColor = computeColor(image);
        }
        reply->deleteLater();
        m_cb(m_url, resultColor);
    }

private:
    QString m_url;
    std::function<void(const QString &, const QString &)> m_cb;
};

} // namespace

DominantColorExtractor::DominantColorExtractor(QObject *parent) : QObject(parent) {}

// 写入 LRU 缓存并发射信号（主线程调用）
void DominantColorExtractor::cacheAndEmit(const QString &imageUrl, const QString &color)
{
    {
        QMutexLocker lock(&m_colorCacheMutex);
        m_pendingColorRequests.remove(imageUrl);
        if (m_colorCache.size() >= kCacheCapacity)
            m_colorCache.erase(m_colorCache.begin());
        m_colorCache.insert(imageUrl, color);
    }
    emit dominantColorReady(color);
}

void DominantColorExtractor::extract(const QString &imageUrl)
{
    if (imageUrl.isEmpty())
    {
        emit dominantColorReady(kFallbackColor);
        return;
    }

    // 1. LRU 命中
    {
        QMutexLocker lock(&m_colorCacheMutex);
        if (m_colorCache.contains(imageUrl))
        {
            emit dominantColorReady(m_colorCache.value(imageUrl));
            return;
        }
    }

    // 2. 去重：已有进行中的请求则跳过
    {
        QMutexLocker lock(&m_colorCacheMutex);
        if (m_pendingColorRequests.contains(imageUrl))
            return;
        m_pendingColorRequests.insert(imageUrl);
    }

    // 3. 本地 qrc 资源：直接读（同步很快）
    if (imageUrl.startsWith(QStringLiteral("qrc:/")))
    {
        QString path = imageUrl;
        path.remove(QStringLiteral("qrc:"));
        QImage image(path);
        cacheAndEmit(imageUrl, image.isNull() ? kFallbackColor : computeColor(image));
        return;
    }

    // 4. 本地文件路径：直接读
    if (!imageUrl.startsWith(QStringLiteral("http://")) && !imageUrl.startsWith(QStringLiteral("https://")))
    {
        QImage image(imageUrl);
        cacheAndEmit(imageUrl, image.isNull() ? kFallbackColor : computeColor(image));
        return;
    }

    // 5. 网络图片：丢到后台线程池
    auto *task = new ColorExtractTask(
        imageUrl,
        [this](const QString &url, const QString &color)
        {
            QMutexLocker lock(&m_colorCacheMutex);
            m_pendingColorRequests.remove(url);
            if (m_colorCache.size() >= kCacheCapacity)
                m_colorCache.erase(m_colorCache.begin());
            m_colorCache.insert(url, color);
            // 回到主线程发射信号
            QMetaObject::invokeMethod(this, [this, color]() { emit dominantColorReady(color); }, Qt::QueuedConnection);
        }
    );
    QThreadPool::globalInstance()->start(task);
}
