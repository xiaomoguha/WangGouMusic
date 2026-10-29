#ifndef WINDOWSTATEMANAGER_H
#define WINDOWSTATEMANAGER_H

#include <QObject>

// 主窗口位置记忆：窗口坐标存本地配置文件 <缓存目录>/config/window_config.json，
// 下次启动恢复到原位；没有记录时由 QML 走默认居中。
//
// 为什么"记录是否还有效"的判断放在 C++：QML 的 Screen 附加属性只能拿到窗口当前
// 所在那一块屏幕，要枚举全部屏幕得绕 Qt.application.screens；C++ 用
// QGuiApplication::screens() 直接判窗口中心点是否落在某块屏幕内。
class WindowStateManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasSavedPosition READ hasSavedPosition NOTIFY savedPositionChanged)
    Q_PROPERTY(int savedX READ savedX NOTIFY savedPositionChanged)
    Q_PROPERTY(int savedY READ savedY NOTIFY savedPositionChanged)

public:
    explicit WindowStateManager(QObject *parent = nullptr);

    bool hasSavedPosition() const
    {
        return m_hasSavedPosition;
    }
    int savedX() const
    {
        return m_savedX;
    }
    int savedY() const
    {
        return m_savedY;
    }

    // 记录的位置是否仍落在某块屏幕的可用区域内（以窗口中心点判断）。
    // 不依赖屏幕名/索引：外接屏改分辨率、改名字都不会误判；屏幕被拔掉则返回 false，
    // 调用方退回默认居中，避免窗口开在看不见的地方。
    Q_INVOKABLE bool isSavedPositionOnScreen(int windowWidth, int windowHeight) const;

    Q_INVOKABLE void savePosition(int x, int y);

signals:
    void savedPositionChanged();

private:
    void loadConfig();

    bool m_hasSavedPosition = false;
    int m_savedX            = 0;
    int m_savedY            = 0;
};

#endif // WINDOWSTATEMANAGER_H
