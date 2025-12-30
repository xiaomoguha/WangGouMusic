// lyricparser.h
#ifndef LYRICPARSER_H
#define LYRICPARSER_H

#include <QObject>
#include <QVector>
#include <QString>
#include <QRegularExpression>
#include <QPair>

// 歌词行结构体
struct LyricLine {
    Q_GADGET
    Q_PROPERTY(QString text MEMBER text)
public:
    qint64 time;    // 时间戳（毫秒）
    QString text;   // 歌词文本
    LyricLine(qint64 t = 0, const QString &txt = "") : time(t), text(txt) {}
};

class LyricParser : public QObject
{
    Q_OBJECT

signals:
    void parselyricsuc(); // 自定义信号

public:
    explicit LyricParser(QObject *parent = nullptr);

    // 解析歌词文本
    bool parseLyrics(const QString &lyricText);

    // 根据时间获取当前歌词
    QString getLyricAtTime(qint64 positionMs);

    // 获取所有解析后的歌词
    QVector<LyricLine> getLyrics() const;

    // 清空歌词数据
    void clear();

    // 检查是否有歌词数据
    bool hasLyrics() const;

    qint64 getcurindex();


private:
    // 将时间字符串转换为毫秒
    qint64 timeStringToMs(const QString &minuteStr, const QString &secondStr, const QString &millisecondStr) const;

    QVector<LyricLine> m_lyrics;

    qint64 curlyricindex = 0;


};

#endif // LYRICPARSER_H
