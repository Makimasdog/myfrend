const path = require('path');

require('dotenv').config({
  path: path.join(__dirname, '..', '..', '.env'),
});

const serverRoot = path.join(__dirname, '..', '..');
const configuredOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000,http://127.0.0.1:3000')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

module.exports = {
  env: process.env.NODE_ENV || 'development',
  host: process.env.HOST || '0.0.0.0',
  port: Number(process.env.PORT || 3000),
  jwtSecret: process.env.JWT_SECRET || (() => {
    throw new Error('JWT_SECRET is required in .env');
  })(),
  dbPath: path.resolve(serverRoot, process.env.DB_PATH || 'data/myfrends.db'),
  corsOrigins: configuredOrigins,
  llm: {
    baseUrl: process.env.LLM_API_BASE_URL || 'https://api.openai.com/v1',
    apiKey: process.env.LLM_API_KEY || '',
    model: process.env.LLM_MODEL || 'gpt-3.5-turbo',
  },
};
