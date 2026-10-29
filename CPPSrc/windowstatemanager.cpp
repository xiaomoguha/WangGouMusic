#include "windowstatemanager.h"

#include "PlaylistCacheStore.h"

#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPoint>
#include <QScreen>

namespace {
// 配置文件名（<缓存目录>/config/ 下）
constexpr auto kConfigFile = "window_config.json";
constexpr auto kKeyX       = "x";
constexpr auto kKeyY       = "y";
} // namespace

WindowStateManager::WindowStateManager(QObject *parent)
    : QObject(parent)
{
    loadConfig();
}

void WindowStateManager::loadConfig()
{
    const QString filePath = PlaylistCacheStore::configPath(QString::fromLatin1(kConfigFile));
    QFile file(filePath);
    if (!file.exists())
        return; // 首次启动：没有记录，交给 QML 走默认居中

    if (!file.open(QIODevice::ReadOnly))
    {
        qWarning() << "[WindowState] 无法读取窗口位置配置:" << filePath;
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    if (!doc.isObject())
    {
        qWarning() << "[WindowState] 窗口位置配置格式错误:" << filePath;
        return;
    }

    const QJsonObject config = doc.object();
    // 两个键必须都在才算有效记录：只有一半说明上次写入被打断
    if (!config.contains(kKeyX) || !config.contains(kKeyY))
        return;

    m_savedX           = config.value(kKeyX).toInt();
    m_savedY           = config.value(kKeyY).toInt();
    m_hasSavedPosition = true;
}

bool WindowStateManager::isSavedPositionOnScreen(int windowWidth, int windowHeight) const
{
    if (!m_hasSavedPosition)
        return false;

    const QPoint center(m_savedX + windowWidth / 2, m_savedY + windowHeight / 2);
    const auto screens = QGuiApplication::screens();
    for (QScreen *screen : screens)
    {
        if (screen && screen->availableGeometry().contains(center))
            return true;
    }
    return false;
}

void WindowStateManager::savePosition(int x, int y)
{
    if (m_hasSavedPosition && x == m_savedX && y == m_savedY)
        return;

    m_savedX           = x;
    m_savedY           = y;
    m_hasSavedPosition = true;

    // 立刻落盘：位置这种"写完就希望留下"的小配置，不值得为了省一次写盘而承担
    // 崩溃/强杀丢数据的风险（调用方已做防抖，拖动过程不会频繁触发）
    PlaylistCacheStore::ensureCacheDir();
    QFile file(PlaylistCacheStore::configPath(QString::fromLatin1(kConfigFile)));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
    {
        qWarning() << "[WindowState] 无法保存窗口位置:" << file.fileName();
        return;
    }

    QJsonObject config;
    config[kKeyX] = m_savedX;
    config[kKeyY] = m_savedY;
    file.write(QJsonDocument(config).toJson(QJsonDocument::Indented));
    file.close();

    emit savedPositionChanged();
}
