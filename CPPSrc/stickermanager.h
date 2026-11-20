#ifndef STICKERMANAGER_H
#define STICKERMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QSet>
#include <QVariantList>

class UserManager;

/**
 * @brief 一起听表情包管理
 *
 * 服务端持久化（内容哈希命名 + 账号索引），本地目录只做文件缓存。
 * 本地结构：<缓存根>/stickers/<id>.<ext>，最近使用存 <缓存根>/config/sticker_recent.json
 */
class StickerManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList library READ library NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList recent READ recent NOTIFY recentChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit StickerManager(UserManager *userManager, QObject *parent = nullptr);

    QVariantList library() const { return m_library; }
    QVariantList recent() const { return m_recent; }
    int revision() const { return m_revision; }
    bool busy() const { return m_busy; }

    /// 拉取账号表情索引并下载缺失文件
    Q_INVOKABLE void refresh();
    /// 添加本地图片/动图（≤2MB），上传后加入账号表情库
    Q_INVOKABLE void addFile(const QString &path);
    /// 拖放添加：上传成功后直接发送到当前一起听房间
    Q_INVOKABLE void addFileAndSend(const QString &path);
    /// 把已有表情编号加入我的表情库（右键别人发的表情）
    Q_INVOKABLE void addSticker(const QString &id);
    /// 从我的表情库移除
    Q_INVOKABLE void removeSticker(const QString &id);
    /// 本地文件 URL；未缓存时触发下载并返回空串（完成后 revision 变化）
    Q_INVOKABLE QString pathFor(const QString &id);
    /// 记录最近使用
    Q_INVOKABLE void markRecent(const QString &id);

signals:
    void libraryChanged();
    void recentChanged();
    void revisionChanged();
    void busyChanged();
    void errorOccurred(const QString &message);
    void notice(const QString &message);
    // 上传完成：send=true 表示这是拖放发送，QML 收到后发到房间
    void fileAdded(const QString &id, bool send);

private:
    void addFileInternal(const QString &path, bool send);
    QString userid() const;
    QString cacheDir() const;
    QString cachePath(const QString &id) const;
    void download(const QString &id);
    void setBusy(bool busy);
    void bump();
    void saveRecent();

    UserManager *m_userManager = nullptr;
    QNetworkAccessManager m_nam;
    QVariantList m_library;
    QVariantList m_recent;
    QSet<QString> m_downloading;
    int m_revision = 0;
    bool m_busy = false;
};

#endif // STICKERMANAGER_H
