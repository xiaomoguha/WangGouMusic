#include "mvmanager.h"

#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>

namespace
{
const char *const kApiRoot = "https://api.special520.com";
} // namespace

MvManager::MvManager(QObject *parent) : QObject(parent)
{
    connect(&m_requester, &HttpGetRequester::dataReceived, this, &MvManager::onVideoUrlData);
    const auto fail    = [this](const QString &err) { onFailed(err); };
    const auto timeout = [this]() { onFailed(QStringLiteral("timeout")); };
    connect(&m_requester, &HttpGetRequester::requestFailed, this, fail);
    connect(&m_requester, &HttpGetRequester::requestTimeout, this, timeout);
}

void MvManager::fetchVideoUrl(const QString &hash)
{
    if (hash.isEmpty())
        return;
    qDebug() << "[MvManager] fetchVideoUrl 发起请求 hash:" << hash;
    m_lastHash = hash;
    m_requester.fetchData(QStringLiteral("%1/video/url?hash=%2").arg(kApiRoot).arg(hash));
}

// 响应：data.{hash: {downurl, backupdownurl[], filesize}}（url 带有效期，不可缓存）// 注意：搜索/歌单数据源的 mvhash 对部分歌曲无效（MV 不存在），上游返回 40002 Not found
void MvManager::onVideoUrlData(const QByteArray &data)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
    {
        qWarning() << "[MvManager] video url parse error:" << perr.errorString();
        emit videoUrlFailed(m_lastHash);
        return;
    }
    const QJsonObject dataObj = doc.object()["data"].toObject();
    for (auto it = dataObj.constBegin(); it != dataObj.constEnd(); ++it)
    {
        const QString hash = it.key();
        const QString url  = it.value().toObject()["downurl"].toString();
        if (!url.isEmpty())
        {
            qDebug() << "[MvManager] 拿到 downurl hash:" << hash << "长度:" << url.size();
            // 回传请求时的原样 hash：歌单数据源 mvhash 是大写、酷狗响应是小写，
            // 消费方按原样比较才不会因大小写失配丢掉 URL
            emit videoUrlReceived(m_lastHash, url);
            return;
        }
    }
    qWarning() << "[MvManager] video url empty (MV 可能不存在或已下架)";
    emit videoUrlFailed(m_lastHash);
}

void MvManager::onFailed(const QString &err)
{
    qWarning() << "[MvManager] request error:" << err;
    emit videoUrlFailed(m_lastHash);
}
