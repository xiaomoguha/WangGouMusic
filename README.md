# 🎵 网狗音乐

<div align="center">

**一个基于 Qt Quick/QML 的跨平台音乐播放器**

桌面端（Windows / macOS）+ 移动端 UI · 界面参考网易云音乐 · 后端接口来自酷狗音乐 · 支持一起听歌实时同步

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Qt](https://img.shields.io/badge/Qt-6.x-green.svg)](https://www.qt.io)
[![C++17](https://img.shields.io/badge/C%2B%2B-17-orange.svg)](https://isocpp.org/std/the-standard)

</div>

---

## ✨ 功能特性

### 🎶 音乐播放
- **在线播放** — 边下边播，下载到本地缓存的同时即可播放，弱网自动缓冲
- **音质切换** — 标准 / 高品 / 无损（128 / 320 / FLAC），切换音质不再从头播放
- **歌词** — KRC 逐字歌词解析与同步滚动、歌词偏移微调、跳跃歌词动效
- **桌面歌词** — 独立窗口，横版 / 竖版、颜色与字号、锁定后鼠标穿透、多屏选择
- **高潮点** — 进度条标记歌曲高潮位置，支持高潮试听（只加载片段，不打断当前播放）
- **播放模式** — 顺序播放、随机播放、单曲循环
- **播放列表** — 本地播放列表持久化缓存，退出恢复进度
- **系统媒体控制** — 键盘媒体键 / 耳机线控；Windows SMTC、macOS 「正在播放」信息

### 🔍 发现与搜索
- **综合搜索** — 搜索历史 + 热搜推荐；结果页分综合 / 单曲 / 歌单 / 专辑 / 歌手 / MV / 歌词 7 个页签，支持滚动加载与分类「查看更多」
- **首页** — 精选推荐与三列热门单曲，可直接试听、播放、加入一起听
- **每日推荐 / 个人FM** — 个人FM 独立页支持发现 / 小众 / 30 秒 / 电台四种模式与多种推荐源，可喜欢、不感兴趣、屏蔽歌手
- **排行榜 / 歌单发现** — 各类榜单与推荐歌单
- **歌手 / 专辑 / MV** — 歌手页、专辑详情、MV 播放窗口
- **AI 推荐** — 在歌曲右键菜单中按当前歌曲获取 AI 推荐
- **歌曲评论** — 查看歌曲评论并回复

### 📚 歌单与收藏
- **我的歌单** — 默认收藏、我喜欢与自建歌单；收藏的歌单可查看原歌单歌曲
- **歌单管理** — 入口在左侧「我的歌单」右侧的「管理」：新建、重命名、删除、取消收藏、批量移除歌曲
- **右键菜单** — 播放、下一首、高潮试听、添加到歌单、收藏、AI 推荐、播放 MV、从歌单移除、添加到一起听
- **听歌历史** — 本地最近播放，登录后云端同步

### 👤 账号
- **登录** — 验证码登录 / 扫码登录，登录后同步收藏、歌单、每日推荐等个人数据
- **账号信息** — 登录设备列表、听歌等级；账号被踢时自动提示重新登录

### 👥 一起听歌
- **三栏房间** — 左：房间与在线成员；中：正在播放 + 播放队列；右：聊天（加入 / 切歌 / 点赞等房间动态并入聊天时间线）
- **实时同步** — 进度 / 暂停 / 切歌实时同步，播放列表增量同步，弱网缓冲优化
- **协作播放列表** — 房间内所有成员可添加、置顶、删除歌曲；可在房间内搜索点歌，或把多首歌批量「添加到一起听」
- **点赞** — 队列里的歌曲可点赞 / 取消，全员实时可见，点赞动态进入聊天时间线
- **聊天** — 文字 + 表情包；表情包支持自定义上传、最近使用、拖入图片直接发送；新消息有系统通知
- **房间推荐** — 队列快播完时，按某位成员的私人 FM 风格自动推荐歌曲（由该成员的客户端拉取，服务端不接触任何账号凭据）；无响应自动换人，仍失败则回退系统推荐
- **房间管理** — 创建 / 加入房间（输入房间号或从活跃房间列表选择）、邀请、在线成员列表

### 🎨 界面与体验
- **深色主题** — 统一的设计令牌（`AppTheme`），全站 SVG 图标
- **星空背景** — 主界面星空背景与光标光源联动；播放详情页随封面主色调变化
- **内嵌字体** — 随包打包更纱黑体（Sarasa Gothic SC），跨平台显示一致
- **无边框窗口** — 自定义标题栏、圆角窗口；macOS 通过 QWindowKit 接入原生红黄绿按钮
- **系统托盘** — 最小化到托盘，后台继续播放；单实例运行
- **自动更新** — 启动时检查新版本，弹窗下载安装
- **设置** — 网络代理、桌面歌词、服务器共享 Token 管理（需管理密钥）
- **稳定性** — 崩溃日志与会话日志、窗口位置记忆

### 📱 移动端 UI
- 独立的移动端界面（`Src_Mobile/` + `main_mobile.qml`）：首页、浏览、搜索、歌单详情、排行榜、每日推荐、播放队列、一起听、我的
- 桌面端运行时加 `--mobile` 参数，即可在手机尺寸的窗口里预览

## 📸 界面预览

```
┌────────────────────────────────────────────────────────────┐
│◉ 网狗音乐          🔍 搜索歌曲、歌手                    ⚙   avatar  —  □  ✕│
├────────────────────┬───────────────────────────────────────┤
│ 云音乐精选         │     首页 / 搜索结果 / 歌单详情 / 一起听 …│
│ 每日推荐           │                                       │
│ 个人FM             │                                       │
│ 排行榜             │                                       │
│ 一起听歌           │                                       │
│ 歌单发现           │                                       │
│ ───────────────────│                                       │
│ ♥ 我的歌单  管理 ▾ │                                       │
│   默认收藏         │                                       │
│   我喜欢           │                                       │
│ 听歌历史           │                                       │
│                    │                                       │
│                    │                                       │
│                    │                                       │
├────────────────────────────────────────────────────────────┤
│ [封面] 歌曲名 - 歌手    ♥  ⏮  ▶  ⏭   00:00 ━━━━━━━━━●━━━━━━ 04:47   🔊  ☰│
└────────────────────────────────────────────────────────────┘
```

## 🛠️ 技术栈

| 层级 | 技术 |
|------|------|
| 前端 UI | Qt Quick / QML（Qt Quick Controls 2，Fusion 风格） |
| 后端逻辑 | C++17（QObject 通过 context property 暴露给 QML） |
| 音频播放 | Qt Multimedia（QMediaPlayer + FFmpeg 后端） |
| 网络通信 | Qt Network, Qt WebSockets |
| 图标 / 字体 | SVG 图标、内嵌更纱黑体 Sarasa Gothic SC |
| 桌面集成 | QWindowKit（macOS）、系统媒体控制（macOS / Windows） |
| 构建系统 | CMake（Visual Studio / Ninja 生成器均可） |
| 数据解析 | Qt JSON, KRC 歌词格式解析 |

## 📁 项目结构

```
WangGouMusic/
├── main.cpp                    # 应用入口：创建后端对象并注入 QML，窗口 / 托盘 / 媒体控制集成
├── main.qml                    # 桌面主窗口
├── main_mobile.qml             # 移动端 UI 入口
├── CMakeLists.txt              # CMake 构建配置（含 macOS / Windows / Android 分支）
├── Info.plist.in               # macOS 应用信息配置
├── app.rc                      # Windows 应用资源（图标等）
├── fonts.qrc / icons.qrc / image.qrc   # 字体 / SVG 图标 / 图片资源
├── qml.qrc                     # QML 资源清单
│
├── CPPSrc/                     # C++ 后端
│   ├── ApiClient.*             # HTTP API 请求单例
│   ├── playlistmanager.*       # 播放核心：播放列表、缓存、高潮试听、一起听同步
│   ├── WebSocketClient.*       # 一起听 WebSocket 客户端
│   ├── lyricparser.*           # KRC 逐字歌词解析器
│   ├── SongInfo.*              # 歌曲数据（Q_GADGET）
│   ├── models/                 # SongListModel / MessageListModel
│   ├── searchcomplex.*         # 搜索（综合搜索 / 一起听点歌各一个实例）
│   ├── gethostsearch.*         # 热搜数据
│   ├── searchhistorymanager.*  # 搜索历史
│   ├── dailyrecommend.*        # 每日推荐
│   ├── personalfm.*            # 个人FM（页面推荐 + 一起听房间推荐）
│   ├── ranklist.*              # 排行榜
│   ├── discovermanager.*       # 歌单发现
│   ├── recommendation.*        # 推荐歌曲 / 歌单
│   ├── airecommendmanager.*    # AI 推荐
│   ├── playlistcollection.*    # 歌单（新建 / 重命名 / 删除 / 收藏）
│   ├── albummanager.*          # 专辑
│   ├── artistmanager.*         # 歌手（含 artistlistmodel.*）
│   ├── mvmanager.*             # MV
│   ├── historymanager.*        # 听歌历史（本地 + 云端）
│   ├── songcomments.*          # 歌曲评论
│   ├── usermanager.*           # 用户登录 / Token 管理
│   ├── serveradminmanager.*    # 服务器共享 Token 管理
│   ├── stickermanager.*        # 一起听表情包
│   ├── appupdater.*            # 自动更新
│   ├── singleapplication.*     # 单实例检测
│   ├── trayhandler.*           # 系统托盘
│   ├── lyricsconfigmanager.*   # 歌词 / 桌面歌词配置持久化
│   ├── NowPlayingMediaController.*   # 系统媒体控制（macOS / Windows）
│   ├── macoswindow.* / mactrayitem.* # macOS 窗口层级 / 托盘
│   ├── CrashHandler.*          # 崩溃捕获与日志
│   ├── PlaylistCacheStore.*    # 缓存目录管理
│   ├── proxymanager.*          # 进程级网络代理
│   └── ...
│
├── Src/                        # 桌面端 QML
│   ├── BasicConfig/            # 主题令牌 (AppTheme)、图标 (AppIcon) 和通用组件
│   ├── Leftpage/               # 左侧导航栏
│   ├── Rightpage/              # 顶部栏、搜索、登录状态、内容区导航
│   ├── Bottompage/             # 底部播放控制栏
│   ├── PlayingPage/            # 播放详情页（歌词）
│   ├── ComponentPage/          # 各功能页面
│   │   ├── HomePage.qml             # 首页推荐
│   │   ├── ComplexPage.qml          # 综合搜索
│   │   ├── PersonalFMPage.qml       # 个人FM
│   │   ├── PlaylistManagerPage.qml  # 歌单管理
│   │   ├── Togethermusicmain.qml    # 一起听歌房间
│   │   ├── Add_room_window.qml      # 创建 / 加入一起听房间
│   │   ├── SettingsPage.qml         # 设置
│   │   ├── LoginPage.qml            # 登录页
│   │   ├── DesktopLyrics.qml        # 桌面歌词独立窗口
│   │   └── ...
│   └── ToolWindow/             # Toast、空状态、导航图标等工具组件
│
└── Src_Mobile/                 # 移动端 QML（M* 通用组件 + pages/）
```

## 🚀 编译运行

### 环境要求

- **Qt** 6.x（需要 Core, Quick, Multimedia, WebSockets, Widgets, QuickControls2, Core5Compat, Network, QuickDialogs2, Svg 模块）
- **macOS 额外依赖** — [QWindowKit](https://github.com/std-microblock/QWindowKit) 以及 Qt 私有模块头文件（Qt6CorePrivate / Qt6GuiPrivate / Qt6QuickPrivate）
- **CMake** ≥ 3.16、**C++17** 编译器（MSVC / Clang / GCC）

> `CMakeLists.txt` 里 `find_package(QWindowKit ... PATHS ...)` 写的是作者本机的安装路径，换机器构建前请改成自己的 QWindowKit 安装路径，或提前设置 `QWindowKit_DIR`。

### macOS

```bash
# 配置 Qt 路径（根据实际安装路径修改）
export Qt6_DIR=~/Qt/6.x.x/macos/lib/cmake/Qt6

# 配置 + 编译
cmake -B build -G Ninja
cmake --build build --parallel

# 运行
open build/网狗音乐.app
```

### Windows

```bash
# 配置（Visual Studio 2022 生成器，按实际 Qt 路径修改）
cmake -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_PREFIX_PATH=C:/Qt/6.x.x/msvc2022_64

# 编译（Release）
cmake --build build --config Release --target WangGouMusic

# 运行
build\Release\网狗音乐.exe
```

> **注意**：Windows 运行时需要将 Qt 的 bin 目录加入 PATH，或使用 `windeployqt` 部署依赖；发布安装包时可再用 Inno Setup 等工具打包。Debug 构建会附带控制台窗口方便看日志。

### Linux

```bash
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x.x/gcc_64
cmake --build build --parallel
./build/网狗音乐
```

### 预览移动端 UI

```bash
./build/网狗音乐 --mobile          # Windows: build\Release\网狗音乐.exe --mobile
```

该模式加载 `main_mobile.qml`，窗口固定为手机尺寸，并跳过单实例、托盘、桌面歌词等桌面专属功能。

## ⚙️ 配置说明

应用配置和缓存存储在以下位置：

| 平台 | 缓存目录 |
|------|---------|
| Windows | `C:/网狗音乐缓存目录/` |
| macOS / 其它 | `~/Downloads/网狗音乐缓存目录/` |

目录内容包括：
- `config/` — 播放列表 (`playlist_cache.json`)、最近播放 (`recent_cache.json`)、听歌历史 (`history_cache.json`)、歌单缓存 (`playlist_*.json`)、收藏 (`favorite_hashes.json`)、搜索历史 (`search_history.json`)、歌词配置 (`lyrics_config.json`) 等
- `lyrics/` — 歌词缓存 (`lyrics_<hash>.json`)
- `songs/128|320|flac/` — 按音质分目录缓存的歌曲文件
- `logs/` — 运行日志 (`session_*.log`) 与崩溃日志 (`crash_*.log`)，自动清理只保留最近 100 份
- 网络图片缓存在系统缓存目录下（100MB, Qt 自动管理）

## 🔧 关键模块说明

### PlaylistManager — 播放核心

管理本地播放列表 (`m_playlist`) 和一起听播放列表 (`m_togetherplaylist`)，通过 `m_curplaylist` 指针在两种模式间切换。支持：
- 缓存文件优先播放，无缓存时边下边播
- 播放进度保存/恢复（退出时自动保存，启动时恢复到上次位置）
- 下载进度追踪和缓冲状态管理
- 高潮试听片段引擎：用独立播放器按字节范围加载 30 秒片段，个人FM 的 30 秒模式也复用它

### WebSocketClient — 一起听同步

基于 `QWebSocket` 的实时同步客户端：
- 心跳保活（30s 间隔，5 倍超时断开）
- 播放进度周期性同步（偏差 > 3s 才 seek，避免频繁跳动）
- 消息发送确认机制（本地回显 + 超时重试）
- 防重入保护（同一首歌不重复加载）
- 统一时间线模型 `timelineMessages`：聊天消息与房间动态按时间合并，供房间页直接渲染
- 登录后在握手参数里声明 `fm_ready=1`，响应服务端的房间 FM 推荐请求（客户端自己拉私人 FM 后回传歌曲信息）

### PersonalFM — 个人FM

- 页面推荐：多种模式与推荐源，维护十首队列并整批刷新
- 房间推荐：收到一起听服务端请求时，用当前登录用户的 Token 拉取私人 FM 并回传候选歌曲，不影响 FM 页自身的队列

### ApiClient / HttpGetRequester — 网络请求

- `ApiClient`：全局 HTTP 请求单例，统一发起接口调用
- `HttpGetRequester`：注册到 QML 的 GET 请求器（`import NetworkRequest 1.0`），页面可直接实例化使用

### LyricParser — 歌词引擎

解析酷狗 KRC 格式歌词，支持：
- 逐行时间戳定位
- 逐字符高亮进度计算
- 英文歌词字符级分割

## 📜 开源许可

本项目基于 [MIT License](LICENSE) 开源。

---

<div align="center">

*个人学习项目，仅供学习交流使用*

</div>
