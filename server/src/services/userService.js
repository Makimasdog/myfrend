const db = require('../models/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');

const userService = {
  /**
   * 用户注册
   */
  register(username, password, nickname) {
    const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
    if (existing) {
      throw new Error('用户名已存在');
    }

    const id = uuidv4();
    const passwordHash = bcrypt.hashSync(password, 10);
    
    db.prepare(`
      INSERT INTO users (id, username, password_hash, nickname)
      VALUES (?, ?, ?, ?)
    `).run(id, username, passwordHash, nickname || username);

    return this.generateToken({ id, username });
  },

  /**
   * 用户登录
   */
  login(username, password) {
    const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!user) {
      throw new Error('用户名或密码错误');
    }

    const valid = bcrypt.compareSync(password, user.password_hash);
    if (!valid) {
      throw new Error('用户名或密码错误');
    }

    return this.generateToken({ id: user.id, username: user.username });
  },

  /**
   * 生成 JWT
   */
  generateToken(payload) {
    const token = jwt.sign(payload, config.jwtSecret, { expiresIn: '7d' });
    return { token, user: payload };
  },

  /**
   * 获取用户信息
   */
  getUserById(id) {
    const user = db.prepare(`
      SELECT id, username, nickname, avatar_url, gender, bio, created_at
      FROM users WHERE id = ?
    `).get(id);
    if (!user) throw new Error('用户不存在');
    return user;
  },

  /**
   * 更新用户资料
   */
  updateProfile(id, fields) {
    const allowed = ['nickname', 'avatar_url', 'gender', 'bio'];
    const updates = [];
    const values = [];

    for (const key of allowed) {
      if (fields[key] !== undefined) {
        updates.push(`${key} = ?`);
        values.push(fields[key]);
      }
    }

    if (updates.length === 0) return this.getUserById(id);

    updates.push("updated_at = datetime('now')");
    values.push(id);

    db.prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`).run(...values);
    return this.getUserById(id);
  },
};

module.exports = userService;
