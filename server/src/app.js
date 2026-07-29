const express = require('express');
const path = require('path');
const cors = require('cors');
const config = require('./config');

const authRoutes = require('./routes/auth');
const aiFriendsRoutes = require('./routes/aiFriends');
const chatRoutes = require('./routes/chat');
const socialRoutes = require('./routes/social');
const advisorRoutes = require('./routes/advisor');
const llmRoutes = require('./routes/llm');
const uploadRoutes = require('./routes/upload');

function createApp({ logger = config.env !== 'test' } = {}) {
  const app = express();

  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.includes('*') || config.corsOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin is not allowed by CORS policy'));
    },
  }));
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  if (logger) {
    app.use((req, _res, next) => {
      console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
      next();
    });
  }

  app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', name: 'myfrends-server', version: '0.2.0' });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/ai-friends', aiFriendsRoutes);
  app.use('/api/chat', chatRoutes);
  app.use('/api/social', socialRoutes);
  app.use('/api/advisor', advisorRoutes);
  app.use('/api/llm', llmRoutes);
  app.use('/api/upload', uploadRoutes);
  app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

  app.use((err, _req, res, _next) => {
    console.error('[Error]', err.message);
    const status = Number.isInteger(err.status) ? err.status : 500;
    res.status(status).json({
      error: status >= 500 && config.env === 'production'
        ? 'Internal server error'
        : err.message || 'Internal server error',
    });
  });

  return app;
}

module.exports = { createApp };
