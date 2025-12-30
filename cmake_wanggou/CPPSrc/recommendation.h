#ifndef RECOMMENDATION_H
#define RECOMMENDATION_H
#include <QObject>
#include "HttpGetRequester.h"
class Recommendation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList manitemsqml READ getmanitemsqml NOTIFY manChanged)
    Q_PROPERTY(QVariantList SelectedGoodSongsitemsqml READ getSelectedGoodSongsitemsqml NOTIFY SelectedGoodSongsChanged)
    Q_PROPERTY(QVariantList Classicnostalgicgoldenoldiesitemsqml READ getClassicnostalgicgoldenoldiesitemsqml NOTIFY ClassicnostalgicgoldenoldiesChanged)
    Q_PROPERTY(QVariantList SelectedPopularHitsitemsqml READ getSelectedPopularHitsitemsqml NOTIFY SelectedPopularHitsChanged)
    Q_PROPERTY(QVariantList Rareandexquisitemasterpiecesitemsqml READ getRareandexquisitemasterpiecesitemsqml NOTIFY RareandexquisitemasterpiecesChanged)
    Q_PROPERTY(QVariantList Keepingupwiththelatesttrendsitemsqml READ getKeepingupwiththelatesttrendsitemsqml NOTIFY KeepingupwiththelatesttrendsChanged)
    Q_PROPERTY(QVariantList ExclusiverecommendationforVIPsongsitemsqml READ getExclusiverecommendationforVIPsongsitemsqml NOTIFY ExclusiverecommendationforVIPsongsChanged)

public:
    explicit Recommendation(QObject *parent = nullptr);
    HttpGetRequester getSelectedGoodSongsdata;
    HttpGetRequester getClassicnostalgicgoldenoldiesdata;
    HttpGetRequester getSelectedPopularHitsdata;
    HttpGetRequester getRareandexquisitemasterpiecesdata;
    HttpGetRequester getKeepingupwiththelatesttrendsdata;
    HttpGetRequester getExclusiverecommendationforVIPsongsdata;
    HttpGetRequester getmansongsdata;
    enum getdatarange
    {
        SelectedGoodSongs,                      //精选好歌随心听
        Classicnostalgicgoldenoldies,           //经典怀旧金曲
        SelectedPopularHits,                    //热门好歌精选
        Rareandexquisitemasterpieces,           //小众宝藏佳作
        Keepingupwiththelatesttrends,           //潮流尝鲜
        ExclusiverecommendationforVIPsongs,     //VIP歌曲专属推荐
        Man                                     //嫚姐常用接口
    };
public:
    Q_INVOKABLE void getdatabygetdatarange(int getdatarange);
    QString secondsToMinutesSeconds(int totalSeconds);
    QVariantList getSelectedGoodSongsitemsqml() const;
    QVariantList getClassicnostalgicgoldenoldiesitemsqml() const;
    QVariantList getSelectedPopularHitsitemsqml() const;
    QVariantList getRareandexquisitemasterpiecesitemsqml() const;
    QVariantList getKeepingupwiththelatesttrendsitemsqml() const;
    QVariantList getExclusiverecommendationforVIPsongsitemsqml() const;
    QVariantList getmanitemsqml() const;

public:
    QVariantList Mansongsitems;
    QVariantList SelectedGoodSongsitems;
    QVariantList Classicnostalgicgoldenoldiesitems;
    QVariantList SelectedPopularHitsitems;
    QVariantList Rareandexquisitemasterpiecesitems;
    QVariantList Keepingupwiththelatesttrendsitems;
    QVariantList ExclusiverecommendationforVIPsongsitems;
signals:
    void SelectedGoodSongsChanged();
    void ClassicnostalgicgoldenoldiesChanged();
    void RareandexquisitemasterpiecesChanged();
    void KeepingupwiththelatesttrendsChanged();
    void ExclusiverecommendationforVIPsongsChanged();
    void SelectedPopularHitsChanged();
    void manChanged();
public slots:
    void SelectedGoodSongsdata(const QByteArray &data);
    void Classicnostalgicgoldenoldiesdata(const QByteArray &data);
    void SelectedPopularHitsdata(const QByteArray &data);
    void Rareandexquisitemasterpiecesdata(const QByteArray &data);
    void Keepingupwiththelatesttrendsdata(const QByteArray &data);
    void ExclusiverecommendationforVIPsongsdata(const QByteArray &data);
    void Manitemsongsdata(const QByteArray &data);
};

#endif // RECOMMENDATION_H
