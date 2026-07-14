#pragma once

#include <QObject>
#include <QWindow>
#include <QRect>
#include <QTimer>

/**
 * @brief 桌面歌词鼠标穿透控制器（三态模型）
 *
 * 锁定时窗口始终穿透，用 QCursor::pos() 全局轮询实现三态：
 *
 *  ① 鼠标在窗口外        → 全穿透，锁按钮隐藏
 *  ② 鼠标在窗口内但不在锁上 → 全穿透，锁按钮显示（hoverInWindow=true）
 *  ③ 鼠标在锁按钮区域     → 取消穿透，锁按钮可点击
 *
 * 平台原生 API：
 * - Windows: WS_EX_TRANSPARENT
 * - macOS:   NSWindow.setIgnoresMouseEvents
 */
class ClickThroughHelper : public QObject
{
    Q_OBJECT
public:
    explicit ClickThroughHelper(QObject *parent = nullptr);

    void setWindow(QWindow *window);

    /// 设置锁按钮捕获区域（全局屏幕坐标），鼠标在此区域时取消穿透
    Q_INVOKABLE void setCaptureRegion(int x, int y, int w, int h);
    Q_INVOKABLE void clearCaptureRegion();

    /// 设置监控区域（整个窗口），鼠标进入时显示锁按钮（不取消穿透）
    Q_INVOKABLE void setMonitorRegion(int x, int y, int w, int h);

    Q_INVOKABLE void setEnabled(bool enabled);
    Q_INVOKABLE bool isEnabled() const { return m_enabled; }

signals:
    /// 鼠标进入/离开窗口区域（用于控制锁按钮显隐，不影响穿透）
    void hoverInWindowChanged(bool inside);
    /// 穿透状态变化
    void passThroughChanged(bool pass);

private:
    void poll();
    void applyPassThrough(bool pass);

    QWindow *m_window = nullptr;
    QRect    m_captureRegion;   // 锁按钮区域
    QRect    m_monitorRegion;   // 整个窗口区域
    bool     m_hasRegion = false;
    bool     m_enabled = false;
    bool     m_currentlyPassing = false;
    bool     m_currentlyInside = false;
    QTimer   m_timer;
};
