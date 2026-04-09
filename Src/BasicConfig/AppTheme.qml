pragma Singleton
import QtQuick 2.15

QtObject {
    id: theme

    // ===== 主题状态 =====
    // 开机时从 C++ 加载，C++ 构造时从本地配置读取
    property bool isDark: lyricsConfig ? lyricsConfig.isDark : true

    signal themeChanged

    function toggleTheme() {
        isDark = !isDark;
        if (lyricsConfig) {
            lyricsConfig.isDark = isDark;
            lyricsConfig.saveConfig();
        }
        themeChanged();
    }

    // ===== 背景颜色 =====
    readonly property color bgSidebar: isDark ? "#1a1a21" : "#F5F5F7"
    readonly property color bgContent: isDark ? "#13131a" : "#FFFFFF"
    readonly property color bgBottomBar: isDark ? "#2d2d37" : "#FAFAFA"
    readonly property color bgBottomBarInner: isDark ? "#1a1a24" : "#F0F0F2"
    readonly property color bgCard: isDark ? "#27272e" : "#F8F8FA"
    readonly property color bgCardHover: isDark ? "#212127" : "#EEEEF2"
    readonly property color bgNavHover: isDark ? "#2A2A35" : "#E8E8EC"
    readonly property color bgInput: isDark ? "#2A2A35" : "#F0F0F3"
    readonly property color bgOverlay: isDark ? "#1E1E2A" : "#FFFFFF"
    readonly property color bgSearchPopup: isDark ? "#2d2d37" : "#F0F0F5"
    readonly property color bgHistoryTag: isDark ? "#2d2d37" : "#EBEBF0"
    readonly property color bgHistoryTagHover: isDark ? "#393943" : "#DCDCDF"
    readonly property color bgSuggestionHover: isDark ? "#393943" : "#E0E0E5"
    readonly property color bgExpandBtn: isDark ? "#2A2A35" : "#EEEEF2"
    readonly property color bgExpandBtnHover: isDark ? "#3A3A45" : "#E0E0E8"
    readonly property color bgRoomCard: isDark ? "#393943" : "#F5F5F7"
    readonly property color bgLoadingOverlay: isDark ? "#13131a" : "#FFFFFF"
    readonly property color bgTooltip: isDark ? "#1E1E2A" : "#2C2C2E"

    // ===== 强调色 =====
    readonly property color accent: isDark ? "#FF6B6B" : "#FF8A80"
    readonly property color accentHover: isDark ? "#FF5252" : "#FF6B6B"
    readonly property color accentDim: isDark ? "#30FF6B6B" : "#15FF8A80"
    readonly property color accentGlow: isDark ? "#40FF6B6B" : "#40FF8A80"
    readonly property color accentPlaying: isDark ? "#e74f50" : "#FF6B6B"

    // ===== 文字颜色 =====
    readonly property color textPrimary: isDark ? "#FFFFFF" : "#1A1A2E"
    readonly property color textSecondary: isDark ? "#CCCCCC" : "#666680"
    readonly property color textMuted: isDark ? "#888899" : "#9999AA"
    readonly property color textDim: isDark ? "#666677" : "#AAAAAA"
    readonly property color textPlaceholder: isDark ? "#666666" : "#AAAAAA"
    readonly property color textHotIndex: "#eb4d44"
    readonly property color textNormalIndex: isDark ? "#818187" : "#888899"
    readonly property color textSearchKeyword: isDark ? "#7f7f85" : "#888899"

    // ===== 边框/分隔线 =====
    readonly property color borderDefault: isDark ? "#3A3A45" : "#D8D8E0"
    readonly property color borderSubtle: isDark ? "#2A2A35" : "#E8E8EC"
    readonly property color borderFocus: "#FF6B6B"

    // ===== 图标颜色 =====
    readonly property color iconDefault: isDark ? "#FFFFFF" : "#444455"
    readonly property color iconHover: isDark ? "#FFFFFF" : "#1A1A2E"
    readonly property color iconNav: isDark ? "#AAAAAA" : "#888899"
    readonly property color iconActive: "#FFFFFF"
    readonly property color iconSearch: isDark ? "#888888" : "#888899"
    readonly property color iconButtonHover: isDark ? "#30FFFFFF" : "#10000000"

    // ===== 滚动条 =====
    readonly property color scrollbarColor: isDark ? "#42424b" : "#D0D0D5"

    // ===== 对话框/弹窗 =====
    readonly property color dialogBorder: isDark ? "#30FFFFFF" : "#D8D8E0"
    readonly property color dialogOverlay: isDark ? "#80000000" : "#40000000"
    readonly property color dialogAccentBorder: isDark ? "#15FF6B6B" : "#10FF8A80"

    // ===== 进度条 =====
    readonly property color progressTrack: isDark ? "#2A2A35" : "#E0E0E5"
    readonly property color progressFill: isDark ? "#FF6B6B" : "#FF8A80"
    readonly property color progressDot: isDark ? "#FFFFFF" : "#FF8A80"

    // ===== 功能色 =====
    readonly property color successColor: "#00C853"
    readonly property color errorColor: "#FF4D4F"
    readonly property color infoColor: "#4FC3F7"

    // ===== 房间渐变边框色 =====
    readonly property color roomOuterStart: isDark ? "#21283d" : "#D8D8E8"
    readonly property color roomOuterEnd: isDark ? "#382635" : "#E8D8E0"
    readonly property color roomInnerStart: isDark ? "#1a1d29" : "#EDEDF2"
    readonly property color roomInnerEnd: isDark ? "#241c26" : "#F2ECF0"

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
}
