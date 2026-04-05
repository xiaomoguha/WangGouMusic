// lyricparser.cpp
#include "lyricparser.h"

LyricParser::LyricParser(QObject *parent) : QObject(parent)
{
}

bool LyricParser::parseLyrics(const QString &lyricText)
{
    m_lyrics.clear();

    if (lyricText.isEmpty())
    {
        qWarning() << "歌词文本为空";
        return false;
    }

    // 移除UTF-8 BOM头（如果有）
    QString text = lyricText;
    if (text.startsWith("\uFEFF"))
    {
        text.remove(0, 1);
    }

    // 按行分割
    QStringList lines = text.split("\n", Qt::SkipEmptyParts);

    // 正则表达式匹配时间标签 [mm:ss.xx]
    QRegularExpression timeRegex("\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\]");

    for (const QString &line : lines)
    {
        QString trimmedLine = line.trimmed();
        if (trimmedLine.isEmpty())
        {
            continue;
        }

        // 跳过元数据行（以 [字母: 开头）
        if (trimmedLine.startsWith("[ar:") || trimmedLine.startsWith("[ti:") ||
            trimmedLine.startsWith("[al:") || trimmedLine.startsWith("[by:") ||
            trimmedLine.startsWith("[offset:") || trimmedLine.startsWith("[total:") ||
            trimmedLine.startsWith("[hash:") || trimmedLine.startsWith("[sign:"))
        {
            continue;
        }

        // 匹配时间标签
        QRegularExpressionMatchIterator matchIterator = timeRegex.globalMatch(trimmedLine);
        QString lyricText = trimmedLine;

        // 移除所有时间标签，提取纯歌词文本
        while (matchIterator.hasNext())
        {
            QRegularExpressionMatch match = matchIterator.next();
            QString timeStr = match.captured(0);
            lyricText.remove(timeStr);
        }

        lyricText = lyricText.trimmed();
        if (lyricText.isEmpty())
        {
            continue;
        }

        // 重新匹配时间标签来获取时间
        matchIterator = timeRegex.globalMatch(trimmedLine);
        while (matchIterator.hasNext())
        {
            QRegularExpressionMatch match = matchIterator.next();

            // 修正：使用正确的参数类型
            QString minuteStr = match.captured(1);
            QString secondStr = match.captured(2);
            QString millisecondStr = match.captured(3);

            qint64 timeMs = timeStringToMs(minuteStr, secondStr, millisecondStr);

            // 添加到歌词列表
            m_lyrics.append(LyricLine(timeMs, 0, lyricText, QVariantList()));
        }
    }

    // 按时间排序
    std::sort(m_lyrics.begin(), m_lyrics.end(),
              [](const LyricLine &a, const LyricLine &b)
              {
                  return a.time < b.time;
              });

    qDebug() << "歌词解析完成，共" << m_lyrics.size() << "行歌词";
    emit parselyricsuc();
    return !m_lyrics.isEmpty();
}

bool LyricParser::parseKRCLyrics(const QString &krcText)
{
    m_lyrics.clear();

    if (krcText.isEmpty())
    {
        qWarning() << "KRC歌词文本为空";
        return false;
    }

    QString text = krcText;
    // 移除UTF-8 BOM头
    if (text.startsWith("\uFEFF"))
    {
        text.remove(0, 1);
    }

    // 按行分割
    QStringList lines = text.split("\n", Qt::SkipEmptyParts);

    // KRC行格式: [开始时间,持续时间]<字偏移,字时长,0>字<字偏移,字时长,0>字...
    QRegularExpression lineRegex("\\[(\\d+),(\\d+)\\](.+)$");
    QRegularExpression charRegex("<(\\d+),(\\d+),\\d+>([^{<]+)");

    for (const QString &line : lines)
    {
        QString trimmedLine = line.trimmed();
        if (trimmedLine.isEmpty())
            continue;

        // 跳过元数据行
        if (trimmedLine.startsWith("[id:") || trimmedLine.startsWith("[ar:") ||
            trimmedLine.startsWith("[ti:") || trimmedLine.startsWith("[by:") ||
            trimmedLine.startsWith("[hash:") || trimmedLine.startsWith("[al:") ||
            trimmedLine.startsWith("[sign:") || trimmedLine.startsWith("[qq:") ||
            trimmedLine.startsWith("[total:") || trimmedLine.startsWith("[offset:") ||
            trimmedLine.startsWith("[language:"))
        {
            continue;
        }

        QRegularExpressionMatch lineMatch = lineRegex.match(trimmedLine);
        if (!lineMatch.hasMatch())
            continue;

        qint64 lineTime = lineMatch.captured(1).toLongLong();
        qint64 lineDuration = lineMatch.captured(2).toLongLong();
        QString charPart = lineMatch.captured(3);

        // 解析逐字
        QVariantList chars;
        QString fullText;
        QRegularExpressionMatchIterator charMatchIt = charRegex.globalMatch(charPart);

        while (charMatchIt.hasNext())
        {
            QRegularExpressionMatch charMatch = charMatchIt.next();
            qint64 charStart = charMatch.captured(1).toLongLong();
            qint64 charDuration = charMatch.captured(2).toLongLong();
            QString charText = charMatch.captured(3);

            LyricChar lc(charStart, charDuration, charText);
            chars.append(QVariant::fromValue(lc));
            fullText.append(charText);
        }

        if (!fullText.isEmpty())
        {
            LyricLine ll(lineTime, lineDuration, fullText, chars);
            m_lyrics.append(ll);
        }
    }

    // 按时间排序
    std::sort(m_lyrics.begin(), m_lyrics.end(),
              [](const LyricLine &a, const LyricLine &b)
              {
                  return a.time < b.time;
              });

    qDebug() << "KRC歌词解析完成，共" << m_lyrics.size() << "行";
    emit parselyricsuc();
    return !m_lyrics.isEmpty();
}

QString LyricParser::getLyricAtTime(qint64 positionMs)
{
    if (m_lyrics.isEmpty())
    {
        return "暂无歌词";
    }

    // 如果当前位置小于第一句歌词的时间，显示第一句
    if (positionMs < m_lyrics.first().time)
    {
        curlyricindex = 0;
        return m_lyrics.first().text;
    }

    // 如果当前位置超过最后一句歌词的时间，显示最后一句
    if (positionMs >= m_lyrics.last().time)
    {
        curlyricindex = m_lyrics.size() - 1;
        return m_lyrics.last().text;
    }

    // 二分查找算法找到当前时间对应的歌词
    int left = 0;
    int right = m_lyrics.size() - 1;
    int resultIndex = 0;

    while (left <= right)
    {
        int mid = left + (right - left) / 2;

        if (m_lyrics[mid].time <= positionMs)
        {
            resultIndex = mid;
            left = mid + 1;
        }
        else
        {
            right = mid - 1;
        }
    }

    curlyricindex = resultIndex;

    return m_lyrics[resultIndex].text;
}

int LyricParser::getCharIndexAtTime(qint64 positionMs)
{
    if (m_lyrics.isEmpty())
        return -1;

    // 找到当前行
    int lineIndex = getCurrentLineIndex(positionMs);
    if (lineIndex < 0 || lineIndex >= m_lyrics.size())
        return -1;

    const LyricLine &line = m_lyrics[lineIndex];
    if (line.chars.isEmpty())
        return -1;

    // 计算行内相对时间
    qint64 relativeTime = positionMs - line.time;

    // 记录找到的最接近的字（用于处理空白时间段）
    int lastPassedCharIndex = -1;

    // 找到当前字
    for (int i = 0; i < line.chars.size(); ++i)
    {
        QVariant v = line.chars.at(i);
        LyricChar lc = v.value<LyricChar>();

        // 字开始时间到结束时间之间
        if (relativeTime >= lc.startTime && relativeTime < lc.startTime + lc.duration)
        {
            return i;
        }

        // 记录已经过去的字（时间已超过该字的结束时间）
        if (relativeTime >= lc.startTime + lc.duration)
        {
            lastPassedCharIndex = i;
        }
    }

    // 如果有已经过去的字，返回最后一个已过去的字
    // 这确保在字结束后的空白时间也能正确显示
    if (lastPassedCharIndex >= 0)
    {
        return lastPassedCharIndex;
    }

    return -1;
}

float LyricParser::getCharProgressAtTime(qint64 positionMs)
{
    if (m_lyrics.isEmpty())
        return 0.0f;

    // 找到当前行
    int lineIndex = getCurrentLineIndex(positionMs);
    if (lineIndex < 0 || lineIndex >= m_lyrics.size())
        return 0.0f;

    const LyricLine &line = m_lyrics[lineIndex];
    if (line.chars.isEmpty())
        return 0.0f;

    // 计算行内相对时间
    qint64 relativeTime = positionMs - line.time;

    // 记录找到的最接近的字（用于处理空白时间段）
    int lastPassedCharIndex = -1;

    // 找到当前字并计算进度
    for (int i = 0; i < line.chars.size(); ++i)
    {
        QVariant v = line.chars.at(i);
        LyricChar lc = v.value<LyricChar>();

        // 字开始时间到结束时间之间
        if (relativeTime >= lc.startTime && relativeTime < lc.startTime + lc.duration)
        {
            // 计算当前字的播放进度
            qint64 elapsed = relativeTime - lc.startTime;
            return static_cast<float>(elapsed) / static_cast<float>(lc.duration);
        }

        // 记录已经过去的字
        if (relativeTime >= lc.startTime + lc.duration)
        {
            lastPassedCharIndex = i;
        }
    }

    // 如果有已经过去的字，返回 1.0（该字已完成）
    // 这与 getCharIndexAtTime 的逻辑一致
    if (lastPassedCharIndex >= 0)
    {
        return 1.0f;
    }

    return 0.0f;
}

QVariantList LyricParser::getCurrentChars(qint64 positionMs)
{
    QVariantList empty;
    if (m_lyrics.isEmpty())
        return empty;

    int lineIndex = getCurrentLineIndex(positionMs);
    if (lineIndex < 0 || lineIndex >= m_lyrics.size())
        return empty;

    return m_lyrics[lineIndex].chars;
}

int LyricParser::getCurrentLineIndex(qint64 positionMs)
{
    if (m_lyrics.isEmpty())
        return -1;

    if (positionMs < m_lyrics.first().time)
        return 0;

    if (positionMs >= m_lyrics.last().time)
        return m_lyrics.size() - 1;

    int left = 0;
    int right = m_lyrics.size() - 1;

    while (left <= right)
    {
        int mid = left + (right - left) / 2;

        if (m_lyrics[mid].time <= positionMs)
            left = mid + 1;
        else
            right = mid - 1;
    }

    return right;
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
