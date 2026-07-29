const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');

const VALID_GENDERS = new Set(['male', 'female', 'other']);

function normalizeName(name) {
  if (typeof name !== 'string' || !name.trim()) {
    throw new Error('AI friend name is required');
  }
  const normalized = name.trim();
  if (normalized.length > 80) {
    throw new Error('AI friend name must be 80 characters or fewer');
  }
  return normalized;
}

function normalizeExtraConfig(value) {
  if (value == null || value === '') return {};
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed;
    } catch (_) {
      throw new Error('extraConfig must be a JSON object');
    }
  }
  if (typeof value === 'object' && !Array.isArray(value)) return value;
  throw new Error('extraConfig must be a JSON object');
}

const aiFriendService = {
  create(ownerId, data) {
    const id = uuidv4();
    const name = normalizeName(data.name);
    const gender = data.gender || 'other';
    if (!VALID_GENDERS.has(gender)) {
      throw new Error('Invalid gender');
    }

    db.prepare(`
      INSERT INTO ai_friends (
        id, owner_id, name, gender, age_range, personality, avatar_url,
        voice_type, system_prompt, extra_config
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      ownerId,
      name,
      gender,
      data.ageRange ?? data.age_range ?? null,
      data.personality ?? null,
      data.avatarUrl ?? data.avatar_url ?? null,
      data.voiceType ?? data.voice_type ?? 'default',
      data.systemPrompt ?? data.system_prompt ?? null,
      JSON.stringify(normalizeExtraConfig(data.extraConfig ?? data.extra_config))
    );

    return this.getById(id, ownerId);
  },

  listByOwner(ownerId) {
    return db.prepare(`
      SELECT id, owner_id, name, gender, age_range, personality, avatar_url,
             voice_type, is_active, created_at, updated_at, extra_config
      FROM ai_friends
      WHERE owner_id = ? AND is_active = 1
      ORDER BY created_at DESC
    `).all(ownerId);
  },

  getById(id, ownerId) {
    return db.prepare(`
      SELECT * FROM ai_friends WHERE id = ? AND owner_id = ?
    `).get(id, ownerId);
  },

  update(id, ownerId, data) {
    const existing = this.getById(id, ownerId);
    if (!existing) throw new Error('AI friend not found');

    const updates = [];
    const values = [];
    const fieldMap = {
      ageRange: 'age_range',
      avatarUrl: 'avatar_url',
      voiceType: 'voice_type',
      systemPrompt: 'system_prompt',
    };

    if (data.name !== undefined) {
      updates.push('name = ?');
      values.push(normalizeName(data.name));
    }
    if (data.gender !== undefined) {
      if (!VALID_GENDERS.has(data.gender)) throw new Error('Invalid gender');
      updates.push('gender = ?');
      values.push(data.gender);
    }
    for (const key of ['age_range', 'personality', 'avatar_url', 'voice_type', 'system_prompt', 'is_active']) {
      if (data[key] !== undefined) {
        updates.push(`${key} = ?`);
        values.push(data[key]);
      }
    }
    for (const [source, target] of Object.entries(fieldMap)) {
      if (data[source] !== undefined) {
        updates.push(`${target} = ?`);
        values.push(data[source]);
      }
    }
    if (data.extraConfig !== undefined || data.extra_config !== undefined) {
      updates.push('extra_config = ?');
      values.push(JSON.stringify(normalizeExtraConfig(data.extraConfig ?? data.extra_config)));
    }

    if (updates.length === 0) return existing;

    updates.push("updated_at = datetime('now')");
    values.push(id, ownerId);
    db.prepare(`
      UPDATE ai_friends SET ${updates.join(', ')} WHERE id = ? AND owner_id = ?
    `).run(...values);
    return this.getById(id, ownerId);
  },

  remove(id, ownerId) {
    const result = db.prepare(`
      UPDATE ai_friends
      SET is_active = 0, updated_at = datetime('now')
      WHERE id = ? AND owner_id = ? AND is_active = 1
    `).run(id, ownerId);
    if (result.changes === 0) {
      throw new Error('AI friend not found');
    }
  },
};

module.exports = aiFriendService;
