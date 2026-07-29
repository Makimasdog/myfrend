const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const config = require('./config');
const chatService = require('./services/chatService');
const llmService = require('./services/llmService');
const ttsService = require('./services/ttsService');
const db = require('./models/db');

function setupWebSocket(server) {
  const wss = new WebSocket.Server({
    server,
    verifyClient: (info) => {
      const origin = info.origin || '';
      // Allow non-browser clients (Flutter mobile, etc.) with no Origin header
      if (!origin) return true;
      try {
        const hostname = new URL(origin).hostname;
        if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname.startsWith('192.168.')) return true;
      } catch (_) {}
      console.warn('[WS] Blocked origin:', origin);
      return false;
    },
  });
  const connections = new Map();

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, 'http://x');
    const pathname = url.pathname;
    const friendId = url.searchParams.get('friend_id');

    let authed = false;
    const timeout = setTimeout(() => { if (!authed) ws.close(4001, 'Auth timeout'); }, 5000);

    ws.once('message', (data) => {
      clearTimeout(timeout);
      try {
        const msg = JSON.parse(data.toString());
        if (msg.type !== 'auth' || !msg.token) { ws.close(4001, 'Missing auth'); return; }
        const decoded = jwt.verify(msg.token, config.jwtSecret);
        const userId = decoded.id;
        authed = true;
        if (pathname === '/ws/call') {
          handleCallConnection(ws, userId, friendId);
        } else {
          handleChatConnection(ws, userId, connections);
        }
      } catch (e) { ws.close(4001, 'Auth failed'); }
    });
  });

  wss.on('error', (e) => console.error('[WS] Server error:', e.message));
  console.log('[WS] WebSocket ready: /ws/chat + /ws/call');
  return { wss, connections };
}

function handleChatConnection(ws, userId, connections) {
  if (!connections.has(userId)) connections.set(userId, new Set());
  connections.get(userId).add(ws);
  console.log('[WS:chat] User ' + userId + ' connected');
  ws.send(JSON.stringify({ type: 'connected', userId }));
  ws.on('message', async (data) => {
    try {
      const msg = JSON.parse(data.toString());
      await handleChatMessage(userId, ws, msg, connections);
    } catch (e) { ws.send(JSON.stringify({ type: 'error', error: 'Internal error' })); }
  });
  ws.on('close', () => {
    const c = connections.get(userId);
    if (c) { c.delete(ws); if (c.size === 0) connections.delete(userId); }
  });
  ws.on('error', (e) => console.error('[WS:chat] Error:', e.message));
}

async function handleChatMessage(userId, ws, msg, connections) {
  switch (msg.type) {
    case 'ping': ws.send(JSON.stringify({ type: 'pong' })); break;
    case 'message':
      broadcastToSession(msg.sessionId, userId, {
        type: 'new_message', sessionId: msg.sessionId, senderId: userId,
        content: msg.content, contentType: msg.contentType || 'text',
        createdAt: new Date().toISOString(),
      }, connections);
      break;
    default: ws.send(JSON.stringify({ type: 'error', error: 'Unknown type' }));
  }
}

function broadcastToSession(sessionId, senderId, message, connections) {
  const c = connections.get(senderId);
  if (!c) return;
  for (const w of c) { if (w.readyState === WebSocket.OPEN) w.send(JSON.stringify(message)); }
}

async function handleCallConnection(ws, userId, aiFriendId) {
  let sessionId;
  console.log('[WS:call] User ' + userId + ' connected');

  let conversationHistory = [];
  try {
    const session = chatService.getOrCreateSession(userId, aiFriendId, 'ai');
    sessionId = session.id;
    const msgs = chatService.getMessages(sessionId, 20);
    conversationHistory = msgs.map(function(m) {
      return { role: m.sender_type === 'user' ? 'user' : 'assistant', content: m.content };
    });
    ws.send(JSON.stringify({ type: 'ready', sessionId: sessionId }));
  } catch (e) { console.error('[Call] Init error:', e.message); }

  ws.on('message', async (data) => {
    try {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'ping') ws.send(JSON.stringify({ type: 'pong' }));
      else if (msg.type === 'speech') await handleCallSpeech(ws, userId, sessionId, aiFriendId, msg.text, conversationHistory);
      else if (msg.type === 'interrupt') ws.send(JSON.stringify({ type: 'tts_stop' }));
    } catch (e) { ws.send(JSON.stringify({ type: 'error', error: 'Internal error' })); }
  });

  ws.on('close', () => console.log('[WS:call] User ' + userId + ' disconnected'));
  ws.on('error', (e) => console.error('[WS:call] Error:', e.message));
}

async function handleCallSpeech(ws, userId, sessionId, aiFriendId, userText, history) {
  if (!userText || !userText.trim()) return;
  ws.send(JSON.stringify({ type: 'recognized', text: userText }));
  if (sessionId) chatService.sendMessage(sessionId, userId, 'user', userText, 'text', null);
  history.push({ role: 'user', content: userText });

  try {
    const aiFriend = db.prepare('SELECT * FROM ai_friends WHERE id = ? AND owner_id = ?').get(aiFriendId, userId);
    if (!aiFriend) { ws.send(JSON.stringify({ type: 'error', error: 'Friend not found' })); return; }
    const user = db.prepare('SELECT nickname, username FROM users WHERE id = ?').get(userId);
    const userName = user ? (user.nickname || user.username) : 'friend';

    const systemPrompt = llmService.buildSystemPrompt(aiFriend, {
      userName: userName, messagesCount: history.length, recentMessages: history.slice(-5),
    });
    const messages = [{ role: 'system', content: systemPrompt + '\nReply in 2-3 natural sentences.' }].concat(history.slice(-10));
    const cfg = llmService.getUserConfig(userId);
    if (!cfg.apiKey) { ws.send(JSON.stringify({ type: 'error', error: 'No API key configured' })); return; }
    const reply = await llmService.chatCompletion(userId, messages, { temperature: 0.9, maxTokens: [redacted] });
    history.push({ role: 'assistant', content: reply });
    if (sessionId) chatService.sendMessage(sessionId, aiFriendId, 'ai', reply, 'text', null);

    const voice = aiFriend.gender === 'male' ? 'zh-CN-male' : 'zh-CN-female';
    ws.send(JSON.stringify({ type: 'tts_start', text: reply }));
    var idx = 0;
    try {
      await ttsService.synthesizeStream(reply, voice, function(chunk) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'tts_chunk', index: idx++, data: chunk.toString('base64') }));
        }
      });
      ws.send(JSON.stringify({ type: 'tts_end' }));
    } catch (ttsErr) {
      console.error('[Call] TTS error:', ttsErr.message);
      ws.send(JSON.stringify({ type: 'tts_end', error: 'TTS failed' }));
      ws.send(JSON.stringify({ type: 'text_reply', text: reply }));
    }
  } catch (e) {
    console.error('[Call] Error:', e.message);
    ws.send(JSON.stringify({ type: 'error', error: 'Internal error' }));
  }
}

module.exports = { setupWebSocket };
