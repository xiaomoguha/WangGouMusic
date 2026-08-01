#ifndef CRASHHANDLER_H
#define CRASHHANDLER_H

#include <QString>

/*
 * 跨平台崩溃日志处理器
 *
 * 功能：
 * 1. 捕获 Qt 日志消息（qDebug/qInfo/qWarning/qCritical）写入滚动日志文件 + 内存环形缓冲
 * 2. 捕获致命信号（SIGSEGV/SIGABRT/SIGFPE/SIGILL/SIGBUS）生成崩溃报告（含堆栈回溯）
 * 3. Windows 额外捕获 SEH 异常并生成 MiniDump (.dmp)
 * 4. 启动时检测上次崩溃日志，弹窗通知用户
 *
 * 使用方法：
 *   int main(int argc, char *argv[]) {
 *       CrashHandler::install();              // <- 在 QApplication 之前调用
 *       QApplication app(argc, argv);
 *       CrashHandler::checkPreviousCrash();   // <- 在 QApplication 之后调用
 *       ...
 *   }
 */
class CrashHandler
{
public:
    // 在 main() 最开始、QApplication 之前调用
    // 安装 Qt 消息处理器 + 崩溃信号处理器
    static void install();

    // 在 QApplication 构造之后调用
    // 检测上次崩溃日志，如有则弹窗提示用户
    static void checkPreviousCrash();

    // 获取日志目录路径
    static QString logDir();

    // 在系统文件管理器中打开日志目录
    static void openLogDir();
};

#endif // CRASHHANDLER_H
