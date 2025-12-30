// lyricparser.cpp
#include "lyricparser.h"

LyricParser::LyricParser(QObject *parent) : QObject(parent)
{
}

bool LyricParser::parseLyrics(const QString &lyricText)
{
    m_lyrics.clear();

    if (lyricText.isEmpty()) {
        qWarning() << "歌词文本为空";
        return false;
    }

    // 移除UTF-8 BOM头（如果有）
    QString text = lyricText;
    if (text.startsWith("\uFEFF")) {
        text.remove(0, 1);
    }

    // 按行分割
    QStringList lines = text.split("\n", Qt::SkipEmptyParts);

    // 正则表达式匹配时间标签 [mm:ss.xx]
    QRegularExpression timeRegex("\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\]");

    for (const QString &line : lines) {
        QString trimmedLine = line.trimmed();
        if (trimmedLine.isEmpty()) {
            continue;
        }

        // 跳过元数据行（以 [字母: 开头）
        if (trimmedLine.startsWith("[ar:") || trimmedLine.startsWith("[ti:") ||
            trimmedLine.startsWith("[al:") || trimmedLine.startsWith("[by:") ||
            trimmedLine.startsWith("[offset:") || trimmedLine.startsWith("[total:") ||
            trimmedLine.startsWith("[hash:") || trimmedLine.startsWith("[sign:")) {
            continue;
        }

        // 匹配时间标签
        QRegularExpressionMatchIterator matchIterator = timeRegex.globalMatch(trimmedLine);
        QString lyricText = trimmedLine;

        // 移除所有时间标签，提取纯歌词文本
        while (matchIterator.hasNext()) {
            QRegularExpressionMatch match = matchIterator.next();
            QString timeStr = match.captured(0);
            lyricText.remove(timeStr);
        }

        lyricText = lyricText.trimmed();
        if (lyricText.isEmpty()) {
            continue;
        }

        // 重新匹配时间标签来获取时间
        matchIterator = timeRegex.globalMatch(trimmedLine);
        while (matchIterator.hasNext()) {
            QRegularExpressionMatch match = matchIterator.next();

            // 修正：使用正确的参数类型
            QString minuteStr = match.captured(1);
            QString secondStr = match.captured(2);
            QString millisecondStr = match.captured(3);

            qint64 timeMs = timeStringToMs(minuteStr, secondStr, millisecondStr);

            // 添加到歌词列表
            m_lyrics.append(LyricLine(timeMs, lyricText));
        }
    }

    // 按时间排序
    std::sort(m_lyrics.begin(), m_lyrics.end(),
              [](const LyricLine &a, const LyricLine &b) {
                  return a.time < b.time;
              });

    qDebug() << "歌词解析完成，共" << m_lyrics.size() << "行歌词";
    emit parselyricsuc();
    return !m_lyrics.isEmpty();
}

QString LyricParser::getLyricAtTime(qint64 positionMs)
{
    if (m_lyrics.isEmpty()) {
        return "暂无歌词";
    }

    // 如果当前位置小于第一句歌词的时间，显示第一句
    if (positionMs < m_lyrics.first().time) {
        return m_lyrics.first().text;
    }

    // 如果当前位置超过最后一句歌词的时间，显示最后一句
    if (positionMs >= m_lyrics.last().time) {
        return m_lyrics.last().text;
    }

    // 二分查找算法找到当前时间对应的歌词
    int left = 0;
    int right = m_lyrics.size() - 1;
    int resultIndex = 0;

    while (left <= right) {
        int mid = left + (right - left) / 2;

        if (m_lyrics[mid].time <= positionMs) {
            resultIndex = mid;
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    curlyricindex = resultIndex;

    return m_lyrics[resultIndex].text;
}

QVector<LyricLine> LyricParser::getLyrics() const
{
    return m_lyrics;
}

void LyricParser::clear()
{
    m_lyrics.clear();
}

bool LyricParser::hasLyrics() const
{
    return !m_lyrics.isEmpty();
}

qint64 LyricParser::getcurindex()
{
    return curlyricindex;
}

qint64 LyricParser::timeStringToMs(const QString &minuteStr, const QString &secondStr, const QString &millisecondStr) const
{
    // 将字符串转换为整数
    int minutes = minuteStr.toInt();
    int seconds = secondStr.toInt();
    int milliseconds = millisecondStr.toInt(); // 两位数，如84表示840毫秒

    return minutes * 60000 + seconds * 1000 + milliseconds * 10;
}
