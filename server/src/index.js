const express = require('express');
const http = require('http');
const path = require('path');
const cors = require('cors');
const config = require('./config');
const { initDatabase, saveToDisk } = require('./models/db');
const { setupWebSocket } = require('./ws');

// 引入路由
const authRoutes = require('./routes/auth');
const aiFriendsRoutes = require('./routes/aiFriends');
const chatRoutes = require('./routes/chat');
const socialRoutes = require('./routes/social');
const advisorRoutes = require('./routes/advisor');
const llmRoutes = require('./routes/llm');
const uploadRoutes = require('./routes/upload');

async function main() {
  // ===================== 初始化数据库 =====================
  await initDatabase();

  const app = express();

  // ===================== 中间件 =====================
  app.use(cors());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // 请求日志
  app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
  });

  // ===================== 路由注册 =====================
  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', name: 'myfrends-server', version: '0.1.0' });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/ai-friends', aiFriendsRoutes);
  app.use('/api/chat', chatRoutes);
  app.use('/api/social', socialRoutes);
  app.use('/api/advisor', advisorRoutes);
  app.use('/api/llm', llmRoutes);
  app.use('/api/upload', uploadRoutes);

  // 静态文件服务 — 音频文件
  app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

  // ===================== 错误处理 =====================
  app.use((err, req, res, _next) => {
    console.error('[Error]', err.message);
    res.status(500).json({ error: '服务器内部错误' });
  });

  // ===================== 启动服务器 =====================
  const server = http.createServer(app);

  // 初始化 WebSocket
  const wsContext = setupWebSocket(server);
  app.set('ws', wsContext);

  server.listen(config.port, () => {
    console.log(`\n🚀 myfrends 服务器已启动:`);
    console.log(`   HTTP:     http://localhost:${config.port}`);
    console.log(`   WebSocket: ws://localhost:${config.port}/ws`);
    console.log(`   API 文档: http://localhost:${config.port}/api/health\n`);
  });

  // 定期自动保存数据库（每 30 秒）
  setInterval(() => {
    try { saveToDisk(); } catch (_) {}
  }, 30000);

  // 优雅退出时保存
  process.on('SIGINT', () => { saveToDisk(); process.exit(0); });
  process.on('SIGTERM', () => { saveToDisk(); process.exit(0); });
}

main().catch(err => {
  console.error('启动失败:', err);
  process.exit(1);
});
