pragma Singleton
import QtQuick 2.15

QtObject {
    signal bkanAreaClicked // 窗口空白被点击
    signal pushPage(string pageUrl)
    signal indexChange(int index)
    signal pushSearchSongPage(string pageUrl)
    signal searchKeywordChange
    signal noticeError(string errormessages)
    signal noticeSuccess(string messages)
    signal songAdded(string songname)
    signal requestMvPlay(var song)  // {mvhash,title,singername,songhash,cover}：MV 窗口展示信息+拉评论用

    property string searchKeyword: ""

    // 导航回退
    property string previousPageUrl: ""
    property int previousIndex: 0

    // 歌单详情页参数
    property string playlistDetailId: ""
    property string playlistDetailName: ""
    property string playlistDetailCover: ""
    property string playlistDetailIntro: ""

    // 歌手页参数
    property string artistId: ""
    property string artistName: ""

    // 专辑页参数
    property string albumId: ""
    property string albumName: ""
    property string albumCover: ""

    // ---- 渐变主色来源 ----
    // 歌单页封面主色（歌单详情页驱动）；歌单页是否显示中
    property string playlistPageCoverColor: ""
    property bool playlistPageActive: false
    // 播放中歌曲封面主色（main.qml 从 playlistmanager 同步）；是否正在播放（有歌且未暂停）
    property string playingCoverColor: ""
    property bool playingActive: false

    // 最终生效色：歌单页激活 → 歌单色；否则播放中 → 播放歌曲色；否则空 = 无渐变。
    // 所有消费方（WindowTintGradient / 面板根色 / 角遮挡片）只读这个，来源切换自动平滑过渡。
    // 深色主题下先过 clampCoverColor 亮度钳制，浅色封面不会把整窗渐变染白。
    readonly property string playlistCoverColor: clampCoverColor(playlistPageActive
        ? playlistPageCoverColor
        : (playingActive ? playingCoverColor : ""))

    // 深色主题下把封面主色按最大分量线性压暗到 ≤0.5 亮度（保持色相），
    // 避免切到浅色封面时整窗渐变与浮层文字一起变白；浅色主题/空色原样返回。
    function clampCoverColor(hex) {
        if (!AppTheme.isDark) return hex
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#") return hex
        var c = rgbFromHex(hex, 1)
        var mx = Math.max(c.r, Math.max(c.g, c.b))
        if (mx <= 0.5) return hex
        var k = 0.5 / mx
        var hexByte = function(v) {
            var s = Math.round(v).toString(16)
            return s.length < 2 ? "0" + s : s
        }
        return "#" + hexByte(c.r * 255 * k) + hexByte(c.g * 255 * k) + hexByte(c.b * 255 * k)
    }

    // 主窗口高度（由 main.qml 同步）：用于把「整窗 50% 处淡出」换算成每个面板内的渐变位置
    property real windowHeight: 752

    // 主窗口被遮蔽（最小化或关闭到托盘，由 main.qml 同步）：
    // 一起听聊天通知只看这个状态——窗口看得见就不打扰，看不见就通知，不论在哪个页面
    property bool windowObscured: false

    // 装饰性动画总闸（由 main.qml 同步）：窗口被遮蔽或应用失焦时为 true。
    // 跑马灯/加载圈/唱片旋转这类无限动画不看用户是否在看就 60fps 空转，
    // 是后台 CPU 高的主因；此闸只停装饰动画，播放进度/歌词等真实数据不受影响
    property bool uiIdle: false

    // 模态弹窗输入锁：弹窗置位/复位，main.qml 据此禁用 windowShell。
    // 点击会沿 z 序穿透到页面 TapHandler（MouseArea 拦不住），只能禁底层
    property bool modalInputLock: false

    // 安全地把 "#RRGGBB" 转为 rgba（与播放页一致，防 NaN 崩溃）
    function rgbFromHex(hex, alpha) {
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#")
            return Qt.rgba(1.0, 0.42, 0.42, alpha)
        var r = parseInt(hex.substring(1, 3), 16)
        var g = parseInt(hex.substring(3, 5), 16)
        var b = parseInt(hex.substring(5, 7), 16)
        if (isNaN(r) || isNaN(g) || isNaN(b))
            return Qt.rgba(1.0, 0.42, 0.42, alpha)
        return Qt.rgba(r / 255, g / 255, b / 255, alpha)
    }

    // 把封面主色按 alpha 混入不透明底色，得到该位置的最终不透明色。
    // 主色为空/非法时原样返回底色（无渐变态）。返回 alpha 恒为 1，
    // 保证面板底色是纯不透明渐变——内容画在其上不会触发 macOS 半透明压字发糊。
    function mixTint(hex, baseColor, alpha) {
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#")
            return baseColor
        var t = rgbFromHex(hex, 1)
        var b = (typeof baseColor === "string") ? rgbFromHex(baseColor, 1) : baseColor
        return Qt.rgba(t.r * alpha + b.r * (1 - alpha),
                       t.g * alpha + b.g * (1 - alpha),
                       t.b * alpha + b.b * (1 - alpha),
                       1.0)
    }

    // 渐变激活时给「浮在渐变上的文字」挑可读色：取顶部 50% 混色（主色×0.5+底色×0.5）
    // 算亮度，深底 → 白字，浅底 → 深字。无渐变时返回空串，调用方自行回退主题色。
    function contrastText(hex, baseColor) {
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#")
            return ""
        var t = rgbFromHex(hex, 1)
        var b = (typeof baseColor === "string" && baseColor.length >= 7) ? rgbFromHex(baseColor, 1) : null
        var r = t.r, g = t.g, bl = t.b
        if (b) {
            r = t.r * 0.5 + b.r * 0.5
            g = t.g * 0.5 + b.g * 0.5
            bl = t.b * 0.5 + b.b * 0.5
        }
        var lum = 0.299 * r + 0.587 * g + 0.114 * bl
        return lum > 0.55 ? "#1A1A2E" : "#FFFFFF"
    }

    function openPlaylistDetail(id, name, cover, intro) {
        playlistDetailId = id;
        playlistDetailName = name;
        playlistDetailCover = cover;
        playlistDetailIntro = intro;
        pushPage("qrc:/Src/ComponentPage/PlaylistDetailPage.qml");
    }

    function openArtist(id, name) {
        artistId = id;
        artistName = name;
        pushPage("qrc:/Src/ComponentPage/ArtistPage.qml");
    }

    function openAlbum(id, name, cover) {
        albumId = id;
        albumName = name;
        albumCover = cover;
        pushPage("qrc:/Src/ComponentPage/AlbumPage.qml");
    }

    function goBack() {
        if (previousPageUrl !== "") {
            pushPage(previousPageUrl);
            indexChange(previousIndex);
        }
    }

    // 便捷方法：发送歌曲添加成功提示
    function emitSongAdded(songname) {
        songAdded(songname || "已添加至播放列表");
    }
}
