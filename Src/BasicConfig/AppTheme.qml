pragma Singleton
import QtQuick 2.15

QtObject {
    id: theme

    // 仅深色模式：浅色模式已整体移除（无主题令牌、无切换入口）

    // ===== 背景颜色 =====
    readonly property color bgSidebar: "#1a1a21"
    readonly property color bgContent: "#13131a"
    readonly property color bgBottomBar: "#1a1a21"
    readonly property color bgBottomBarInner: "#1a1a24"
    readonly property color bgCard: "#27272e"
    readonly property color bgCardHover: "#212127"
    readonly property color bgNavHover: "#2A2A35"
    readonly property color bgInput: "#2A2A35"
    readonly property color bgOverlay: "#1E1E2A"
    readonly property color bgSearchPopup: "#2d2d37"
    readonly property color bgHistoryTag: "#2d2d37"
    readonly property color bgHistoryTagHover: "#393943"
    readonly property color bgSuggestionHover: "#393943"
    readonly property color bgExpandBtn: "#2A2A35"
    readonly property color bgExpandBtnHover: "#3A3A45"
    readonly property color bgRoomCard: "#393943"
    readonly property color bgLoadingOverlay: "#13131a"
    readonly property color bgTooltip: "#1E1E2A"

    // ===== 强调色 =====
    readonly property color accent: "#FF6B6B"
    readonly property color accentHover: "#FF5252"
    readonly property color accentDim: "#30FF6B6B"
    readonly property color accentGlow: "#40FF6B6B"
    readonly property color accentPlaying: "#e74f50"

    // 弱化的强调色（空状态图标底色、淡红底纹等）
    readonly property color accentSubtle: "#30FF6B6B"

    // 主操作按钮(CTA)色：暂保留现有"一起听 / 播放全部"红紫配色，后续可统一到 accent
    readonly property color accentPrimary: "#e94560"
    readonly property color accentPrimaryHover: "#533483"

    // ===== 文字颜色 =====
    readonly property color textPrimary: "#FFFFFF"
    // 歌曲名专用：深色纯白、浅色纯黑（比 textPrimary 的浅色 #1A1A2E 更黑）
    readonly property color textSongTitle: "#FFFFFF"
    readonly property color textSecondary: "#CCCCCC"
    readonly property color textMuted: "#888899"
    readonly property color textDim: "#666677"
    readonly property color textPlaceholder: "#666666"
    readonly property color textHotIndex: "#eb4d44"
    readonly property color textNormalIndex: "#818187"
    readonly property color textSearchKeyword: "#7f7f85"

    // ===== 边框/分隔线 =====
    readonly property color borderDefault: "#3A3A45"
    readonly property color borderSubtle: "#2A2A35"
    readonly property color borderFocus: "#FF6B6B"

    // ===== 图标颜色 =====
    readonly property color iconDefault: "#FFFFFF"
    readonly property color iconHover: "#FFFFFF"
    readonly property color iconNav: "#AAAAAA"
    readonly property color iconActive: "#FFFFFF"
    readonly property color iconSearch: "#888888"
    readonly property color iconButtonHover: "#30FFFFFF"

    // ===== 滚动条 =====
    readonly property color scrollbarColor: "#42424b"

    // ===== 对话框/弹窗 =====
    readonly property color dialogBorder: "#30FFFFFF"
    readonly property color dialogOverlay: "#80000000"
    readonly property color dialogAccentBorder: "#15FF6B6B"

    // ===== 进度条 =====
    readonly property color progressTrack: "#2A2A35"
    readonly property color progressFill: "#FF6B6B"
    readonly property color progressDot: "#FFFFFF"

    // ===== 功能色 =====
    readonly property color successColor: "#00C853"
    readonly property color errorColor: "#FF4D4F"
    readonly property color infoColor: "#4FC3F7"

    // ===== 房间渐变边框色 =====
    readonly property color roomOuterStart: "#21283d"
    readonly property color roomOuterEnd: "#382635"
    readonly property color roomInnerStart: "#1a1d29"
    readonly property color roomInnerEnd: "#241c26"

    // ===== 间距常量 =====
    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingXL: 20

    // ===== 圆角常量 =====
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16
    readonly property int radiusXL: 20

    // ===== 动画时长 =====
    readonly property int animFast: 150
    readonly property int animNormal: 250
    readonly property int animSlow: 400
    readonly property int animThemeTransition: 300

    // ===== 字体 =====
    // 主字体：Sarasa Gothic SC（更纱黑体），随包打包、在 main.cpp 用 QFontDatabase 注册，
    // 跨平台显示一致；含完整中文，中英文混排对齐整齐。缺失字形时 Qt 自动回退系统字体。
    readonly property string fontFamily: "Sarasa Gothic SC"

    // ===== 字号（px）=====
    // 对齐现有最高频取值（13/12/14/11/16/20/18）；后续可叠加 dp 缩放适配 HiDPI
    readonly property int fontSizeXs: 10        // 极小 / 辅助标记
    readonly property int fontSizeCaption: 11   // 说明、次要信息
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeBody: 13      // 正文（最常用）
    readonly property int fontSizeBodyLg: 14
    readonly property int fontSizeTitle: 16
    readonly property int fontSizeTitleLg: 18
    readonly property int fontSizeHeadline: 20
    readonly property int fontSizeDisplay: 24   // 大标题
}
