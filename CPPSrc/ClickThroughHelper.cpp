#include "ClickThroughHelper.h"
#include <QCursor>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#elif defined(Q_OS_MAC)
#import <Cocoa/Cocoa.h>
#endif

ClickThroughHelper::ClickThroughHelper(QObject *parent) : QObject(parent)
{
    m_timer.setInterval(50);
    connect(&m_timer, &QTimer::timeout, this, &ClickThroughHelper::poll);
}

void ClickThroughHelper::setWindow(QWindow *window)
{
    m_window = window;
}

void ClickThroughHelper::setCaptureRegion(int x, int y, int w, int h)
{
    m_captureRegion = QRect(x, y, w, h);
    m_hasRegion     = true;
}

void ClickThroughHelper::clearCaptureRegion()
{
    m_hasRegion = false;
}

void ClickThroughHelper::setMonitorRegion(int x, int y, int w, int h)
{
    m_monitorRegion = QRect(x, y, w, h);
}

void ClickThroughHelper::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;

    if (enabled)
    {
        applyPassThrough(true);
        m_timer.start();
    }
    else
    {
        m_timer.stop();
        applyPassThrough(false);
        // 关闭时也通知 QML 隐藏按钮
        if (m_currentlyInside)
        {
            m_currentlyInside = false;
            emit hoverInWindowChanged(false);
        }
    }
}

// ── 50ms 轮询：三态切换 ──
void ClickThroughHelper::poll()
{
    if (!m_window || !m_hasRegion)
        return;

    const QPoint mouse = QCursor::pos();

    // ── 1. 检测鼠标是否在锁按钮区域（状态3.）──
    const bool inCapture = m_captureRegion.contains(mouse);
    if (inCapture && m_currentlyPassing)
    {
        applyPassThrough(false);
    }
    else if (!inCapture && !m_currentlyPassing)
    {
        applyPassThrough(true);
    }

    // ── 2. 检测鼠标是否在窗口区域内（状态2.）──
    const bool inWindow = m_monitorRegion.contains(mouse);
    if (inWindow != m_currentlyInside)
    {
        m_currentlyInside = inWindow;
        emit hoverInWindowChanged(inWindow);
    }
}

// ── 平台原生：设置窗口是否鼠标穿透 ──
void ClickThroughHelper::applyPassThrough(bool pass)
{
    if (m_currentlyPassing == pass)
        return;
    m_currentlyPassing = pass;
    if (!m_window)
        return;

    emit passThroughChanged(pass);

#ifdef Q_OS_WIN
    HWND hwnd        = (HWND)m_window->winId();
    LONG_PTR exStyle = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    if (pass)
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, exStyle | WS_EX_TRANSPARENT);
    else
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, exStyle & ~WS_EX_TRANSPARENT);

#elif defined(Q_OS_MAC)
    NSView *view = (__bridge NSView *)reinterpret_cast<void *>(m_window->winId());
    if (view && view.window)
    {
        [view.window setIgnoresMouseEvents:pass];
    }
#endif
}
