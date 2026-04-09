#include "lyricsconfigmanager.h"
#include <QGuiApplication>
#include <QScreen>

LyricsConfigManager::LyricsConfigManager(QObject *parent)
    : QObject(parent)
{
    // 获取屏幕尺寸
    QScreen *screen = QGuiApplication::primaryScreen();
    if (screen)
    {
        QRect screenGeometry = screen->availableGeometry();
        m_screenWidth = screenGeometry.width();
        m_screenHeight = screenGeometry.height();
    }

    // 设置默认位置
    // 横向模式：屏幕下方居中，离底部有一定距离
    m_horizontalX = (m_screenWidth - m_horizontalWidth) / 2;
    m_horizontalY = m_screenHeight - m_horizontalHeight - 50;

    // 竖向模式：屏幕右侧居中，离右边有一定距离
    m_verticalX = m_screenWidth - m_verticalWidth - 20;
    m_verticalY = (m_screenHeight - m_verticalHeight) / 2;

    // 启动时自动加载配置
    loadConfig();
}

LyricsConfigManager::~LyricsConfigManager()
{
    // 析构时自动保存配置
    saveConfig();
}

QString LyricsConfigManager::getConfigFilePath()
{
    QString cacheDir;
#ifdef Q_OS_WIN
    cacheDir = "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    cacheDir = downloadsPath + "/网狗音乐缓存目录";
#endif
    return cacheDir + "/lyrics_config.json";
}

void LyricsConfigManager::ensureConfigDirExists()
{
    QString cacheDir;
#ifdef Q_OS_WIN
    cacheDir = "C:/网狗音乐缓存目录";
#elif defined(Q_OS_MAC)
    QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    cacheDir = downloadsPath + "/网狗音乐缓存目录";
#endif
    QDir dir(cacheDir);
    if (!dir.exists())
    {
        dir.mkpath(".");
    }
}

void LyricsConfigManager::saveConfig()
{
    ensureConfigDirExists();

    QJsonObject config;
    // 横向模式
    QJsonObject horizontal;
    horizontal["x"] = m_horizontalX;
    horizontal["y"] = m_horizontalY;
    horizontal["width"] = m_horizontalWidth;
    horizontal["height"] = m_horizontalHeight;
    config["horizontal"] = horizontal;

    // 竖向模式
    QJsonObject vertical;
    vertical["x"] = m_verticalX;
    vertical["y"] = m_verticalY;
    vertical["width"] = m_verticalWidth;
    vertical["height"] = m_verticalHeight;
    config["vertical"] = vertical;

    // 通用配置
    config["locked"] = m_locked;
    config["isVertical"] = m_isVertical;
    config["scale"] = m_scale;
    config["fontSize"] = m_fontSize;
    config["isDark"] = m_isDark;

    // 写入文件
    QString filePath = getConfigFilePath();
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly))
    {
        QJsonDocument doc(config);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        qDebug() << "歌词配置已保存到:" << filePath;
    }
    else
    {
        qWarning() << "无法保存歌词配置到:" << filePath;
    }
}

void LyricsConfigManager::loadConfig()
{
    QString filePath = getConfigFilePath();
    QFile file(filePath);

    if (!file.exists())
    {
        qDebug() << "歌词配置文件不存在，使用默认值";
        return;
    }

    if (file.open(QIODevice::ReadOnly))
    {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (doc.isNull())
        {
            qWarning() << "歌词配置文件格式错误";
            return;
        }

        QJsonObject config = doc.object();

        // 读取横向模式配置
        if (config.contains("horizontal"))
        {
            QJsonObject horizontal = config["horizontal"].toObject();
            m_horizontalX = horizontal["x"].toInt(m_horizontalX);
            m_horizontalY = horizontal["y"].toInt(m_horizontalY);
            m_horizontalWidth = horizontal["width"].toInt(m_horizontalWidth);
            m_horizontalHeight = horizontal["height"].toInt(m_horizontalHeight);
        }

        // 读取竖向模式配置
        if (config.contains("vertical"))
        {
            QJsonObject vertical = config["vertical"].toObject();
            m_verticalX = vertical["x"].toInt(m_verticalX);
            m_verticalY = vertical["y"].toInt(m_verticalY);
            m_verticalWidth = vertical["width"].toInt(m_verticalWidth);
            m_verticalHeight = vertical["height"].toInt(m_verticalHeight);
        }

        // 读取通用配置
        m_locked = config["locked"].toBool(m_locked);
        m_isVertical = config["isVertical"].toBool(m_isVertical);
        m_scale = config["scale"].toDouble(m_scale);
        m_fontSize = config["fontSize"].toInt(m_fontSize);
        m_isDark = config["isDark"].toBool(m_isDark);

        qDebug() << "歌词配置已加载:" << filePath;
        emit configChanged();
    }
}

void LyricsConfigManager::resetToDefaults()
{
    // 横向模式：屏幕下方居中
    m_horizontalX = (m_screenWidth - 600) / 2;
    m_horizontalY = m_screenHeight - 150 - 50;
    m_horizontalWidth = 600;
    m_horizontalHeight = 150;

    // 竖向模式：屏幕右侧居中
    m_verticalX = m_screenWidth - 180 - 20;
    m_verticalY = (m_screenHeight - 300) / 2;
    m_verticalWidth = 180;
    m_verticalHeight = 300;

    // 通用
    m_locked = false;
    m_isVertical = false;
    m_scale = 1.0;
    m_fontSize = 22;

    emit configChanged();
}

// 横向模式 setters
void LyricsConfigManager::setHorizontalX(int value)
{
    if (m_horizontalX != value)
    {
        m_horizontalX = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setHorizontalY(int value)
{
    if (m_horizontalY != value)
    {
        m_horizontalY = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setHorizontalWidth(int value)
{
    if (m_horizontalWidth != value)
    {
        m_horizontalWidth = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setHorizontalHeight(int value)
{
    if (m_horizontalHeight != value)
    {
        m_horizontalHeight = value;
        emit configChanged();
    }
}

// 竖向模式 setters
void LyricsConfigManager::setVerticalX(int value)
{
    if (m_verticalX != value)
    {
        m_verticalX = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setVerticalY(int value)
{
    if (m_verticalY != value)
    {
        m_verticalY = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setVerticalWidth(int value)
{
    if (m_verticalWidth != value)
    {
        m_verticalWidth = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setVerticalHeight(int value)
{
    if (m_verticalHeight != value)
    {
        m_verticalHeight = value;
        emit configChanged();
    }
}

// 通用 setters
void LyricsConfigManager::setLocked(bool value)
{
    if (m_locked != value)
    {
        m_locked = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setIsVertical(bool value)
{
    if (m_isVertical != value)
    {
        m_isVertical = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setScale(qreal value)
{
    if (!qFuzzyCompare(m_scale, value))
    {
        m_scale = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setFontSize(int value)
{
    if (m_fontSize != value)
    {
        m_fontSize = value;
        emit configChanged();
    }
}
void LyricsConfigManager::setIsDark(bool value)
{
    if (m_isDark != value)
    {
        m_isDark = value;
        emit configChanged();
    }
}
