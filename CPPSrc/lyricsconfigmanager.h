#ifndef LYRICSCONFIGMANAGER_H
#define LYRICSCONFIGMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QJsonDocument>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

class LyricsConfigManager : public QObject
{
    Q_OBJECT
    // 横向模式配置
    Q_PROPERTY(int horizontalX READ horizontalX WRITE setHorizontalX NOTIFY configChanged)
    Q_PROPERTY(int horizontalY READ horizontalY WRITE setHorizontalY NOTIFY configChanged)
    Q_PROPERTY(int horizontalWidth READ horizontalWidth WRITE setHorizontalWidth NOTIFY configChanged)
    Q_PROPERTY(int horizontalHeight READ horizontalHeight WRITE setHorizontalHeight NOTIFY configChanged)
    // 竖向模式配置
    Q_PROPERTY(int verticalX READ verticalX WRITE setVerticalX NOTIFY configChanged)
    Q_PROPERTY(int verticalY READ verticalY WRITE setVerticalY NOTIFY configChanged)
    Q_PROPERTY(int verticalWidth READ verticalWidth WRITE setVerticalWidth NOTIFY configChanged)
    Q_PROPERTY(int verticalHeight READ verticalHeight WRITE setVerticalHeight NOTIFY configChanged)
    // 通用配置
    Q_PROPERTY(bool locked READ locked WRITE setLocked NOTIFY configChanged)
    Q_PROPERTY(bool isVertical READ isVertical WRITE setIsVertical NOTIFY configChanged)
    Q_PROPERTY(qreal scale READ scale WRITE setScale NOTIFY configChanged)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY configChanged)
    Q_PROPERTY(bool isDark READ isDark WRITE setIsDark NOTIFY configChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY configChanged)
    Q_PROPERTY(QString lyricsColor READ lyricsColor WRITE setLyricsColor NOTIFY configChanged)
    Q_PROPERTY(QString starColor READ starColor WRITE setStarColor NOTIFY configChanged)
    Q_PROPERTY(bool jumpEnabled READ jumpEnabled WRITE setJumpEnabled NOTIFY configChanged)

public:
    explicit LyricsConfigManager(QObject *parent = nullptr);
    ~LyricsConfigManager();

    // 横向模式
    int horizontalX() const
    {
        return m_horizontalX;
    }
    int horizontalY() const
    {
        return m_horizontalY;
    }
    int horizontalWidth() const
    {
        return m_horizontalWidth;
    }
    int horizontalHeight() const
    {
        return m_horizontalHeight;
    }

    // 竖向模式
    int verticalX() const
    {
        return m_verticalX;
    }
    int verticalY() const
    {
        return m_verticalY;
    }
    int verticalWidth() const
    {
        return m_verticalWidth;
    }
    int verticalHeight() const
    {
        return m_verticalHeight;
    }

    // 通用
    bool locked() const
    {
        return m_locked;
    }
    bool isVertical() const
    {
        return m_isVertical;
    }
    qreal scale() const
    {
        return m_scale;
    }
    int fontSize() const
    {
        return m_fontSize;
    }
    bool isDark() const
    {
        return m_isDark;
    }
    bool enabled() const
    {
        return m_enabled;
    }
    QString lyricsColor() const
    {
        return m_lyricsColor;
    }
    QString starColor() const
    {
        return m_starColor;
    }
    bool jumpEnabled() const
    {
        return m_jumpEnabled;
    }

    // 横向模式 setters
    void setHorizontalX(int value);
    void setHorizontalY(int value);
    void setHorizontalWidth(int value);
    void setHorizontalHeight(int value);

    // 竖向模式 setters
    void setVerticalX(int value);
    void setVerticalY(int value);
    void setVerticalWidth(int value);
    void setVerticalHeight(int value);

    // 通用 setters
    void setLocked(bool value);
    void setIsVertical(bool value);
    void setScale(qreal value);
    void setFontSize(int value);
    void setIsDark(bool value);
    void setEnabled(bool value);
    void setLyricsColor(const QString &value);
    void setStarColor(const QString &value);
    void setJumpEnabled(bool value);

    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void loadConfig();
    Q_INVOKABLE void resetToDefaults();

signals:
    void configChanged();

private:
    QString getConfigFilePath();
    void ensureConfigDirExists();

    // 横向模式默认值
    int m_horizontalX;
    int m_horizontalY;
    int m_horizontalWidth  = 600;
    int m_horizontalHeight = 150;
    // 竖向模式默认值
    int m_verticalX;
    int m_verticalY;
    int m_verticalWidth  = 180;
    int m_verticalHeight = 300;
    // 通用默认值
    bool m_locked     = false;
    bool m_isVertical = false;
    qreal m_scale     = 1.0;
    int m_fontSize    = 22;
    bool m_isDark     = false;
    bool m_enabled    = true;  // 桌面歌词开关
    QString m_lyricsColor;     // 已播歌词颜色，空 = 跟随主题
    QString m_starColor;       // 跳跃歌词(星星+拖尾)颜色，空 = 跟随主题
    bool m_jumpEnabled = true; // 跳跃歌词开关（关=普通刷过，无压扁无星星）

    // 屏幕尺寸缓存
    int m_screenWidth  = 1920;
    int m_screenHeight = 1080;
};

#endif // LYRICSCONFIGMANAGER_H
