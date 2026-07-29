const http = require('http');
const config = require('./config');
const { initDatabase, saveToDisk } = require('./models/db');
const { setupWebSocket } = require('./ws');
const { createApp } = require('./app');

async function main() {
  await initDatabase();

  const app = createApp();
  const server = http.createServer(app);
  app.set('ws', setupWebSocket(server));

  server.listen(config.port, config.host, () => {
    console.log(`myfrends server listening on http://${config.host}:${config.port}`);
  });

  const saveAndExit = () => {
    saveToDisk();
    server.close(() => process.exit(0));
  };

  setInterval(() => {
    try {
      saveToDisk();
    } catch (_) {
      // The next scheduled save will retry.
    }
  }, 30000).unref();

  process.once('SIGINT', saveAndExit);
  process.once('SIGTERM', saveAndExit);
}

main().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
