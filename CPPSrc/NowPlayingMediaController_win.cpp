// Windows 系统媒体传输控件（SystemMediaTransportControls, SMTC）接入：
// 任务栏/锁屏媒体控件、键盘媒体键。与 macOS 的 NowPlayingMediaController.mm 同构。
//
// 构建要求：MSVC + Windows 10 SDK（10.0.19041+）自带的 C++/WinRT 头（cppwinrt），
// 链接 runtimeobject.lib（已在 CMakeLists 的 WIN32 块配置）。
//
// Q_OS_WIN 由 <QtGlobal>（经任意 Qt 头引入）定义。下面的 #ifdef Q_OS_WIN 必须在包含
// Qt 头之后才成立——否则 Q_OS_WIN 尚未定义，整份文件被预处理为空，
// NowPlayingMediaController 的构造/析构符号不会被编译出来，导致 LNK2001。
#include <QtGlobal>

#ifdef Q_OS_WIN

// C++/WinRT 要求在包含 winrt/base.h 之前定义 NOMINMAX：否则 windows.h 的
// min/max 宏会污染全局，破坏 winrt 模板里的 std::min/std::max 导致编译失败。
// 同样需要 WIN32_LEAN_AND_MEAN 减少不必要的 windows.h 子集。
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
// C++/WinRT 依赖 <experimental/coroutine>，MSVC 14.5x 将其标记为废弃并
// 用 static_assert 阻断编译。此处静默该警告以维持 winrt 头可用。
#ifndef _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
#define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
#endif

#include "NowPlayingMediaController.h"
#include "playlistmanager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QMetaObject>
#include <QString>
#include <QWindow>

#include <windows.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>
#include <systemmediatransportcontrolsinterop.h>

using namespace winrt;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Media;
using namespace winrt::Windows::Storage::Streams;

namespace {
struct WinImpl {
    SystemMediaTransportControls smtc{ nullptr };
    QString cachedCoverUrl;   // 封面 URL 变化才换缩略图，避免反复重建
};

inline hstring toHstring(const QString &s) {
    return hstring(reinterpret_cast<const wchar_t *>(s.utf16()));
}

double parseDurationSec(const QString &s) {
    if (s.contains(QLatin1Char(':'))) {
        const auto parts = s.split(QLatin1Char(':'));
        if (parts.size() == 2)
            return parts[0].toInt() * 60.0 + parts[1].toInt();
    }
    return s.toDouble();
}

// TimeSpan 是 100ns 单位的 int64；brace-init 在「裸 struct」与「chrono duration」两种
// C++/WinRT 投影形态下都能编过。
inline TimeSpan secondsToTimeSpan(double sec) {
    return TimeSpan{ static_cast<int64_t>(sec * 10000000.0) };
}

// SMTC 必须在持有窗口的 UI 线程上获取，且需要窗口已存在，因此延迟到首次
// updateNowPlaying（播放开始后）再初始化。失败被 catch，不影响主程序。
// 主窗口 HWND：桌面(Win32)程序没有 CoreWindow 视图，必须用 GetForWindow 把 SMTC 绑到 HWND，
// 否则 GetForCurrentView() 会报"找不到要与此 MediaPlaybackControl 实例关联的相应视图"。
// 选普通顶层窗口（排除桌面歌词等 Qt::Tool 工具窗口）；窗口尚未就绪时返回 nullptr，下次播放再试。
HWND findMainWindowHwnd() {
    const auto wins = QGuiApplication::topLevelWindows();
    for (QWindow *w : wins) {
        if (!w->isVisible() || w->flags().testFlag(Qt::Tool))
            continue;
        const WId id = w->winId();
        if (id)
            return reinterpret_cast<HWND>(id);
    }
    // 退路：任一可见顶层窗口
    for (QWindow *w : wins) {
        if (w->isVisible() && w->winId())
            return reinterpret_cast<HWND>(w->winId());
    }
    return nullptr;
}

void ensureSmtc(WinImpl *impl, PlaylistManager *pm) {
    if (!impl || impl->smtc) return;
    try {
        HWND hwnd = findMainWindowHwnd();
        if (!hwnd)
            return;
        auto factory = winrt::get_activation_factory<SystemMediaTransportControls>();
        auto interop = factory.as<ISystemMediaTransportControlsInterop>();
        const winrt::guid iid = winrt::guid_of<SystemMediaTransportControls>();
        SystemMediaTransportControls smtc{ nullptr };
        winrt::check_hresult(interop->GetForWindow(hwnd, reinterpret_cast<const GUID&>(iid), winrt::put_abi(smtc)));
        if (!smtc)
            return;
        smtc.IsEnabled(true);
        smtc.IsPlayEnabled(true);
        smtc.IsPauseEnabled(true);
        smtc.IsNextEnabled(true);
        smtc.IsPreviousEnabled(true);
        // ponytail: 系统回调线程不可控，统一用 QueuedConnection 派发回主线程操作播放器
        smtc.ButtonPressed([pm](SystemMediaTransportControls const &,
                                SystemMediaTransportControlsButtonPressedEventArgs const &args) {
            switch (args.Button()) {
            case SystemMediaTransportControlsButton::Play:
                QMetaObject::invokeMethod(qApp, [pm] { pm->setPaused(false); }, Qt::QueuedConnection);
                break;
            case SystemMediaTransportControlsButton::Pause:
                QMetaObject::invokeMethod(qApp, [pm] { pm->setPaused(true); }, Qt::QueuedConnection);
                break;
            case SystemMediaTransportControlsButton::Next:
                QMetaObject::invokeMethod(qApp, [pm] { pm->playNext(); }, Qt::QueuedConnection);
                break;
            case SystemMediaTransportControlsButton::Previous:
                QMetaObject::invokeMethod(qApp, [pm] { pm->playPrevious(); }, Qt::QueuedConnection);
                break;
            default:
                break;
            }
        });
        impl->smtc = smtc;
    } catch (const hresult_error &e) {
        qWarning() << "SMTC init failed:" << QString::fromWCharArray(e.message().c_str());
    }
}
} // namespace

NowPlayingMediaController::NowPlayingMediaController(PlaylistManager *pm, QObject *parent)
    : QObject(parent), m_playlistManager(pm)
{
    // Qt 已以 STA（OleInitialize）初始化主线程 COM；此处再以 single_threaded 初始化
    // 通常返回 S_FALSE，仅作保险。若抛 RPC_E_CHANGED_MODE 也忽略。
    try {
        init_apartment(apartment_type::single_threaded);
    } catch (...) {
    }

    m_impl = new WinImpl();

    connect(m_playlistManager, &PlaylistManager::currentSongChanged, this, &NowPlayingMediaController::updateNowPlaying);
    connect(m_playlistManager, &PlaylistManager::isPausedChanged, this, &NowPlayingMediaController::updateNowPlaying);
    connect(m_playlistManager, &PlaylistManager::durationChanged, this, &NowPlayingMediaController::updateNowPlaying);
}

NowPlayingMediaController::~NowPlayingMediaController()
{
    auto *impl = static_cast<WinImpl *>(m_impl);
    if (impl) {
        if (impl->smtc) {
            try { impl->smtc.PlaybackStatus(MediaPlaybackStatus::Closed); } catch (...) {}
        }
        delete impl;
    }
    m_impl = nullptr;
}

void NowPlayingMediaController::updateNowPlaying()
{
    auto *impl = static_cast<WinImpl *>(m_impl);
    if (!impl) return;
    ensureSmtc(impl, m_playlistManager);
    if (!impl->smtc) return;
    const auto smtc = impl->smtc;

    try {
        const QString title = m_playlistManager->currentTitle();
        const QString artist = m_playlistManager->currentsingername();
        const QString cover = m_playlistManager->union_cover();
        const float percent = m_playlistManager->getpercent();
        const bool paused = m_playlistManager->isPaused();
        const double dur = parseDurationSec(m_playlistManager->durationstr());

        auto updater = smtc.DisplayUpdater();
        updater.Type(MediaPlaybackType::Music);
        auto props = updater.MusicProperties();
        props.Title(toHstring(title));
        props.Artist(toHstring(artist));

        if (!cover.isEmpty() && cover != impl->cachedCoverUrl) {
            impl->cachedCoverUrl = cover;
            try {
                Uri uri{ toHstring(cover) };
                updater.Thumbnail(RandomAccessStreamReference::CreateFromUri(uri));
            } catch (...) {
                // 无效 URL（如 qrc:/ 本地图）：跳过缩略图
            }
        }
        updater.Update();

        smtc.PlaybackStatus(paused ? MediaPlaybackStatus::Paused : MediaPlaybackStatus::Playing);

        // 进度条：系统按 PlaybackStatus 自动外推 Position。仅显示，未启用拖动 seek。
        SystemMediaTransportControlsTimelineProperties tl;
        tl.StartTime(secondsToTimeSpan(0));
        tl.EndTime(secondsToTimeSpan(dur));
        tl.Position(secondsToTimeSpan(percent * dur));
        tl.MinSeekTime(secondsToTimeSpan(0));
        tl.MaxSeekTime(secondsToTimeSpan(dur));
        smtc.UpdateTimelineProperties(tl);
    } catch (const hresult_error &e) {
        qWarning() << "SMTC update failed:" << QString::fromWCharArray(e.message().c_str());
    }
}

void NowPlayingMediaController::clearNowPlaying()
{
    auto *impl = static_cast<WinImpl *>(m_impl);
    if (!impl || !impl->smtc) return;
    try { impl->smtc.PlaybackStatus(MediaPlaybackStatus::Closed); } catch (...) {}
    impl->cachedCoverUrl.clear();
}

#endif // Q_OS_WIN
