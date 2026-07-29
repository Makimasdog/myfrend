const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');

const chatService = {
  getOrCreateSession(userId, friendId, friendType) {
    let session = db.prepare(`
      SELECT * FROM chat_sessions WHERE user_id = ? AND friend_id = ? AND friend_type = ?
    `).get(userId, friendId, friendType);

    if (!session) {
      const id = uuidv4();
      db.prepare(`
        INSERT INTO chat_sessions (id, user_id, friend_id, friend_type)
        VALUES (?, ?, ?, ?)
      `).run(id, userId, friendId, friendType);
      session = db.prepare('SELECT * FROM chat_sessions WHERE id = ?').get(id);
    }

    return session;
  },

  listByUser(userId) {
    return db.prepare(`
      SELECT cs.*,
        CASE WHEN cs.friend_type = 'ai' THEN af.name
             WHEN cs.friend_type = 'human' THEN u.nickname
        END as friend_name,
        CASE WHEN cs.friend_type = 'ai' THEN af.avatar_url
             WHEN cs.friend_type = 'human' THEN u.avatar_url
        END as friend_avatar
      FROM chat_sessions cs
      LEFT JOIN ai_friends af ON cs.friend_id = af.id AND cs.friend_type = 'ai'
      LEFT JOIN users u ON cs.friend_id = u.id AND cs.friend_type = 'human'
      WHERE cs.user_id = ?
      ORDER BY cs.last_message_at DESC
    `).all(userId);
  },

  sendMessage(sessionId, senderId, senderType, content, contentType, voiceUrl) {
    const id = uuidv4();
    db.prepare(`
      INSERT INTO messages (id, session_id, sender_id, sender_type, content, content_type, voice_url)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(id, sessionId, senderId, senderType, content, contentType || 'text', voiceUrl || null);

    db.prepare(`
      UPDATE chat_sessions SET last_message = ?, last_message_at = datetime('now')
      WHERE id = ?
    `).run((content || '').substring(0, 200), sessionId);

    return this.getMessageById(id);
  },

  getMessages(sessionId, limit, offset) {
    return db.prepare(`
      SELECT * FROM messages WHERE session_id = ?
      ORDER BY rowid DESC
      LIMIT ? OFFSET ?
    `).all(sessionId, limit || 50, offset || 0).reverse();
  },

  getMessageById(id) {
    return db.prepare('SELECT * FROM messages WHERE id = ?').get(id);
  },

  markAsRead(messageIds) {
    for (const id of messageIds) {
      db.prepare('UPDATE messages SET is_read = 1 WHERE id = ?').run(id);
    }
  },
};

module.exports = chatService;
