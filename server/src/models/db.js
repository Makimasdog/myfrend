const initSqlJs = require('sql.js');
const path = require('path');
const fs = require('fs');
const config = require('../config');

let db = null;

/**
 * sql.js 包装器 —— 提供兼容 better-sqlite3 的 API
 */
function wrapDatabase(sqlDb) {
  const origPrepare = sqlDb.prepare.bind(sqlDb);

  // 扩展 db 方法，模拟 better-sqlite3 API
  sqlDb.prepare = function (sql) {
    const stmt = origPrepare(sql);

    return {
      // 执行并返回单行对象
      get(...params) {
        try {
          stmt.bind(params.map(v => v === undefined ? null : v));
          if (stmt.step()) {
            const row = {...stmt.getAsObject()};
            stmt.free();
            return row;
          }
          stmt.free();
          return undefined;
        } catch (e) {
          stmt.free();
          throw e;
        }
      },

      // 执行并返回所有行
      all(...params) {
        try {
          stmt.bind(params.map(v => v === undefined ? null : v));
          const results = [];
          while (stmt.step()) {
            results.push({...stmt.getAsObject()});
          }
          stmt.free();
          return results;
        } catch (e) {
          stmt.free();
          throw e;
        }
      },

      // 执行写操作（INSERT/UPDATE/DELETE）
      run(...params) {
        try {
          stmt.bind(params.map(v => v === undefined ? null : v));
          stmt.step(); // sql.js 中 step() 执行语句
          const changes = sqlDb.getRowsModified();
          stmt.free();
          return { changes };
        } catch (e) {
          stmt.free();
          throw e;
        }
      },
    };
  };

  // 直接 exec 方法用于多语句
  sqlDb.execMulti = function (sql) {
    return sqlDb.exec(sql);
  };

  return sqlDb;
}

/**
 * 初始化数据库（异步，需在启动时 await）
 */
async function initDatabase() {
  const SQL = await initSqlJs();

  const dbDir = path.dirname(config.dbPath);
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  // 尝试从文件加载已有数据库
  if (fs.existsSync(config.dbPath)) {
    const fileBuffer = fs.readFileSync(config.dbPath);
    db = new SQL.Database(fileBuffer);
  } else {
    db = new SQL.Database();
  }

  // 包装 API
  db = wrapDatabase(db);

  // 启用外键约束
  db.run('PRAGMA foreign_keys = ON');

  // ===================== 数据库表初始化 =====================
  const tables = [
    `CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      nickname TEXT,
      avatar_url TEXT,
      gender TEXT DEFAULT 'other',
      bio TEXT DEFAULT '',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    )`,
    `CREATE TABLE IF NOT EXISTS ai_friends (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL,
      gender TEXT DEFAULT 'other',
      age_range TEXT,
      personality TEXT,
      avatar_url TEXT,
      voice_type TEXT DEFAULT 'default',
      system_prompt TEXT,
      extra_config TEXT DEFAULT '{}',
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (owner_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS chat_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      friend_id TEXT NOT NULL,
      friend_type TEXT NOT NULL CHECK(friend_type IN ('ai', 'human')),
      title TEXT DEFAULT '新对话',
      last_message TEXT,
      last_message_at TEXT DEFAULT (datetime('now')),
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_type TEXT NOT NULL CHECK(sender_type IN ('user', 'ai', 'human')),
      content TEXT NOT NULL,
      content_type TEXT DEFAULT 'text' CHECK(content_type IN ('text', 'voice', 'image')),
      voice_url TEXT,
      is_read INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (session_id) REFERENCES chat_sessions(id)
    )`,
    `CREATE TABLE IF NOT EXISTS user_llm_configs (
      id TEXT PRIMARY KEY,
      user_id TEXT UNIQUE NOT NULL,
      api_base_url TEXT,
      api_key TEXT,
      model TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS friendships (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      friend_id TEXT NOT NULL,
      status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'accepted', 'blocked')),
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (friend_id) REFERENCES users(id),
      UNIQUE(user_id, friend_id)
    )`,
    `CREATE TABLE IF NOT EXISTS advisor_logs (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      ai_friend_id TEXT NOT NULL,
      advice_content TEXT NOT NULL,
      context_snapshot TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (session_id) REFERENCES chat_sessions(id),
      FOREIGN KEY (ai_friend_id) REFERENCES ai_friends(id)
    )`,
    `CREATE TABLE IF NOT EXISTS user_memories (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      ai_friend_id TEXT NOT NULL,
      fact TEXT NOT NULL,
      source_message TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (ai_friend_id) REFERENCES ai_friends(id)
    )`,
  ];

  for (const sql of tables) {
    db.run(sql);
  }

  // 持久化到磁盘
  saveToDisk();

  console.log('[DB] SQLite 数据库已初始化:', config.dbPath);
  return db;
}

/**
 * 将数据库保存到磁盘
 */
function saveToDisk() {
  if (!db) return;
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(config.dbPath, buffer);
}

/**
 * 获取数据库实例（确保已初始化）
 */
function getDb() {
  if (!db) throw new Error('数据库未初始化，请先调用 initDatabase()');
  return db;
}

/**
 * 默认导出为 Proxy，自动转发到数据库实例
 * 这样所有 require('../models/db') 的代码无需改动即可直接调用 db.prepare() 等
 */
const defaultExport = new Proxy({}, {
  get(target, prop) {
    // 优先返回命名导出
    if (prop === 'initDatabase') return initDatabase;
    if (prop === 'getDb') return getDb;
    if (prop === 'saveToDisk') return saveToDisk;
    // 其他属性转发到数据库实例
    if (db) return typeof db[prop] === 'function' ? db[prop].bind(db) : db[prop];
    return undefined;
  }
});

module.exports = defaultExport;
