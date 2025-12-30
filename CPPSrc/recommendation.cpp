#include "recommendation.h"
#include <QDebug>
#include <QJsonParseError>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
Recommendation::Recommendation(QObject *parent):
    QObject{parent},
    getSelectedGoodSongsdata(10000,this),  // 初始化并设置父对象
    getClassicnostalgicgoldenoldiesdata(10000,this),
    getSelectedPopularHitsdata(10000,this),
    getRareandexquisitemasterpiecesdata(10000,this),
    getKeepingupwiththelatesttrendsdata(10000,this),
    getExclusiverecommendationforVIPsongsdata(10000,this),
    getmansongsdata(10000,this)
{
    QObject::connect(&getSelectedGoodSongsdata, &HttpGetRequester::dataReceived,this,&Recommendation::SelectedGoodSongsdata);
    QObject::connect(&getClassicnostalgicgoldenoldiesdata, &HttpGetRequester::dataReceived,this,&Recommendation::Classicnostalgicgoldenoldiesdata);
    QObject::connect(&getSelectedPopularHitsdata, &HttpGetRequester::dataReceived,this,&Recommendation::SelectedPopularHitsdata);
    QObject::connect(&getRareandexquisitemasterpiecesdata, &HttpGetRequester::dataReceived,this,&Recommendation::Rareandexquisitemasterpiecesdata);
    QObject::connect(&getKeepingupwiththelatesttrendsdata, &HttpGetRequester::dataReceived,this,&Recommendation::Keepingupwiththelatesttrendsdata);
    QObject::connect(&getExclusiverecommendationforVIPsongsdata, &HttpGetRequester::dataReceived,this,&Recommendation::ExclusiverecommendationforVIPsongsdata);
    QObject::connect(&getmansongsdata, &HttpGetRequester::dataReceived,this,&Recommendation::Manitemsongsdata);
}

void Recommendation::SelectedGoodSongsdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    SelectedGoodSongsitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        SelectedGoodSongsitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit SelectedGoodSongsChanged();
}
void Recommendation::Classicnostalgicgoldenoldiesdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    Classicnostalgicgoldenoldiesitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        Classicnostalgicgoldenoldiesitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit ClassicnostalgicgoldenoldiesChanged();
}
void Recommendation::SelectedPopularHitsdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    SelectedPopularHitsitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        SelectedPopularHitsitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit SelectedPopularHitsChanged();
}
void Recommendation::Rareandexquisitemasterpiecesdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    Rareandexquisitemasterpiecesitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        Rareandexquisitemasterpiecesitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit RareandexquisitemasterpiecesChanged();
}
void Recommendation::Keepingupwiththelatesttrendsdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    Keepingupwiththelatesttrendsitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        Keepingupwiththelatesttrendsitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit KeepingupwiththelatesttrendsChanged();
}
void Recommendation::ExclusiverecommendationforVIPsongsdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    ExclusiverecommendationforVIPsongsitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["song_list"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QJsonArray singerinfo = song["singerinfo"].toArray();;
        const QString singername = (singerinfo[0])["name"].toString();
        const QString songName = song["songname"].toString();
        const QString hash = song["hash"].toString();
        const QString album_name = song["album_name"].toString();
        const QString sizable_cover = song["sizable_cover"].toString().replace("{size}","1024");;
        const double time_length_s = song["time_length"].toDouble();
        const QString time_length = secondsToMinutesSeconds((int)time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        ExclusiverecommendationforVIPsongsitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit ExclusiverecommendationforVIPsongsChanged();
}

void Recommendation::Manitemsongsdata(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error != QJsonParseError::NoError)
    {
        qWarning() << "JSON parse error:" << error.errorString();
        return;
    }

    if (!doc.isObject())
    {
        qWarning() << "Not a JSON object";
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject dataObj = root["data"].toObject();
    Mansongsitems.clear();


    // 解析歌曲列表
    const QJsonArray songs = dataObj["lists"].toArray();
    for (const QJsonValue &songVal : songs)
    {
        QJsonObject song = songVal.toObject();
        const QString singername = song["SingerName"].toString();
        const QString songName = song["OriSongName"].toString();
        const QString hash = (song["HQ"].toObject())["Hash"].toString();
        const QString album_name = song["AlbumName"].toString();
        const QString sizable_cover = song["Image"].toString().replace("{size}","1024");;
        const int time_length_s = song["Duration"].toInt();
        const QString time_length = secondsToMinutesSeconds(time_length_s);

        QVariantMap item;
        item["songname"] = songName;
        item["singername"] = singername;
        item["duration"] = time_length;
        item["album_name"] = album_name;
        item["songhash"] = hash;
        item["union_cover"] = sizable_cover;

        Mansongsitems.append(item);
        //qDebug() << "歌曲:"<< songName << "歌名" << singername<<"专辑"<<album_name<<"hash"<<hash<<"歌曲长度"<<time_length<<"歌曲秒数"<<time_length_s<<"图片url:"<<sizable_cover;
    }
    emit manChanged();
}

void Recommendation::getdatabygetdatarange(int getdatarange)
{
    switch (getdatarange)
    {
    case SelectedGoodSongs:
        getSelectedGoodSongsdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=1");
        break;
    case Classicnostalgicgoldenoldies:
        getClassicnostalgicgoldenoldiesdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=2");
        break;
    case SelectedPopularHits:
        getSelectedPopularHitsdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=3");
        break;
    case Rareandexquisitemasterpieces:
        getRareandexquisitemasterpiecesdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=4");
        break;
    case Keepingupwiththelatesttrends:
        getKeepingupwiththelatesttrendsdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=5");
        break;
    case ExclusiverecommendationforVIPsongs:
        getExclusiverecommendationforVIPsongsdata.fetchData("https://xjt-togethertracks.top/api/top/card?card_id=6");
        break;
    case Man:
        getmansongsdata.fetchData("https://xjt-togethertracks.top/api/searchtwo");
        break;
    default:
        break;
    }
}

QVariantList Recommendation::getSelectedGoodSongsitemsqml() const
{
    return SelectedGoodSongsitems;
}

QVariantList Recommendation::getClassicnostalgicgoldenoldiesitemsqml() const
{
    return Classicnostalgicgoldenoldiesitems;
}

QVariantList Recommendation::getSelectedPopularHitsitemsqml() const
{
    return SelectedPopularHitsitems;
}

QVariantList Recommendation::getRareandexquisitemasterpiecesitemsqml() const
{
    return Rareandexquisitemasterpiecesitems;
}

QVariantList Recommendation::getKeepingupwiththelatesttrendsitemsqml() const
{
    return Keepingupwiththelatesttrendsitems;
}

QVariantList Recommendation::getExclusiverecommendationforVIPsongsitemsqml() const
{
    return ExclusiverecommendationforVIPsongsitems;
}

QVariantList Recommendation::getmanitemsqml() const
{
    return Mansongsitems;
}
QString Recommendation::secondsToMinutesSeconds(int totalSeconds)
{
    QTime time(0, 0); // 初始化为 00:00:00
    time = time.addSecs(totalSeconds); // 添加秒数
    return time.toString("mm:ss"); // 格式化为 "分钟:秒"
}
