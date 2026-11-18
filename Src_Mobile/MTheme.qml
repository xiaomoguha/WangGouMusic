pragma Singleton
import QtQuick 2.15

// 移动端设计令牌 —— 浅色主题（最大程度对齐网易云音乐手机版视觉）：
// 白底 + 品牌红 #EC4141 + 三级灰文字。
QtObject
{
    id: theme

    // ===== 运行环境 =====
    // 真机（Android/iOS）；桌面 --mobile 预览时为 false（预览窗口固定手机尺寸）
    readonly property bool onDevice: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // ===== 安全区 =====
    // 由 main_mobile.qml 从 Window 的 SafeArea.margins 注入；桌面预览恒为 0。
    property real safeTop: 0
    property real safeBottom: 0
    property real safeLeft: 0
    property real safeRight: 0

    // ===== 品牌色（网易云红系） =====
    readonly property color accent: "#EC4141"
    readonly property color accentHover: "#D93A3A"
    readonly property color accentSubtle: "#1AEC4141"
    readonly property color accentPrimary: "#EC4141"

    // ===== 背景分层 =====
    readonly property color bgPage: "#F7F8FA"      // 页面底（浅灰，衬白卡片）
    readonly property color bgCard: "#FFFFFF"      // 卡片/导航/迷你条
    readonly property color bgInput: "#F2F3F7"     // 搜索框/输入/按压底
    readonly property color bgOverlay: "#14000000"

    // ===== 文字（网易云三级灰） =====
    readonly property color textPrimary: "#333333"
    readonly property color textSecondary: "#666666"
    readonly property color textMuted: "#999999"
    readonly property color textPlaceholder: "#B8B8BE"
    // 播放页（封面模糊深背景）上的文字/图标
    readonly property color textOnCover: "#FFFFFF"

    // ===== 分隔/描边 =====
    readonly property color separator: "#EDEDF0"
    readonly property color borderSubtle: "#F0F0F2"

    // ===== 图标 =====
    readonly property color iconActive: accent
    readonly property color iconInactive: "#B8B8BE"
    readonly property color iconDefault: textPrimary

    // ===== 功能色 =====
    readonly property color successColor: "#07C160"
    readonly property color errorColor: "#FA5151"
    readonly property color hotRank: accent

    // ===== 关键尺寸 =====
    readonly property int tabBarHeight: 54
    readonly property int miniPlayerHeight: 56
    readonly property int touchMin: 44        // 最小可点击目标
    readonly property int pageHPadding: 16    // 页面左右统一留白
    readonly property int cardRadius: 14
    readonly property int coverRadius: 10

    // 底部常驻区总高（TabBar + 可选 MiniPlayer，不含安全区）
    function bottomChromeHeight(miniVisible)
    {
        return tabBarHeight + (miniVisible ? miniPlayerHeight : 0)
    }

    // ===== 字号（移动端整体比桌面大 1~2px） =====
    readonly property string fontFamily: "Sarasa Gothic SC"
    readonly property int fontCaption: 11
    readonly property int fontBody: 14
    readonly property int fontBodyLg: 15
    readonly property int fontTitle: 17
    readonly property int fontHeadline: 21
    readonly property int fontDisplay: 28

    // ===== 动画时长 =====
    readonly property int animFast: 150
    readonly property int animNormal: 250
    readonly property int animSlow: 400

    // ===== 导航钩子 =====
    // 由 main_mobile.qml 启动时注入（StackView 压栈/弹栈）。
    property var pushPage: function(url, props) { }
    property var popPage: function() { }
    // 轻提示（由 main_mobile.qml 实现并注入；页面直接 MTheme.toast("已点播《xx》")）
    property var toast: function(msg) { }

    // 秒 → "3:45"
    function formatTime(sec)
    {
        var s = Math.max(0, Math.floor(Number(sec) || 0))
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }
}
