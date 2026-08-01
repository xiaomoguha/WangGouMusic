#include "CrashHandler.h"
#include "PlaylistCacheStore.h"

#include <QAtomicInt>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QMessageBox>
#include <QFileInfo>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTimer>
#include <QUrl>
#include <QtGlobal>

#include <cstring>
#include <ctime>
#include <cstdarg>
#include <clocale> // setlocale — 让 Windows C 运行时按 UTF-8 解析中文路径

#ifndef APP_VERSION
#define APP_VERSION "unknown"
#endif

// ==================== 平台头文件 ====================

#ifdef Q_OS_MAC
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#elif defined(Q_OS_WIN)
#include <windows.h>
#include <dbghelp.h>
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <csignal> // signal()、SIGSEGV/SIGABRT/SIGFPE/SIGILL 等
#pragma comment(lib, "dbghelp.lib")
#endif

// ==================== 跨平台低级 I/O 宏 ====================

#ifdef Q_OS_WIN
#define CRASH_OPEN(path, flags, mode) _open(path, flags, mode)
#define CRASH_WRITE(fd, buf, len) _write(fd, buf, (unsigned)(len))
#define CRASH_CLOSE(fd) _close(fd)
#define CRASH_O_WRONLY _O_WRONLY
#define CRASH_O_CREAT _O_CREAT
#define CRASH_O_TRUNC _O_TRUNC
#define CRASH_MODE (_S_IREAD | _S_IWRITE)
#else
#define CRASH_OPEN(path, flags, mode) open(path, flags, mode)
#define CRASH_WRITE(fd, buf, len) write(fd, buf, len)
#define CRASH_CLOSE(fd) close(fd)
#define CRASH_O_WRONLY O_WRONLY
#define CRASH_O_CREAT O_CREAT
#define CRASH_O_TRUNC O_TRUNC
#define CRASH_MODE 0644
#endif

// ==================== 全局静态数据 ====================

// 日志目录路径（install() 时写入，信号处理器中只读）
static char s_logDir[1024] = {0};

// 预计算的系统信息（install() 时写入，崩溃报告中只读）
static char s_sysInfo[2048] = {0};

// 内存环形缓冲：保存最近的日志消息，供崩溃报告引用
// 使用预分配的静态数组，信号处理器中可直接读取，无需堆分配
static constexpr int RING_SIZE     = 2000; // 缓冲行数
static constexpr int RING_LINE_MAX = 1024; // 每行最大字节数
static char s_ringBuf[RING_SIZE][RING_LINE_MAX];
static QAtomicInt s_ringHead(0); // 下一个写入位置

// 本次启动的会话日志文件（消息处理器中使用）
static FILE *s_logFile = nullptr;
static QMutex s_fileMutex;

// 单份会话日志文件的最大大小（10MB），超过后滚动
static constexpr long long LOG_MAX_SIZE = 10 * 1024 * 1024;
// 当前会话日志文件路径（滚动时需要重建路径）
static char s_sessionPath[1100] = {0};

// 最多保留的日志文件数量
static constexpr int MAX_LOG_FILES = 100;

// ==================== 信号安全写入辅助 ====================
// 以下函数仅使用 async-signal-safe 的操作（write / strlen / vsnprintf）

static void writeStr(int fd, const char *s)
{
    if (s)
    {
        size_t len = 0;
        while (s[len])
            len++;
        if (len > 0)
            CRASH_WRITE(fd, s, len);
    }
}

static void writeFmt(int fd, const char *fmt, ...)
{
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n > 0)
    {
        if (n > (int)sizeof(buf))
            n = (int)sizeof(buf);
        CRASH_WRITE(fd, buf, n);
    }
}

// ==================== 崩溃报告生成 ====================

static void generateCrashReport(
    int signalNum, const char *signalName
#ifdef Q_OS_WIN
    ,
    EXCEPTION_POINTERS *ep = nullptr
#endif
)
{
    // 生成文件名：crash_YYYYMMDD_HHMMSS.log
    time_t now    = time(nullptr);
    struct tm *lt = localtime(&now);

    char filename[1100];
    snprintf(
        filename, sizeof(filename), "%s/crash_%04d%02d%02d_%02d%02d%02d.log", s_logDir, lt->tm_year + 1900,
        lt->tm_mon + 1, lt->tm_mday, lt->tm_hour, lt->tm_min, lt->tm_sec
    );

    int fd = CRASH_OPEN(filename, CRASH_O_WRONLY | CRASH_O_CREAT | CRASH_O_TRUNC, CRASH_MODE);
    if (fd < 0)
        return;

    // --- 头部 ---
    writeStr(fd, "========================================\n");
    writeStr(fd, "  网狗音乐 崩溃报告\n");
    writeStr(fd, "========================================\n\n");

    // 时间戳
    writeFmt(
        fd, "崩溃时间: %04d-%02d-%02d %02d:%02d:%02d\n", lt->tm_year + 1900, lt->tm_mon + 1, lt->tm_mday, lt->tm_hour,
        lt->tm_min, lt->tm_sec
    );

    // 崩溃类型
    writeFmt(fd, "崩溃类型: %s (%d)\n", signalName, signalNum);

#ifdef Q_OS_WIN
    if (ep && ep->ExceptionRecord)
    {
        writeFmt(fd, "异常代码: 0x%08lX\n", (unsigned long)ep->ExceptionRecord->ExceptionCode);
        writeFmt(fd, "异常地址: 0x%p\n", ep->ExceptionRecord->ExceptionAddress);
    }
#endif

    // 系统信息（预计算）
    writeStr(fd, "\n");
    writeStr(fd, s_sysInfo);

    // --- 堆栈回溯 ---
    writeStr(fd, "\n--- 堆栈回溯 ---\n");

#ifdef Q_OS_MAC
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    // backtrace_symbols_fd 直接写入 fd，无堆分配
    backtrace_symbols_fd(callstack, frames, fd);

#elif defined(Q_OS_WIN)
    if (ep)
    {
        // 使用 dbghelp 的 StackWalk64 获取带符号名的调用栈
        HANDLE hProcess = GetCurrentProcess();
        SymSetOptions(SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES);
        SymInitialize(hProcess, nullptr, TRUE);

        CONTEXT ctx = *ep->ContextRecord;
        STACKFRAME64 sf;
        memset(&sf, 0, sizeof(sf));

#ifdef _M_IX86
        DWORD machineType   = IMAGE_FILE_MACHINE_I386;
        sf.AddrPC.Offset    = ctx.Eip;
        sf.AddrStack.Offset = ctx.Esp;
        sf.AddrFrame.Offset = ctx.Ebp;
#elif defined(_M_X64)
        DWORD machineType   = IMAGE_FILE_MACHINE_AMD64;
        sf.AddrPC.Offset    = ctx.Rip;
        sf.AddrStack.Offset = ctx.Rsp;
        sf.AddrFrame.Offset = ctx.Rbp;
#elif defined(_M_ARM64)
        DWORD machineType   = IMAGE_FILE_MACHINE_ARM64;
        sf.AddrPC.Offset    = ctx.Pc;
        sf.AddrStack.Offset = ctx.Sp;
        sf.AddrFrame.Offset = ctx.Fp;
#else
        DWORD machineType = IMAGE_FILE_MACHINE_UNKNOWN;
#endif
        sf.AddrPC.Mode = sf.AddrStack.Mode = sf.AddrFrame.Mode = AddrModeFlat;

        int frameNum = 0;
        while (StackWalk64(
            machineType, hProcess, GetCurrentThread(), &sf, &ctx, nullptr, SymFunctionTableAccess64, SymGetModuleBase64,
            nullptr
        ))
        {
            if (frameNum++ > 64)
                break;

            DWORD64 addr = sf.AddrPC.Offset;
            char symbolBuf[sizeof(SYMBOL_INFO) + 256];
            PSYMBOL_INFO symbol  = (PSYMBOL_INFO)symbolBuf;
            symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
            symbol->MaxNameLen   = 256;

            DWORD64 disp = 0;
            if (SymFromAddr(hProcess, addr, &disp, symbol))
            {
                IMAGEHLP_MODULE64 modInfo;
                modInfo.SizeOfStruct = sizeof(IMAGEHLP_MODULE64);
                const char *modName  = "?";
                if (SymGetModuleInfo64(hProcess, sf.AddrPC.Offset, &modInfo))
                    modName = modInfo.ModuleName;
                writeFmt(
                    fd, "  [%2d] %s!%s +0x%llx  (0x%llx)\n", frameNum, modName, symbol->Name, (unsigned long long)disp,
                    (unsigned long long)addr
                );
            }
            else
            {
                writeFmt(fd, "  [%2d] 0x%llx (no symbol)\n", frameNum, (unsigned long long)addr);
            }
        }
    }
    else
    {
        // 无 EXCEPTION_POINTERS，用 CaptureStackBackTrace 兜底
        void *stack[64];
        USHORT frames = CaptureStackBackTrace(0, 64, stack, nullptr);
        for (int i = 0; i < (int)frames; i++)
            writeFmt(fd, "  [%2d] 0x%p\n", i, stack[i]);
    }
#endif

    // --- 最近日志（环形缓冲） ---
    writeStr(fd, "\n--- 最近日志 ---\n");
    {
        int head  = s_ringHead.loadAcquire();
        int count = (head < RING_SIZE) ? head : RING_SIZE;
        int start = (head < RING_SIZE) ? 0 : (head % RING_SIZE);
        for (int i = 0; i < count; i++)
        {
            int idx = (start + i) % RING_SIZE;
            writeStr(fd, s_ringBuf[idx]);
            writeStr(fd, "\n");
        }
    }

    // --- 尾部 ---
    writeStr(fd, "\n========================================\n");
    writeStr(fd, "请将此文件发送给开发者以帮助排查问题。\n");
    writeFmt(fd, "日志目录: %s\n", s_logDir);
    writeStr(fd, "========================================\n");

    CRASH_CLOSE(fd);

    // Windows: 额外生成 MiniDump (.dmp) 供 WinDbg / VS 调试
#ifdef Q_OS_WIN
    if (ep)
    {
        char dumpFile[1100];
        snprintf(
            dumpFile, sizeof(dumpFile), "%s/crash_%04d%02d%02d_%02d%02d%02d.dmp", s_logDir, lt->tm_year + 1900,
            lt->tm_mon + 1, lt->tm_mday, lt->tm_hour, lt->tm_min, lt->tm_sec
        );
        HANDLE hFile = CreateFileA(dumpFile, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile != INVALID_HANDLE_VALUE)
        {
            MINIDUMP_EXCEPTION_INFORMATION mei;
            mei.ThreadId          = GetCurrentThreadId();
            mei.ExceptionPointers = ep;
            mei.ClientPointers    = FALSE;
            MiniDumpWriteDump(
                GetCurrentProcess(), GetCurrentProcessId(), hFile, MiniDumpNormal, &mei, nullptr, nullptr
            );
            CloseHandle(hFile);
        }
    }
#endif
}

// ==================== 信号处理器 ====================

static void crashSignalHandler(int sig)
{
    const char *sigName = "UNKNOWN";
    switch (sig)
    {
    case SIGSEGV:
        sigName = "SIGSEGV (段错误)";
        break;
    case SIGABRT:
        sigName = "SIGABRT (异常终止)";
        break;
    case SIGFPE:
        sigName = "SIGFPE (浮点异常/除零)";
        break;
    case SIGILL:
        sigName = "SIGILL (非法指令)";
        break;
#ifndef Q_OS_WIN
    case SIGBUS:
        sigName = "SIGBUS (总线错误)";
        break;
#endif
    }

    generateCrashReport(sig, sigName);

    // 恢复默认信号处理并重新触发，让系统生成 core dump（如果启用了）
#ifndef Q_OS_WIN
    signal(sig, SIG_DFL);
    raise(sig);
#endif

    _exit(1);
}

// ==================== Windows SEH 异常过滤器 ====================

#ifdef Q_OS_WIN
static LONG WINAPI windowsExceptionFilter(EXCEPTION_POINTERS *ep)
{
    const char *excName = "UNKNOWN";
    DWORD code          = ep->ExceptionRecord->ExceptionCode;
    switch (code)
    {
    case EXCEPTION_ACCESS_VIOLATION:
        excName = "ACCESS_VIOLATION (内存访问违规)";
        break;
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
        excName = "ARRAY_BOUNDS_EXCEEDED";
        break;
    case EXCEPTION_DATATYPE_MISALIGNMENT:
        excName = "DATATYPE_MISALIGNMENT";
        break;
    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
        excName = "FLT_DIVIDE_BY_ZERO";
        break;
    case EXCEPTION_ILLEGAL_INSTRUCTION:
        excName = "ILLEGAL_INSTRUCTION";
        break;
    case EXCEPTION_IN_PAGE_ERROR:
        excName = "IN_PAGE_ERROR";
        break;
    case EXCEPTION_INT_DIVIDE_BY_ZERO:
        excName = "INT_DIVIDE_BY_ZERO";
        break;
    case EXCEPTION_STACK_OVERFLOW:
        excName = "STACK_OVERFLOW (栈溢出)";
        break;
    }

    generateCrashReport((int)code, excName, ep);
    _exit(1);
    // return EXCEPTION_EXECUTE_HANDLER;  // 不会执行到
}
#endif

// ==================== Qt 消息处理器 ====================
// 将 qDebug/qInfo/qWarning/qCritical 输出同时写入：
// 1. 内存环形缓冲（供崩溃报告引用）
// 2. 本次启动的会话日志文件（超过 10MB 后滚动为 .old，新建续写）

static void qtMessageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg)
{
    // 格式化消息（使用 qSetMessagePattern 设定的格式）
    QString formatted = qFormatLogMessage(type, ctx, msg);

    // 1. 写入环形缓冲（原子索引，无锁，最差情况丢失一行）
    QByteArray utf8 = formatted.toUtf8();
    {
        int idx     = s_ringHead.fetchAndAddOrdered(1) % RING_SIZE;
        int copyLen = utf8.size();
        if (copyLen >= RING_LINE_MAX)
            copyLen = RING_LINE_MAX - 1;
        memcpy(s_ringBuf[idx], utf8.constData(), copyLen);
        s_ringBuf[idx][copyLen] = '\0';
    }

    // 2. 写入会话日志文件（10MB 超限时自动滚动）
    {
        QMutexLocker locker(&s_fileMutex);
        if (s_logFile)
        {
            // 检查文件大小，超过 10MB 则滚动
            long pos = ftell(s_logFile);
            if (pos > LOG_MAX_SIZE)
            {
                fclose(s_logFile);
                // 当前 session 文件重命名为 .old，然后新建同名文件继续写
                char oldPath[1100];
                snprintf(oldPath, sizeof(oldPath), "%s.old", s_sessionPath);
                remove(oldPath);
                rename(s_sessionPath, oldPath);
                s_logFile = fopen(s_sessionPath, "w");
            }
            if (s_logFile)
            {
                fputs(utf8.constData(), s_logFile);
                fputc('\n', s_logFile);
                fflush(s_logFile);
            }
        }
    }

    // 3. Debug 构建同时输出到 stderr
#ifdef QT_DEBUG
    fputs(utf8.constData(), stderr);
    fputc('\n', stderr);
    fflush(stderr);
#endif
}

// ==================== 日志目录计算 ====================
// 复用 PlaylistCacheStore::cacheDir()：避免在此处再 #ifdef Q_OS_WIN 一次，
// 缓存目录搬迁时只需改一处。
static QString computeLogDir()
{
    return PlaylistCacheStore::cacheDir() + QStringLiteral("/logs");
}

// 清理旧日志文件，保留最新的 MAX_LOG_FILES 份
// 同时匹配 session_*.log 和 crash_*.log
static void pruneOldLogs()
{
    QDir dir(s_logDir);
    if (!dir.exists())
        return;

    QStringList filters;
    filters << "session_*.log" << "session_*.log.old" << "crash_*.log" << "crash_*.dmp";
    dir.setNameFilters(filters);
    dir.setSorting(QDir::Time); // 按修改时间排序（最新在前）

    QFileInfoList files = dir.entryInfoList(QDir::Files);
    if (files.size() <= MAX_LOG_FILES)
        return;

    // 删除超出的旧文件（第 MAX_LOG_FILES 之后的全删）
    for (int i = MAX_LOG_FILES; i < files.size(); i++)
    {
        QFile::remove(files[i].absoluteFilePath());
    }
    qDebug().noquote() << "日志清理: 保留了" << MAX_LOG_FILES << "份文件，删除了" << (files.size() - MAX_LOG_FILES)
                       << "份旧文件";
}

// ==================== 公开接口 ====================

void CrashHandler::install()
{
#ifdef Q_OS_WIN
    // Windows C 运行时默认按系统代码页（GBK）解析文件路径。本项目的日志路径含中文
    // （C:/网狗音乐缓存目录/logs），但代码以 UTF-8 传递，两者不匹配会导致
    // fopen/_open/rename 等全部失败（返回 nullptr/-1），日志文件无法创建。
    // 设置 locale 为 UTF-8 后，C 运行时函数即可正确处理 UTF-8 中文路径。
    // 要求 Windows 10 1803+（2018 年 4 月发布）。
    setlocale(LC_ALL, ".UTF8");
#endif

    // 1. 计算日志目录（与缓存目录同级）
    QString dir = computeLogDir();
    QDir().mkpath(dir);

    QByteArray dirUtf8 = dir.toUtf8();
    strncpy(s_logDir, dirUtf8.constData(), sizeof(s_logDir) - 1);
    s_logDir[sizeof(s_logDir) - 1] = '\0';

    // 2. 设置 Qt 日志格式
    qSetMessagePattern("[%{time yyyy.MM.dd hh:mm:ss.zzz}] [%{type}] %{message}");

    // 3. 预计算系统信息（崩溃报告中只读访问，不调用 Qt API）
    QSysInfo sysInfo;
    snprintf(
        s_sysInfo, sizeof(s_sysInfo),
        "应用版本: %s\n"
        "操作系统: %s\n"
        "系统版本: %s\n"
        "CPU 架构: %s\n"
        "Qt 版本: %s\n"
        "日志目录: %s\n",
        APP_VERSION, sysInfo.prettyProductName().toUtf8().constData(), sysInfo.productVersion().toUtf8().constData(),
        sysInfo.currentCpuArchitecture().toUtf8().constData(), QT_VERSION_STR, s_logDir
    );

    // 4. 本次启动创建新的会话日志文件：session_YYYYMMDD_HHMMSS.log
    QDateTime now       = QDateTime::currentDateTime();
    QString sessionName = QStringLiteral("session_%1.log").arg(now.toString(QStringLiteral("yyyyMMdd_HHmmss")));
    snprintf(s_sessionPath, sizeof(s_sessionPath), "%s/%s", s_logDir, sessionName.toUtf8().constData());
    s_logFile = fopen(s_sessionPath, "w");

    // 5. 安装 Qt 消息处理器
    qInstallMessageHandler(qtMessageHandler);

    // 写入启动标记
    qDebug().noquote() << "========== 网狗音乐启动 ==========";
    qDebug().noquote()
        << QString("Version: %1  OS: %2  Qt: %3").arg(APP_VERSION).arg(sysInfo.prettyProductName()).arg(QT_VERSION_STR);

    // 6. 安装信号处理器
    signal(SIGSEGV, crashSignalHandler);
    signal(SIGABRT, crashSignalHandler);
    signal(SIGFPE, crashSignalHandler);
    signal(SIGILL, crashSignalHandler);
#ifndef Q_OS_WIN
    signal(SIGBUS, crashSignalHandler);
#endif

#ifdef Q_OS_WIN
    // 7. Windows SEH 异常过滤器
    SetUnhandledExceptionFilter(windowsExceptionFilter);
#endif

    // 8. 清理旧日志，保留最新 100 份
    pruneOldLogs();
}

QString CrashHandler::logDir()
{
    return QString::fromUtf8(s_logDir);
}

void CrashHandler::openLogDir()
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(logDir()));
}

void CrashHandler::checkPreviousCrash()
{
    QDir dir(logDir());
    if (!dir.exists())
        return;

    // 查找最新的 crash_*.log 文件
    QStringList filters;
    filters << "crash_*.log";
    dir.setNameFilters(filters);
    dir.setSorting(QDir::Time);

    QFileInfoList files = dir.entryInfoList(QDir::Files);
    if (files.isEmpty())
        return;

    QFileInfo latest = files.first();

    // 延迟 2 秒显示弹窗，避免阻塞启动界面
    QTimer::singleShot(
        2000,
        [latest]()
        {
            QString msg = QString(
                              "检测到上一次运行时发生了崩溃。\n\n"
                              "崩溃文件: %1\n"
                              "崩溃时间: %2\n\n"
                              "是否打开日志目录查看详情？\n"
                              "您可以将崩溃日志发送给开发者以帮助排查问题。"
            )
                              .arg(latest.fileName())
                              .arg(latest.lastModified().toString("yyyy-MM-dd hh:mm:ss"));

            auto ret = QMessageBox::question(
                nullptr, "崩溃日志检测", msg, QMessageBox::Yes | QMessageBox::No, QMessageBox::Yes
            );

            if (ret == QMessageBox::Yes)
            {
                openLogDir();
            }
        }
    );
}
