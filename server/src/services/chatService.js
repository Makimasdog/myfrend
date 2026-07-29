const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');

const VALID_FRIEND_TYPES = new Set(['ai', 'human']);
const VALID_CONTENT_TYPES = new Set(['text', 'voice', 'image']);
const MAX_MESSAGE_LENGTH = 4000;

function assertMessageInput(content, contentType) {
  if (typeof content !== 'string' || !content.trim()) {
    throw new Error('Message content is required');
  }
  if (content.length > MAX_MESSAGE_LENGTH) {
    throw new Error(`Message content must be ${MAX_MESSAGE_LENGTH} characters or fewer`);
  }
  if (!VALID_CONTENT_TYPES.has(contentType || 'text')) {
    throw new Error('Unsupported message content type');
  }
}

const chatService = {
  getOwnedSession(sessionId, userId) {
    return db.prepare(`
      SELECT * FROM chat_sessions WHERE id = ? AND user_id = ?
    `).get(sessionId, userId);
  },

  getOrCreateSession(userId, friendId, friendType) {
    if (!friendId || !VALID_FRIEND_TYPES.has(friendType)) {
      throw new Error('Invalid chat session target');
    }

    this.assertSessionTarget(userId, friendId, friendType);

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

  assertSessionTarget(userId, friendId, friendType) {
    if (friendType === 'ai') {
      const friend = db.prepare(`
        SELECT id FROM ai_friends WHERE id = ? AND owner_id = ? AND is_active = 1
      `).get(friendId, userId);
      if (!friend) {
        throw new Error('AI friend not found');
      }
      return;
    }

    if (friendId === userId) {
      throw new Error('You cannot start a chat with yourself');
    }
    const friend = db.prepare('SELECT id FROM users WHERE id = ?').get(friendId);
    if (!friend) {
      throw new Error('Friend not found');
    }
    if (!this.areFriends(userId, friendId)) {
      throw new Error('An accepted friendship is required before chatting');
    }
  },

  areFriends(userId, friendId) {
    return Boolean(db.prepare(`
      SELECT id FROM friendships
      WHERE user_id = ? AND friend_id = ? AND status = 'accepted'
    `).get(userId, friendId));
  },

  listByUser(userId) {
    return db.prepare(`
      SELECT cs.*,
        CASE WHEN cs.friend_type = 'ai' THEN af.name
             WHEN cs.friend_type = 'human' THEN COALESCE(u.nickname, u.username)
        END AS friend_name,
        CASE WHEN cs.friend_type = 'ai' THEN af.avatar_url
             WHEN cs.friend_type = 'human' THEN u.avatar_url
        END AS friend_avatar
      FROM chat_sessions cs
      LEFT JOIN ai_friends af ON cs.friend_id = af.id AND cs.friend_type = 'ai'
      LEFT JOIN users u ON cs.friend_id = u.id AND cs.friend_type = 'human'
      WHERE cs.user_id = ?
      ORDER BY cs.last_message_at DESC
    `).all(userId);
  },

  sendMessage(sessionId, senderId, senderType, content, contentType = 'text', voiceUrl = null) {
    assertMessageInput(content, contentType);

    const id = uuidv4();
    db.prepare(`
      INSERT INTO messages (id, session_id, sender_id, sender_type, content, content_type, voice_url)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(id, sessionId, senderId, senderType, content.trim(), contentType, voiceUrl || null);

    const preview = contentType === 'voice'
      ? '[Voice message]'
      : contentType === 'image'
        ? '[Image]'
        : content.trim().substring(0, 200);
    db.prepare(`
      UPDATE chat_sessions SET last_message = ?, last_message_at = datetime('now')
      WHERE id = ?
    `).run(preview, sessionId);

    return this.getMessageById(id);
  },

  sendHumanMessage(userId, sessionId, content, contentType = 'text', voiceUrl = null) {
    const senderSession = this.getOwnedSession(sessionId, userId);
    if (!senderSession || senderSession.friend_type !== 'human') {
      throw new Error('Human chat session not found');
    }
    this.assertSessionTarget(userId, senderSession.friend_id, 'human');

    const senderMessage = this.sendMessage(
      senderSession.id,
      userId,
      'user',
      content,
      contentType,
      voiceUrl
    );
    const recipientSession = this.getOrCreateSession(
      senderSession.friend_id,
      userId,
      'human'
    );
    const recipientMessage = this.sendMessage(
      recipientSession.id,
      userId,
      'human',
      content,
      contentType,
      voiceUrl
    );

    return { senderMessage, recipientMessage, recipientSession };
  },

  getMessages(sessionId, limit = 50, offset = 0) {
    const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
    const safeOffset = Math.max(Number(offset) || 0, 0);
    return db.prepare(`
      SELECT * FROM messages WHERE session_id = ?
      ORDER BY rowid DESC
      LIMIT ? OFFSET ?
    `).all(sessionId, safeLimit, safeOffset).reverse();
  },

  getMessageById(id) {
    return db.prepare('SELECT * FROM messages WHERE id = ?').get(id);
  },

  markAsReadForUser(userId, messageIds) {
    let updatedCount = 0;
    for (const id of messageIds) {
      const result = db.prepare(`
        UPDATE messages
        SET is_read = 1
        WHERE id = ?
          AND sender_id != ?
          AND session_id IN (
            SELECT id FROM chat_sessions WHERE user_id = ?
          )
      `).run(id, userId, userId);
      updatedCount += result.changes;
    }
    return updatedCount;
  },
};

module.exports = chatService;
