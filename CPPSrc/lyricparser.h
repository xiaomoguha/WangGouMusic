// lyricparser.h
#ifndef LYRICPARSER_H
#define LYRICPARSER_H

#include <QObject>
#include <QVector>
#include <QString>
#include <QRegularExpression>
#include <QPair>

// 单个字结构体
struct LyricChar
{
    qint64 startTime; // 字开始时间（毫秒）
    qint64 duration;  // 字持续时间（毫秒）
    QString text;     // 字符文本

    LyricChar(qint64 start = 0, qint64 dur = 0, const QString &txt = "")
        : startTime(start), duration(dur), text(txt) {}
};
Q_DECLARE_METATYPE(LyricChar)

// 歌词行结构体
struct LyricLine
{
    Q_GADGET
    Q_PROPERTY(QString text MEMBER text)
    Q_PROPERTY(QVariantList chars MEMBER chars)
public:
    qint64 time;        // 行开始时间（毫秒）
    qint64 duration;    // 行持续时间（毫秒）
    QString text;       // 完整歌词文本
    QVariantList chars; // 逐字信息列表

    LyricLine(qint64 t = 0, qint64 dur = 0, const QString &txt = "", const QVariantList &c = QVariantList())
        : time(t), duration(dur), text(txt), chars(c) {}
};
Q_DECLARE_METATYPE(LyricLine)

class LyricParser : public QObject
{
    Q_OBJECT

signals:
    void parselyricsuc(); // 自定义信号

public:
    explicit LyricParser(QObject *parent = nullptr);

    // 解析标准LRC歌词
    bool parseLyrics(const QString &lyricText);

    // 解析KRC逐字歌词
    bool parseKRCLyrics(const QString &krcText);

    // 根据时间获取当前歌词
    QString getLyricAtTime(qint64 positionMs);

    // 根据时间获取当前逐字高亮索引（-1表示无）
    int getCharIndexAtTime(qint64 positionMs);

    // 获取当前字符的高亮进度（0.0-1.0）
    float getCharProgressAtTime(qint64 positionMs);

    // 获取当前歌词行的逐字信息
    QVariantList getCurrentChars(qint64 positionMs);

    // 获取所有解析后的歌词
    QVector<LyricLine> getLyrics() const;

    // 清空歌词数据
    void clear();

    // 检查是否有歌词数据
    bool hasLyrics() const;

    qint64 getcurindex();

    // 获取当前行索引
    int getCurrentLineIndex(qint64 positionMs);

private:
    // 将时间字符串转换为毫秒
    qint64 timeStringToMs(const QString &minuteStr, const QString &secondStr, const QString &millisecondStr) const;

    QVector<LyricLine> m_lyrics;

    qint64 curlyricindex = 0;
};

#endif // LYRICPARSER_H
