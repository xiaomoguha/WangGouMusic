// 本文件承载两部分内容：
//   1) SongInfo.h 的 Q_GADGET moc 输出（AUTOMOC 需要同名 cpp 来生成
//      staticMetaObject，否则链接时 "undefined SongInfo::staticMetaObject"）；
//   2) hash→album_audio_id 登记表（见 SongInfo.h 的说明）。
#include "SongInfo.h"

#include <QHash>
#include <QJsonValue>
#include <QLatin1String>

namespace {
// 各接口给 album_audio_id 用的字段名：搜索/排行是 album_audio_id，
// 歌单 tracks 是 mixsongid（同一个 id 的两种叫法）
const char *const kIdKeys[] = {"album_audio_id", "mixsongid"};
// 部分接口把歌曲信息裹了一层
const char *const kNestedKeys[] = {"audio_info", "base", "audio"};

// id 在 JSON 里可能是数字也可能是字符串
QString idText(const QJsonValue &value)
{
    if (value.isString())
        return value.toString().trimmed();
    const qint64 id = value.toVariant().toLongLong();
    return id > 0 ? QString::number(id) : QString();
}

// 键统一大写（接口回来的 hash 大小写不一）。只在主线程读写（各 manager 的网络
// 回调都在主线程），故不加锁；条目数上限是"本次运行见过的歌"，内存可忽略。
QHash<QString, QString> &mxidRegistry()
{
    static QHash<QString, QString> registry;
    return registry;
}
} // namespace

QString SongInfo::mxidFromJson(const QJsonObject &songObj)
{
    for (const char *key : kIdKeys)
    {
        const QString id = idText(songObj.value(QLatin1String(key)));
        if (!id.isEmpty())
            return id;
    }
    for (const char *nested : kNestedKeys)
    {
        const QJsonObject sub = songObj.value(QLatin1String(nested)).toObject();
        if (sub.isEmpty())
            continue;
        for (const char *key : kIdKeys)
        {
            const QString id = idText(sub.value(QLatin1String(key)));
            if (!id.isEmpty())
                return id;
        }
    }
    return QString();
}

void SongInfo::rememberMxidFromJson(const QJsonObject &songObj, const QString &hash)
{
    if (hash.isEmpty())
        return;
    const QString id = mxidFromJson(songObj);
    if (id.isEmpty())
        return;
    mxidRegistry().insert(hash.toUpper(), id);
}

QString SongInfo::cachedMxid(const QString &hash)
{
    if (hash.isEmpty())
        return QString();
    return mxidRegistry().value(hash.toUpper());
}
