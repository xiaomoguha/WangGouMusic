# 🎵 网狗音乐

<div align="center">

**一个基于 Qt Quick/QML 的跨平台音乐播放器**

界面参考网易云音乐 · 后端接口来自酷狗音乐 · 支持一起听歌实时同步

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Qt](https://img.shields.io/badge/Qt-6.x-green.svg)](https://www.qt.io)
[![C++17](https://img.shields.io/badge/C%2B%2B-17-orange.svg)](https://isocpp.org/std/the-standard)

</div>

---

## ✨ 功能特性

### 🎶 音乐播放
- **在线搜索** — 关键词搜索歌曲，支持热搜推荐
- **边下边播** — 下载到本地缓存的同时即可播放，弱网自动缓冲
- **歌词显示** — KRC 逐字歌词解析与同步滚动，桌面歌词（横版/竖版）独立窗口
- **播放模式** — 顺序播放、随机播放、单曲循环
- **播放列表** — 本地播放列表持久化缓存，退出恢复进度

### 👥 一起听歌
- **实时同步** — 基于 WebSocket 的多人同步播放，进度/暂停/切歌实时同步
- **协作播放列表** — 房间内所有成员可添加、置顶、删除歌曲
- **聊天互动** — 房间内实时聊天，操作动态（加入/离开/添加歌曲等）
- **房间管理** — 创建/加入房间，在线用户列表
- **弱网优化** — 自动缓冲检测，播放追上下载时暂停等待，领先后自动恢复

### 🎨 界面与体验
- **深色/浅色主题** — 一键切换，跟随系统风格
- **无边框窗口** — 自定义标题栏，圆角窗口设计
- **专辑封面主色调** — 自动提取封面颜色，UI 动态适配
- **系统托盘** — 最小化到托盘，后台继续播放
- **macOS 媒体控制** — 支持 Touch Bar 和通知中心控制播放
- **自动更新** — 启动时静默检查新版本

## 📸 界面预览

```
┌─────────────────────────────────────────────────┐
│  🎵 网狗音乐                    ─  □  ✕        │
├──────────┬──────────────────────────────────────┤
│          │                                      │
│  发现音乐 │      搜索结果 / 推荐 / 歌单详情       │
│  播放列表 │                                      │
│  最近播放 │                                      │
│  我的收藏 │                                      │
│  本地音乐 │                                      │
│  一起听歌 │                                      │
│          │                                      │
│          │                                      │
├──────────┴──────────────────────────────────────┤
│  ◀◀  ▶  ▶▶   歌曲名 - 歌手   ▬▬▬▬▬▬▬○▬▬▬   🔊  │
└─────────────────────────────────────────────────┘
```

## 🛠️ 技术栈

| 层级 | 技术 |
|------|------|
| 前端 UI | Qt Quick / QML |
| 后端逻辑 | C++17 |
| 音频播放 | Qt Multimedia (QMediaPlayer + FFmpeg 后端) |
| 网络通信 | Qt Network, Qt WebSockets |
| 构建系统 | CMake + Ninja |
| 数据解析 | Qt JSON, KRC 歌词格式解析 |

## 📁 项目结构

```
WangGouMusic/
├── main.cpp                    # 应用入口，初始化所有后端对象
├── main.qml                    # 主窗口，三栏布局（左栏/内容/底栏）
├── CMakeLists.txt              # CMake 构建配置
├── Info.plist.in               # macOS 应用信息配置
├── app.rc                      # Windows 应用资源（图标等）
├── image.qrc / qml.qrc         # Qt 资源文件
│
├── CPPSrc/                     # C++ 后端源码
│   ├── playlistmanager.*       # 播放列表管理 & 播放控制核心
│   ├── WebSocketClient.*       # WebSocket 客户端（一起听歌）
│   ├── lyricparser.*           # KRC 逐字歌词解析器
│   ├── searchcomplex.*         # 搜索功能
│   ├── recommendation.*        # 推荐歌曲/歌单
│   ├── gethostsearch.*         # 热搜数据
│   ├── usermanager.*           # 用户登录/Token 管理
│   ├── appupdater.*            # 自动更新
│   ├── singleapplication.*     # 单实例检测
│   ├── trayhandler.*           # 系统托盘
│   ├── lyricsconfigmanager.*   # 歌词/主题配置持久化
│   ├── macoswindow.*           # macOS 窗口层级 API
│   └── NowPlayingMediaController.*  # macOS 媒体控制中心集成
│
├── Src/                        # QML 前端界面
│   ├── BasicConfig/            # 全局主题 (AppTheme) 和配置
│   ├── Leftpage/               # 左侧导航栏
│   ├── Rightpage/              # 右侧内容区（搜索、登录、页面导航）
│   ├── Bottompage/             # 底部播放控制栏
│   ├── PlayingPage/            # 歌词全屏页
│   ├── ComponentPage/          # 各功能页面
│   │   ├── HomePage.qml        # 首页推荐
│   │   ├── Togethermusicmain.qml   # 一起听歌房间
│   │   ├── SearchresultPage.qml    # 搜索结果
│   │   ├── DesktopLyrics.qml       # 桌面歌词独立窗口
│   │   ├── LoginPage.qml           # 登录页
│   │   └── ...
│   └── ToolWindow/             # Toast 提示等工具组件
│
└── image/                      # 图标和图片资源
    ├── wyyicon.png             # 应用图标 (512×512)
    ├── wyymusic.ico            # Windows 图标 (多尺寸)
    └── tray_icon_mac.png       # 托盘图标
```

## 🚀 编译运行

### 环境要求

- **Qt** 6.x（需要 Core, Quick, Multimedia, WebSockets, Widgets, QuickControls2, Core5Compat, Network 模块）
- **CMake** ≥ 3.16
- **C++17** 编译器（MSVC / Clang / GCC）
- **Ninja**（推荐）

### macOS

```bash
# 配置 Qt 路径（根据实际安装路径修改）
export Qt6_DIR=~/Qt/6.x.x/macos/lib/cmake/Qt6

# 配置
cmake -B build -G Ninja

# 编译
cmake --build build --parallel

# 运行
open build/网狗音乐.app
```

### Windows

```bash
# 配置（使用 Qt 维护的 CMake）
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=C:/Qt/6.x.x/msvc2022_64

# 编译
cmake --build build --parallel

# 运行
build\网狗音乐.exe
```

> **注意**：Windows 运行时需要将 Qt 的 bin 目录加入 PATH，或使用 `windeployqt` 部署依赖。

### Linux

```bash
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x.x/gcc_64
cmake --build build --parallel
./build/网狗音乐
```

## ⚙️ 配置说明

应用配置和缓存存储在以下位置：

| 平台 | 缓存目录 |
|------|---------|
| macOS | `~/Downloads/网狗音乐缓存目录/` |
| Windows | `C:/网狗音乐缓存目录/` |

缓存内容包括：
- 播放列表 (`playlist_cache.json`)
- 最近播放 (`recent_cache.json`)
- 歌词缓存 (`lyrics_<hash>.json`)
- 下载的歌曲文件 (`歌曲名-歌手.mp3`)
- 网络图片缓存 (100MB, Qt 自动管理)

## 🔧 关键模块说明

### PlaylistManager — 播放核心

管理本地播放列表 (`m_playlist`) 和一起听播放列表 (`m_togetherplaylist`)，通过 `m_curplaylist` 指针在两种模式间切换。支持：
- 缓存文件优先播放，无缓存时边下边播
- 播放进度保存/恢复（退出时自动保存，启动时恢复到上次位置）
- 下载进度追踪和缓冲状态管理

### WebSocketClient — 一起听同步

基于 `QWebSocket` 的实时同步客户端：
- 心跳保活（30s 间隔，5 倍超时断开）
- 播放进度周期性同步（偏差 > 3s 才 seek，避免频繁跳动）
- 消息发送确认机制（本地回显 + 超时重试）
- 防重入保护（同一首歌不重复加载）

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
