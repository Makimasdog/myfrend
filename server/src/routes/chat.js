const express = require('express');
const router = express.Router();
const chatService = require('../services/chatService');
const llmService = require('../services/llmService');
const db = require('../models/db');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/chat/sessions — 获取会话列表
router.get('/sessions', (req, res) => {
  try {
    const sessions = chatService.listByUser(req.user.id);
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/chat/sessions — 创建或获取会话
router.post('/sessions', (req, res) => {
  try {
    const { friendId, friendType } = req.body;
    if (!friendId || !friendType) {
      return res.status(400).json({ error: 'friendId 和 friendType 不能为空' });
    }
    const session = chatService.getOrCreateSession(req.user.id, friendId, friendType);
    res.json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/chat/sessions/:id/messages — 获取会话消息
router.get('/sessions/:id/messages', (req, res) => {
  try {
    const { limit, offset } = req.query;
    const messages = chatService.getMessages(
      req.params.id,
      parseInt(limit) || 50,
      parseInt(offset) || 0
    );
    res.json(messages);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/chat/sessions/:id/messages — 发送消息到指定会话
router.post('/sessions/:id/messages', async (req, res) => {
  try {
    const { content, contentType = 'text', voiceUrl } = req.body;
    if (!content) {
      return res.status(400).json({ error: '消息内容不能为空' });
    }

    const sessionId = req.params.id;

    // 验证会话属于当前用户
    const session = db.prepare('SELECT * FROM chat_sessions WHERE id = ? AND user_id = ?')
      .get(sessionId, req.user.id);
    if (!session) return res.status(404).json({ error: '会话不存在' });

    // 保存用户消息
    const userMsg = chatService.sendMessage(
      sessionId, req.user.id, 'user', content, contentType, voiceUrl
    );

    res.status(201).json({ userMessage: userMsg, status: 'sent' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// POST /api/chat/sessions/:id/ai-reply — 触发 AI 回复
router.post('/sessions/:id/ai-reply', async (req, res) => {
  try {
    const sessionId = req.params.id;

    const session = db.prepare('SELECT * FROM chat_sessions WHERE id = ? AND user_id = ?')
      .get(sessionId, req.user.id);
    if (!session) return res.status(404).json({ error: '会话不存在' });
    if (session.friend_type !== 'ai') return res.status(400).json({ error: '此会话不是 AI 聊天' });

    const aiFriend = db.prepare('SELECT * FROM ai_friends WHERE id = ?')
      .get(session.friend_id);
    if (!aiFriend) return res.status(404).json({ error: 'AI 朋友不存在' });

    // 获取用户名
    const user = db.prepare('SELECT nickname, username FROM users WHERE id = ?').get(req.user.id);
    const userName = user?.nickname || user?.username || '朋友';

    // 获取历史消息 + 记忆
    const history = chatService.getMessages(sessionId, 20);
    const memories = llmService.getMemories(req.user.id, session.friend_id, 5);
    const memoryText = memories.length > 0
      ? '\n\n# 你记得关于' + userName + '的这些事\n' + memories.map(m => '- ' + m.fact).join('\n')
      : '';

    const systemPrompt = llmService.buildSystemPrompt(aiFriend, {
      userName,
      messagesCount: history.length,
      lastInteractionMs: session.last_message_at ? new Date(session.last_message_at + 'Z').getTime() : null,
      recentMessages: history.slice(-5),
    }) + memoryText;

    const messages = [
      { role: 'system', content: systemPrompt },
      ...history.map(m => ({
        role: m.sender_type === 'user' ? 'user' : 'assistant',
        content: m.content,
      })),
    ];

    const reply = await llmService.chatCompletion(req.user.id, messages);

    // 保存 AI 回复
    const aiMsg = chatService.sendMessage(sessionId, aiFriend.id, 'ai', reply);

    // 异步提取用户事实（不阻塞响应）
    _extractMemories(req.user.id, session.friend_id, history, reply).catch(() => {});

    res.json({ aiMessage: aiMsg });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// POST /api/chat/sessions/:id/stream — SSE streaming AI reply
router.post('/sessions/:id/stream', async (req, res) => {
  try {
    const sessionId = req.params.id;
    const { content } = req.body;
    const session = db.prepare('SELECT * FROM chat_sessions WHERE id = ? AND user_id = ?').get(sessionId, req.user.id);
    if (!session) return res.status(404).json({ error: 'not found' });
    if (session.friend_type !== 'ai') return res.status(400).json({ error: 'not ai' });
    const aiFriend = db.prepare('SELECT * FROM ai_friends WHERE id = ?').get(session.friend_id);
    if (!aiFriend) return res.status(404).json({ error: 'no friend' });
    const user = db.prepare('SELECT nickname, username FROM users WHERE id = ?').get(req.user.id);
    const userName = user?.nickname || user?.username || 'friend';
    if (content) chatService.sendMessage(sessionId, req.user.id, 'user', content || '', 'text', null);
    const history = chatService.getMessages(sessionId, 20);
    const memories = llmService.getMemories(req.user.id, session.friend_id, 5);
    const memoryText = memories.length > 0 ? '\n\n- ' + memories.map(m => m.fact).join('\n- ') : '';
    const systemPrompt = llmService.buildSystemPrompt(aiFriend, { userName, messagesCount: history.length, lastInteractionMs: session.last_message_at ? new Date(session.last_message_at + 'Z').getTime() : null, recentMessages: history.slice(-5) }) + memoryText;
    const messages = [{ role: 'system', content: systemPrompt }, ...history.map(m => ({ role: m.sender_type === 'user' ? 'user' : 'assistant', content: m.content }))];
    res.setHeader('Content-Type', 'text/event-stream'); res.setHeader('Cache-Control', 'no-cache'); res.setHeader('Connection', 'keep-alive'); res.flushHeaders();
    let fullReply = '';
    try {
      await llmService.chatCompletionStream(req.user.id, messages, { temperature: 0.9, maxTokens: 300, onToken: (token) => { fullReply += token; res.write('data: ' + JSON.stringify({ token: token }) + '\n\n'); } });
    } catch (e) { res.write('data: ' + JSON.stringify({ error: e.message }) + '\n\n'); res.end(); return; }
    if (fullReply) { chatService.sendMessage(sessionId, aiFriend.id, 'ai', fullReply, 'text', null); _extractMemories(req.user.id, session.friend_id, history, fullReply).catch(() => {}); }
    res.write('data: ' + JSON.stringify({ done: true, fullText: fullReply }) + '\n\n'); res.end();
  } catch (err) { if (!res.headersSent) res.status(500).json({ error: err.message }); else { res.write('data: ' + JSON.stringify({ error: err.message }) + '\n\n'); res.end(); } }
});

// PUT /api/chat/messages/read — 标记消息已读
router.put('/messages/read', (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!messageIds || !Array.isArray(messageIds)) {
      return res.status(400).json({ error: 'messageIds 数组不能为空' });
    }
    chatService.markAsRead(messageIds);
    res.json({ message: '已标记为已读' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


// ===== 异步提取用户记忆 =====
async function _extractMemories(userId, aiFriendId, history, aiReply) {
  try {
    // 取最近2条用户消息用于提取
    const userMsgs = history.filter(m => m.sender_type === 'user').slice(-2);
    if (userMsgs.length === 0) return;

    const userText = userMsgs.map(m => m.content).join('\n');
    const factPrompt = [
      { role: 'system', content: '从用户的发言中提取关于用户的重要事实。只提取明确的信息，不要推测。每条事实一行，用"- "开头。如果没有什么值得记住的，回复"无"。' },
      { role: 'user', content: userText },
    ];

    const factsText = await llmService.chatCompletion(userId, factPrompt, { temperature: 0.3, maxTokens: 100 });
    if (!factsText || factsText.includes('无')) return;

    // 解析并保存每条事实
    const facts = factsText.split('\n').filter(f => f.trim().startsWith('- ')).map(f => f.trim().substring(2));
    for (const fact of facts) {
      if (fact.length > 3 && fact.length < 200) {
        llmService.saveMemory(userId, aiFriendId, fact, userText);
      }
    }
    if (facts.length > 0) console.log('[Memory] Extracted', facts.length, 'facts for user', userId);
  } catch (e) {
    // 静默失败，不影响主流程
  }
}
module.exports = router;
