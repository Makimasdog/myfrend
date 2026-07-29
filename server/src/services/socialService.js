const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');

const socialService = {
  /**
   * 搜索用户
   */
  searchUsers(query, excludeUserId, limit = 20) {
    return db.prepare(`
      SELECT id, username, nickname, avatar_url, gender, bio
      FROM users
      WHERE id != ? AND (username LIKE ? OR nickname LIKE ? OR bio LIKE ?)
      LIMIT ?
    `).all(excludeUserId, `%${query}%`, `%${query}%`, `%${query}%`, limit);
  },

  /**
   * 发送好友请求
   */
  sendFriendRequest(userId, friendId) {
    const existing = db.prepare(`
      SELECT * FROM friendships WHERE user_id = ? AND friend_id = ?
    `).get(userId, friendId);

    if (existing) {
      throw new Error(existing.status === 'pending' ? '已发送过好友请求' : 
                      existing.status === 'accepted' ? '你们已经是好友了' : '无法发送请求');
    }

    const id = uuidv4();
    db.prepare(`
      INSERT INTO friendships (id, user_id, friend_id, status) VALUES (?, ?, ?, 'pending')
    `).run(id, userId, friendId);

    return { id, status: 'pending' };
  },

  /**
   * 接受好友请求
   */
  acceptFriendRequest(userId, requestId) {
    const request = db.prepare(`
      SELECT * FROM friendships WHERE id = ? AND friend_id = ? AND status = 'pending'
    `).get(requestId, userId);

    if (!request) throw new Error('好友请求不存在或已处理');

    db.prepare(`
      UPDATE friendships SET status = 'accepted', updated_at = datetime('now') WHERE id = ?
    `).run(requestId);

    // 创建反向好友关系
    const existing = db.prepare(`
      SELECT * FROM friendships WHERE user_id = ? AND friend_id = ?
    `).get(userId, request.user_id);

    if (!existing) {
      db.prepare(`
        INSERT INTO friendships (id, user_id, friend_id, status) VALUES (?, ?, ?, 'accepted')
      `).run(uuidv4(), userId, request.user_id);
    }

    return { status: 'accepted' };
  },

  /**
   * 获取好友列表
   */
  getFriendList(userId) {
    return db.prepare(`
      SELECT u.id, u.username, u.nickname, u.avatar_url, u.gender, u.bio, f.created_at as friends_since
      FROM friendships f
      JOIN users u ON f.friend_id = u.id
      WHERE f.user_id = ? AND f.status = 'accepted'
      ORDER BY f.updated_at DESC
    `).all(userId);
  },

  /**
   * 获取待处理的好友请求
   */
  getPendingRequests(userId) {
    return db.prepare(`
      SELECT f.id as request_id, f.created_at,
             u.id as user_id, u.username, u.nickname, u.avatar_url
      FROM friendships f
      JOIN users u ON f.user_id = u.id
      WHERE f.friend_id = ? AND f.status = 'pending'
      ORDER BY f.created_at DESC
    `).all(userId);
  },
};

module.exports = socialService;
