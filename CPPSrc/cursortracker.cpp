#include "cursortracker.h"

#include <QCoreApplication>
#include <QCursor>
#include <QEvent>
#include <QMouseEvent>
#include <QQuickWindow>

namespace {
// 60Hz 采样：足够跟手，QCursor::pos() 开销极低（不碰窗口系统查询）
constexpr int kPollIntervalMs = 16;
}

CursorTracker::CursorTracker(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(kPollIntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &CursorTracker::poll);
    m_timer.start();
}

void CursorTracker::attachWindow(QObject *window)
{
    m_window = window;
    if (qApp && !m_filterInstalled)
    {
        qApp->installEventFilter(this);
        m_filterInstalled = true;
    }
}

bool CursorTracker::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)
    if (event->type() != QEvent::MouseButtonPress)
        return false;

    auto *win = qobject_cast<QQuickWindow *>(m_window);
    if (!win || !win->isVisible())
        return false;

    auto *me = static_cast<QMouseEvent *>(event);
    const QPointF globalPos = me->globalPosition();
    if (!win->geometry().contains(globalPos.toPoint()))
        return false;

    const QPointF local = win->mapFromGlobal(globalPos.toPoint());
    emit pressed(local.x(), local.y());
    return false; // 只旁听，不消费——点击照常到达下面的控件
}

void CursorTracker::poll()
{
    auto *win = qobject_cast<QQuickWindow *>(m_window);
    if (!win)
        return;

    const QPoint globalPos = QCursor::pos();
    const bool visible = win->isVisible();
    const bool inside = visible && win->geometry().contains(globalPos);
    const QPointF local = inside ? QPointF(win->mapFromGlobal(globalPos)) : m_pos;

    if (local != m_pos) {
        m_pos = local;
        emit posChanged();
    }
    if (inside != m_inside) {
        m_inside = inside;
        emit insideWindowChanged();
    }
    const bool active = inside;
    if (active != m_active) {
        m_active = active;
        emit activeChanged();
    }
}
