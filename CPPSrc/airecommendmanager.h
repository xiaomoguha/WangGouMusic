#ifndef AIRECOMMENDMANAGER_H
#define AIRECOMMENDMANAGER_H

#include "HttpGetRequester.h"
#include <QObject>
#include <QVariantList>

// AI 推荐：种子歌曲（hash）→ 搜索解析 album_audio_id → ai/recommend 生成相似歌单
class AiRecommendManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
public:
    explicit AiRecommendManager(QObject *parent = nullptr);

    Q_INVOKABLE void recommend(const QString &songhash, const QString &songname);
    bool busy() const;

signals:
    // 带种子 hash：只有发起请求的那一行才接收结果（各展开行互不串扰）
    void recommendDone(const QString &seedHash, const QVariantList &songs);
    void recommendFailed(const QString &seedHash, const QString &reason);
    void busyChanged();

private:
    HttpGetRequester m_searchRequester;    // hash -> album_audio_id
    HttpGetRequester m_recommendRequester; // album_audio_id -> 推荐歌单
    QString m_seedHash;
    QString m_seedName;
    bool m_busy = false;
    QString m_pendingHash;   // 单飞：生成期间的新请求缓存一个，完成后接续
    QString m_pendingName;
    void setBusy(bool busy);
    void startFlow(const QString &hash, const QString &name);
    void drainPending();
    void requestRecommend(const QString &mxid);
    void parseRecommend(const QByteArray &data);
    void fail(const QString &reason);
};

#endif // AIRECOMMENDMANAGER_H
