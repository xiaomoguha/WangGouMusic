pragma Singleton
import QtQuick 2.15

// 矢量图标(Phosphor)统一路径映射。全部为单色 SVG，由 IconButton 的 ColorOverlay
// 按主题 token 着色——深/浅色自适应、任意 DPI 锐利。`*Fill` 为实心变体，用于 active 态。
QtObject {
    // 传输
    readonly property string play: "qrc:/icons/play.svg"
    readonly property string playFill: "qrc:/icons/play-fill.svg"
    readonly property string pause: "qrc:/icons/pause.svg"
    readonly property string pauseFill: "qrc:/icons/pause-fill.svg"
    readonly property string next: "qrc:/icons/skip-forward.svg"
    readonly property string prev: "qrc:/icons/skip-back.svg"
    readonly property string playCircle: "qrc:/icons/play-circle.svg"

    // 歌曲行动作
    readonly property string addToList: "qrc:/icons/list-plus.svg"
    readonly property string addTogether: "qrc:/icons/users-three.svg"
    readonly property string heart: "qrc:/icons/heart.svg"
    readonly property string heartFill: "qrc:/icons/heart-fill.svg"

    // 导航/通用
    readonly property string queue: "qrc:/icons/queue.svg"
    readonly property string list: "qrc:/icons/list.svg"
    readonly property string listFill: "qrc:/icons/list-fill.svg"

    // 导航栏图标（线框 + 填充变体）
    readonly property string star: "qrc:/icons/star.svg"
    readonly property string starFill: "qrc:/icons/star-fill.svg"
    readonly property string headphones: "qrc:/icons/headphones.svg"
    readonly property string headphonesFill: "qrc:/icons/headphones-fill.svg"
    readonly property string clock: "qrc:/icons/clock.svg"
    readonly property string clockFill: "qrc:/icons/clock-fill.svg"
    readonly property string lyrics: "qrc:/icons/closed-captioning.svg"
    readonly property string search: "qrc:/icons/magnifying-glass.svg"
    readonly property string fire: "qrc:/icons/fire.svg"
    readonly property string back: "qrc:/icons/arrow-left.svg"
    readonly property string arrowUp: "qrc:/icons/arrow-up.svg"
    readonly property string close: "qrc:/icons/x.svg"
    readonly property string minimize: "qrc:/icons/minus.svg"
    readonly property string maximize: "qrc:/icons/arrows-out-simple.svg"
    readonly property string restore: "qrc:/icons/arrows-in-simple.svg"
    readonly property string refresh: "qrc:/icons/arrow-clockwise.svg"
    readonly property string check: "qrc:/icons/check.svg"
    readonly property string lock: "qrc:/icons/lock.svg"
    readonly property string unlock: "qrc:/icons/lock-open.svg"
    readonly property string deleteIcon: "qrc:/icons/trash.svg"
    readonly property string user: "qrc:/icons/user.svg"
    readonly property string moon: "qrc:/icons/moon.svg"
    readonly property string sun: "qrc:/icons/sun.svg"
    readonly property string locate: "qrc:/icons/crosshair.svg"
    readonly property string plus: "qrc:/icons/plus.svg"
    readonly property string caretLeft: "qrc:/icons/caret-left.svg"
    readonly property string caretDown: "qrc:/icons/caret-down.svg"
    readonly property string caretUp: "qrc:/icons/caret-up.svg"
    readonly property string caretRight: "qrc:/icons/caret-right.svg"
    readonly property string sparkle: "qrc:/icons/sparkle.svg"
    // 播放模式：顺序 / 单曲循环 / 随机
    readonly property string playModeOrder: "qrc:/icons/order.svg"
    readonly property string playModeRepeatOne: "qrc:/icons/repeat-one.svg"
    readonly property string playModeShuffle: "qrc:/icons/shuffle.svg"
}
