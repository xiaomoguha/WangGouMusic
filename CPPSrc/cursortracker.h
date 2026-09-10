#ifndef CURSORTRACKER_H
#define CURSORTRACKER_H

#include <QObject>
#include <QPointF>
#include <QTimer>

// 全局指针追踪：定时读系统光标位置，换算成主窗口内的局部坐标，供 QML 绘制
// "跟随鼠标的光源/拖尾"。
//
// 为什么不用 QML 的 HoverHandler：光标光源是一个铺满窗口、位于最上层的覆盖层，
// 它一旦持有 hover 处理器就会独占 hover 事件，把下层卡片/导航的 hover 动效全挡掉。
// 改由 C++ 读指针后，覆盖层不参与任何事件，下层交互完好。
class CursorTracker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QPointF pos READ pos NOTIFY posChanged)                  // 窗口内局部坐标
    Q_PROPERTY(bool insideWindow READ insideWindow NOTIFY insideWindowChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)            // 窗口可见 && 指针在窗口内

public:
    explicit CursorTracker(QObject *parent = nullptr);

    QPointF pos() const { return m_pos; }
    bool insideWindow() const { return m_inside; }
    bool active() const { return m_active; }

    // 由 main.cpp 在主窗口创建后注入，用于坐标换算与可见性判断
    void attachWindow(QObject *window);

signals:
    void posChanged();
    void insideWindowChanged();
    void activeChanged();

private:
    void poll();

    QObject *m_window = nullptr;
    QPointF m_pos;
    bool m_inside = false;
    bool m_active = false;
    QTimer m_timer;
};

#endif // CURSORTRACKER_H
