const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');

const aiFriendService = {
  /**
   * 创建 AI 朋友
   */
  create(ownerId, data) {
    const id = uuidv4();
    const {
      name, gender = 'other', ageRange = null, personality = null,
      avatarUrl = null, voiceType = 'default',
      systemPrompt = null, extraConfig = '{}'
    } = data;

    db.prepare(`
      INSERT INTO ai_friends (id, owner_id, name, gender, age_range, personality, avatar_url, voice_type, system_prompt, extra_config)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, ownerId, name, gender, ageRange, personality, avatarUrl, voiceType, systemPrompt, JSON.stringify(extraConfig));

    return this.getById(id, ownerId);
  },

  /**
   * 获取用户的 AI 朋友列表
   */
  listByOwner(ownerId) {
    return db.prepare(`
      SELECT id, name, gender, age_range, personality, avatar_url, voice_type, is_active, created_at
      FROM ai_friends WHERE owner_id = ? AND is_active = 1
      ORDER BY created_at DESC
    `).all(ownerId);
  },

  /**
   * 获取单个 AI 朋友详情
   */
  getById(id, ownerId) {
    return db.prepare(`
      SELECT * FROM ai_friends WHERE id = ? AND owner_id = ?
    `).get(id, ownerId);
  },

  /**
   * 更新 AI 朋友
   */
  update(id, ownerId, data) {
    const existing = this.getById(id, ownerId);
    if (!existing) throw new Error('AI 朋友不存在');

    const allowed = ['name', 'gender', 'age_range', 'personality', 'avatar_url', 'voice_type', 'system_prompt', 'extra_config', 'is_active'];
    const updates = [];
    const values = [];

    for (const key of allowed) {
      if (data[key] !== undefined) {
        updates.push(`${key} = ?`);
        values.push(typeof data[key] === 'object' ? JSON.stringify(data[key]) : data[key]);
      }
    }

    if (updates.length === 0) return existing;

    updates.push("updated_at = datetime('now')");
    values.push(id, ownerId);

    db.prepare(`UPDATE ai_friends SET ${updates.join(', ')} WHERE id = ? AND owner_id = ?`).run(...values);
    return this.getById(id, ownerId);
  },

  /**
   * 删除（软删除）AI 朋友
   */
  remove(id, ownerId) {
    db.prepare(`UPDATE ai_friends SET is_active = 0, updated_at = datetime('now') WHERE id = ? AND owner_id = ?`)
      .run(id, ownerId);
  },
};

module.exports = aiFriendService;
