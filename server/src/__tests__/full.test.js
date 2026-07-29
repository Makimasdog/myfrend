/**
 * myfrends Full Test Suite
 */
const request = require('supertest');
const fs = require('fs');
const path = require('path');

const testDbPath = path.join(__dirname, '..', '..', 'data', 'test-myfrends.db');
fs.rmSync(testDbPath, { force: true });

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-jwt-secret';
process.env.DB_PATH = testDbPath;

const { initDatabase, getDb, saveToDisk } = require('../models/db');
const { createApp } = require('../app');
const userService = require('../services/userService');
const aiFriendService = require('../services/aiFriendService');
const chatService = require('../services/chatService');
const socialService = require('../services/socialService');
const llmService = require('../services/llmService');

let app;
let svcUser;
let svcToken;
let svcAiFriend;
let svcSession;

beforeAll(async () => {
  await initDatabase();
  app = createApp({ logger: false });
});

afterAll(() => {
  saveToDisk();
  fs.rmSync(testDbPath, { force: true });
});

// ==================== DB ====================
describe('Database', () => {
  const tables = ['users', 'ai_friends', 'chat_sessions', 'messages',
                  'user_llm_configs', 'friendships', 'advisor_logs'];
  test.each(tables)('table %s exists', (name) => {
    const r = getDb().prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
    ).get(name);
    expect(r.name).toBe(name);
  });
});

// ==================== User Service ====================
describe('User Service', () => {
  const uname = 'svc_user_' + Date.now();

  test('register', () => {
    const r = userService.register(uname, '123456', 'SvcUser');
    expect(r).toHaveProperty('token');
    expect(r.user.username).toBe(uname);
    svcUser = r.user;
  });

  test('register duplicate throws', () => {
    expect(() => userService.register(uname, '123456')).toThrow();
  });

  test('login', () => {
    const r = userService.login(uname, '123456');
    expect(r).toHaveProperty('token');
  });

  test('login wrong password', () => {
    expect(() => userService.login(uname, 'wrong')).toThrow();
  });

  test('getUserById', () => {
    const u = userService.getUserById(svcUser.id);
    expect(u.username).toBe(uname);
    expect(u.nickname).toBe('SvcUser');
  });

  test('updateProfile', () => {
    const u = userService.updateProfile(svcUser.id, {
      nickname: 'NewNick', gender: 'male', bio: 'Hi'
    });
    expect(u.nickname).toBe('NewNick');
    expect(u.gender).toBe('male');
  });
});

// ==================== AI Friend Service ====================
describe('AI Friend Service', () => {
  test('create', () => {
    const f = aiFriendService.create(svcUser.id, {
      name: 'AF_One', gender: 'male', ageRange: '20-25', personality: 'funny'
    });
    expect(f.name).toBe('AF_One');
    expect(f.gender).toBe('male');
    svcAiFriend = f;
  });

  test('create minimal', () => {
    const f = aiFriendService.create(svcUser.id, {
      name: 'AF_Two', gender: 'female'
    });
    expect(f.name).toBe('AF_Two');
    expect(f.personality).toBeNull();
  });

  test('listByOwner', () => {
    const list = aiFriendService.listByOwner(svcUser.id);
    expect(list.length).toBeGreaterThanOrEqual(2);
  });

  test('getById', () => {
    const f = aiFriendService.getById(svcAiFriend.id, svcUser.id);
    expect(f.name).toBe('AF_One');
  });

  test('update', () => {
    const f = aiFriendService.update(svcAiFriend.id, svcUser.id, {
      personality: 'mature', age_range: '25-30'
    });
    expect(f.personality).toBe('mature');
    expect(f.age_range).toBe('25-30');
  });

  test('soft delete', () => {
    aiFriendService.remove(svcAiFriend.id, svcUser.id);
    const f = aiFriendService.getById(svcAiFriend.id, svcUser.id);
    expect(f.is_active).toBe(0);
  });
});

// ==================== Chat Service ====================
describe('Chat Service', () => {
  let cf;

  beforeAll(() => {
    cf = aiFriendService.create(svcUser.id, {
      name: 'ChatPal', gender: 'female', personality: 'chatty'
    });
  });

  test('getOrCreateSession', () => {
    svcSession = chatService.getOrCreateSession(svcUser.id, cf.id, 'ai');
    expect(svcSession.friend_type).toBe('ai');
  });

  test('reuse session', () => {
    const s2 = chatService.getOrCreateSession(svcUser.id, cf.id, 'ai');
    expect(s2.id).toBe(svcSession.id);
  });

  test('sendMessage', () => {
    const m = chatService.sendMessage(svcSession.id, svcUser.id, 'user', 'Hello!');
    expect(m.content).toBe('Hello!');
  });

  test('multiple messages', () => {
    chatService.sendMessage(svcSession.id, cf.id, 'ai', 'Hi!');
    chatService.sendMessage(svcSession.id, svcUser.id, 'user', 'How r u?');
    chatService.sendMessage(svcSession.id, cf.id, 'ai', 'Good!');
  });

  test('getMessages ascending', () => {
    const msgs = chatService.getMessages(svcSession.id);
    expect(msgs.length).toBeGreaterThanOrEqual(4);
    expect(msgs[0].content).toBe('Hello!');
  });

  test('listByUser', () => {
    const list = chatService.listByUser(svcUser.id);
    expect(list.find(s => s.id === svcSession.id)).toBeDefined();
  });

  test('markAsRead', () => {
    const msgs = chatService.getMessages(svcSession.id);
    chatService.markAsReadForUser(svcUser.id, msgs.map(m => m.id));
    const updated = chatService.getMessages(svcSession.id);
    for (const m of updated) {
      expect(m.is_read).toBe(m.sender_type === 'user' ? 0 : 1);
    }
  });
});

// ==================== Social Service ====================
describe('Social Service', () => {
  let su;

  beforeAll(() => {
    su = userService.register('soc_' + Date.now(), '123456', 'SocX').user;
  });

  test('searchUsers finds user', () => {
    const r = socialService.searchUsers('svc', su.id);
    expect(r.find(u => u.username === svcUser.username)).toBeDefined();
  });

  test('searchUsers empty', () => {
    expect(socialService.searchUsers('zzzz_nobody', su.id).length).toBe(0);
  });

  test('send friend request', () => {
    expect(socialService.sendFriendRequest(su.id, svcUser.id).status).toBe('pending');
  });

  test('duplicate throws', () => {
    expect(() => socialService.sendFriendRequest(su.id, svcUser.id)).toThrow();
  });

  test('pending requests', () => {
    const r = socialService.getPendingRequests(svcUser.id);
    expect(r.find(x => x.username === su.username)).toBeDefined();
  });

  test('accept', () => {
    const r = socialService.getPendingRequests(svcUser.id);
    expect(socialService.acceptFriendRequest(svcUser.id, r[0].request_id).status)
      .toBe('accepted');
  });

  test('friend list', () => {
    const f = socialService.getFriendList(svcUser.id);
    expect(f.find(x => x.username === su.username)).toBeDefined();
  });
});

// ==================== LLM Service ====================
describe('LLM Service', () => {
  test('getUserConfig defaults', () => {
    const c = llmService.getUserConfig('fake');
    expect(c).toHaveProperty('baseUrl');
    expect(c).toHaveProperty('model');
  });

  test('saveUserConfig', () => {
    llmService.saveUserConfig(svcUser.id, {
      apiBaseUrl: 'https://x.com/v1', apiKey: 'sk-x', model: 'mx'
    });
    const c = llmService.getUserConfig(svcUser.id);
    expect(c.baseUrl).toBe('https://x.com/v1');
    expect(c.model).toBe('mx');
  });

  test('buildSystemPrompt', () => {
    const p = llmService.buildSystemPrompt({
      name: 'Mei', gender: 'female', age_range: '20-25', personality: 'gentle'
    });
    expect(p).toContain('Mei');
    expect(p).toContain('gentle');
  });
});

// ==================== API Endpoints ====================
describe('API', () => {
  let t, uid;
  const duplicateUsername = 'dup_' + Date.now() + '_' + Math.floor(Math.random() * 100000);

  test('GET /api/health', async () => {
    const r = await request(app).get('/api/health');
    expect(r.status).toBe(200);
    expect(r.body.status).toBe('ok');
  });

  test('POST /api/auth/register', async () => {
    const uname = 'api_' + Date.now();
    const r = await request(app)
      .post('/api/auth/register')
      .send({ username: uname, password: '123456', nickname: 'Api' });
    expect(r.status).toBe(201);
    expect(r.body.user.username).toBe(uname);
    t = r.body.token;
    uid = r.body.user.id;
  });

  test('POST /api/auth/register duplicate', async () => {
    const r = await request(app)
      .post('/api/auth/register')
      .send({ username: duplicateUsername, password: '123456' });
    // First time should succeed
    expect(r.status).toBe(201);
    const r2 = await request(app)
      .post('/api/auth/register')
      .send({ username: duplicateUsername, password: '123456' });
    expect(r2.status).toBe(400);
  });

  test('POST /api/auth/register short pw', async () => {
    const r = await request(app)
      .post('/api/auth/register')
      .send({ username: 'spw', password: '12345' });
    expect(r.status).toBe(400);
  });

  test('POST /api/auth/login', async () => {
    const r = await request(app)
      .post('/api/auth/login')
      .send({ username: duplicateUsername, password: '123456' });
    expect(r.status).toBe(200);
  });

  test('POST /api/auth/login wrong pw', async () => {
    const r = await request(app)
      .post('/api/auth/login')
      .send({ username: duplicateUsername, password: 'wrong' });
    expect(r.status).toBe(401);
  });

  test('GET /api/auth/me', async () => {
    const r = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer ' + t);
    expect(r.status).toBe(200);
  });

  test('GET /api/auth/me no token', async () => {
    const r = await request(app).get('/api/auth/me');
    expect(r.status).toBe(401);
  });

  test('PUT /api/auth/profile', async () => {
    const r = await request(app)
      .put('/api/auth/profile')
      .set('Authorization', 'Bearer ' + t)
      .send({ nickname: 'Upd', bio: 'New' });
    expect(r.status).toBe(200);
    expect(r.body.nickname).toBe('Upd');
  });

  test('POST + GET /api/ai-friends', async () => {
    const r = await request(app)
      .post('/api/ai-friends')
      .set('Authorization', 'Bearer ' + t)
      .send({ name: 'AF_api', gender: 'male' });
    expect(r.status).toBe(201);
    expect(r.body.name).toBe('AF_api');

    const r2 = await request(app)
      .get('/api/ai-friends')
      .set('Authorization', 'Bearer ' + t);
    expect(r2.status).toBe(200);
    expect(r2.body.length).toBeGreaterThanOrEqual(1);
  });

  test('GET /api/ai-friends no token', async () => {
    const r = await request(app).get('/api/ai-friends');
    expect(r.status).toBe(401);
  });

  test('Chat flow', async () => {
    // Create friend
    const fr = await request(app)
      .post('/api/ai-friends')
      .set('Authorization', 'Bearer ' + t)
      .send({ name: 'ChatAF', gender: 'female' });
    const fid = fr.body.id;

    // Create session
    const sr = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + t)
      .send({ friendId: fid, friendType: 'ai' });
    expect(sr.status).toBe(200);
    const sid = sr.body.id;

    // Send message
    const mr = await request(app)
      .post('/api/chat/sessions/' + sid + '/messages')
      .set('Authorization', 'Bearer ' + t)
      .send({ content: 'Hello world' });
    expect(mr.status).toBe(201);
    expect(mr.body.userMessage.content).toBe('Hello world');

    // Get messages
    const gr = await request(app)
      .get('/api/chat/sessions/' + sid + '/messages')
      .set('Authorization', 'Bearer ' + t);
    expect(gr.status).toBe(200);
    expect(gr.body.length).toBeGreaterThanOrEqual(1);
  });

  test('POST /api/chat/sessions missing params', async () => {
    const r = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + t)
      .send({ friendId: 'x' });
    expect(r.status).toBe(400);
  });

  test('GET /api/social/search + friends', async () => {
    const r = await request(app)
      .get('/api/social/search?q=api')
      .set('Authorization', 'Bearer ' + t);
    expect(r.status).toBe(200);

    const r2 = await request(app)
      .get('/api/social/friends')
      .set('Authorization', 'Bearer ' + t);
    expect(r2.status).toBe(200);
  });

  test('LLM config', async () => {
    const r = await request(app)
      .get('/api/llm/config')
      .set('Authorization', 'Bearer ' + t);
    expect(r.status).toBe(200);
    expect(r.body).toHaveProperty('hasApiKey');

    const r2 = await request(app)
      .put('/api/llm/config')
      .set('Authorization', 'Bearer ' + t)
      .send({ apiBaseUrl: 'https://x.com/v1', apiKey: 'sk-x', model: 'm' });
    expect(r2.status).toBe(200);
  });

  test('Advisor missing params', async () => {
    const r = await request(app)
      .post('/api/advisor/advice')
      .set('Authorization', 'Bearer ' + t)
      .send({});
    expect(r.status).toBe(400);
  });

  test('chat endpoints enforce session ownership and read ownership', async () => {
    const other = await request(app)
      .post('/api/auth/register')
      .send({ username: 'other_' + Date.now(), password: '123456', nickname: 'Other' });
    expect(other.status).toBe(201);

    const friend = await request(app)
      .post('/api/ai-friends')
      .set('Authorization', 'Bearer ' + t)
      .send({ name: 'Private AI' });
    const session = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + t)
      .send({ friendId: friend.body.id, friendType: 'ai' });
    const message = await request(app)
      .post('/api/chat/sessions/' + session.body.id + '/messages')
      .set('Authorization', 'Bearer ' + t)
      .send({ content: 'Private message' });

    const foreignRead = await request(app)
      .get('/api/chat/sessions/' + session.body.id + '/messages')
      .set('Authorization', 'Bearer ' + other.body.token);
    expect(foreignRead.status).toBe(404);

    const foreignReceipt = await request(app)
      .put('/api/chat/messages/read')
      .set('Authorization', 'Bearer ' + other.body.token)
      .send({ messageIds: [message.body.userMessage.id] });
    expect(foreignReceipt.status).toBe(200);
    expect(foreignReceipt.body.updatedCount).toBe(0);

    const stored = getDb().prepare('SELECT is_read FROM messages WHERE id = ?')
      .get(message.body.userMessage.id);
    expect(stored.is_read).toBe(0);

    const foreignSession = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + other.body.token)
      .send({ friendId: friend.body.id, friendType: 'ai' });
    expect(foreignSession.status).toBe(400);
  });

  test('human messages persist in both participants sessions', async () => {
    const left = userService.register('left_' + Date.now(), '123456', 'Left');
    const right = userService.register('right_' + Date.now(), '123456', 'Right');
    socialService.sendFriendRequest(left.user.id, right.user.id);
    const pending = socialService.getPendingRequests(right.user.id);
    socialService.acceptFriendRequest(right.user.id, pending[0].request_id);

    const senderSession = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + left.token)
      .send({ friendId: right.user.id, friendType: 'human' });
    expect(senderSession.status).toBe(200);

    const sent = await request(app)
      .post('/api/chat/sessions/' + senderSession.body.id + '/messages')
      .set('Authorization', 'Bearer ' + left.token)
      .send({ content: 'Hello from Left' });
    expect(sent.status).toBe(201);

    const recipientSessions = await request(app)
      .get('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + right.token);
    const recipientSession = recipientSessions.body.find((item) =>
      item.friend_id === left.user.id && item.friend_type === 'human');
    expect(recipientSession).toBeDefined();

    const received = await request(app)
      .get('/api/chat/sessions/' + recipientSession.id + '/messages')
      .set('Authorization', 'Bearer ' + right.token);
    expect(received.status).toBe(200);
    expect(received.body).toHaveLength(1);
    expect(received.body[0].content).toBe('Hello from Left');
    expect(received.body[0].sender_type).toBe('human');
  });

  test('streamed AI replies do not duplicate an already persisted user message', async () => {
    const friend = await request(app)
      .post('/api/ai-friends')
      .set('Authorization', 'Bearer ' + t)
      .send({ name: 'Streaming AI' });
    const session = await request(app)
      .post('/api/chat/sessions')
      .set('Authorization', 'Bearer ' + t)
      .send({ friendId: friend.body.id, friendType: 'ai' });
    await request(app)
      .post('/api/chat/sessions/' + session.body.id + '/messages')
      .set('Authorization', 'Bearer ' + t)
      .send({ content: 'Please stream once' });

    const streamSpy = jest.spyOn(llmService, 'chatCompletionStream')
      .mockImplementation(async (_userId, _messages, options) => {
        options.onToken('One');
        options.onToken(' reply');
      });
    const memorySpy = jest.spyOn(llmService, 'chatCompletion')
      .mockResolvedValue('None');
    const response = await request(app)
      .post('/api/chat/sessions/' + session.body.id + '/stream')
      .set('Authorization', 'Bearer ' + t)
      .send({});
    streamSpy.mockRestore();
    memorySpy.mockRestore();

    expect(response.status).toBe(200);
    expect(response.text).toContain('"done":true');
    const messages = chatService.getMessages(session.body.id);
    expect(messages.filter((message) => message.content === 'Please stream once')).toHaveLength(1);
    expect(messages.filter((message) => message.content === 'One reply')).toHaveLength(1);
  });
});
