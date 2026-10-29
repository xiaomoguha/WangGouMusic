#ifndef CURSORTRACKER_H
#define CURSORTRACKER_H

#include <QObject>
#include <QPointF>
#include <QTimer>

// 全局指针追踪：定时读系统光标位置，换算成主窗口内的局部坐标，供 QML 做
// "指针附近的星点被点亮、轻轻推开"这类联动（见 StarfieldLayer）。
//
// 用 C++ 读指针而不是 QML 的 HoverHandler：联动层不必参与事件分发，而且指针
// 移出窗口/窗口失焦时也有明确状态（active=false），不用靠 enter/exit 推断。
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
