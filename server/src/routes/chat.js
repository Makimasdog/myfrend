const express = require('express');
const router = express.Router();
const chatService = require('../services/chatService');
const llmService = require('../services/llmService');
const db = require('../models/db');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

router.get('/sessions', (req, res) => {
  try {
    res.json(chatService.listByUser(req.user.id));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/sessions', (req, res) => {
  try {
    const { friendId, friendType } = req.body;
    const session = chatService.getOrCreateSession(req.user.id, friendId, friendType);
    res.json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/sessions/:id/messages', (req, res) => {
  try {
    const session = chatService.getOwnedSession(req.params.id, req.user.id);
    if (!session) {
      return res.status(404).json({ error: 'Chat session not found' });
    }
    res.json(chatService.getMessages(session.id, req.query.limit, req.query.offset));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/sessions/:id/messages', (req, res) => {
  try {
    const { content, contentType = 'text', voiceUrl } = req.body;
    const session = chatService.getOwnedSession(req.params.id, req.user.id);
    if (!session) {
      return res.status(404).json({ error: 'Chat session not found' });
    }

    if (session.friend_type === 'human') {
      const result = chatService.sendHumanMessage(
        req.user.id,
        session.id,
        content,
        contentType,
        voiceUrl
      );
      const ws = req.app.get('ws');
      ws?.sendToUser(session.friend_id, {
        type: 'new_message',
        sessionId: result.recipientSession.id,
        message: result.recipientMessage,
      });
      return res.status(201).json({
        userMessage: result.senderMessage,
        status: 'sent',
      });
    }

    const userMessage = chatService.sendMessage(
      session.id,
      req.user.id,
      'user',
      content,
      contentType,
      voiceUrl
    );
    res.status(201).json({ userMessage, status: 'sent' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/sessions/:id/ai-reply', async (req, res) => {
  try {
    const context = getAiChatContext(req.user.id, req.params.id);
    const reply = await llmService.chatCompletion(req.user.id, context.messages);
    const aiMessage = chatService.sendMessage(
      context.session.id,
      context.aiFriend.id,
      'ai',
      reply
    );

    extractMemories(req.user.id, context.aiFriend.id, context.history, reply).catch(() => {});
    res.json({ aiMessage });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// The user message must be persisted through POST /messages before starting a stream.
// This prevents a streamed reply from creating a duplicate user message.
router.post('/sessions/:id/stream', async (req, res) => {
  try {
    const context = getAiChatContext(req.user.id, req.params.id);
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    let fullReply = '';
    let closed = false;
    res.on('close', () => {
      closed = true;
    });

    try {
      await llmService.chatCompletionStream(req.user.id, context.messages, {
        temperature: 0.9,
        maxTokens: 300,
        onToken(token) {
          fullReply += token;
          if (!closed) {
            writeSse(res, { token });
          }
        },
      });
    } catch (err) {
      if (!closed) {
        writeSse(res, { error: err.message });
        res.end();
      }
      return;
    }

    if (!fullReply) {
      if (!closed) {
        writeSse(res, { error: 'The AI provider returned an empty response' });
        res.end();
      }
      return;
    }

    const aiMessage = chatService.sendMessage(
      context.session.id,
      context.aiFriend.id,
      'ai',
      fullReply
    );
    extractMemories(req.user.id, context.aiFriend.id, context.history, fullReply).catch(() => {});

    if (!closed) {
      writeSse(res, { done: true, message: aiMessage });
      res.end();
    }
  } catch (err) {
    if (!res.headersSent) {
      res.status(400).json({ error: err.message });
    } else {
      writeSse(res, { error: err.message });
      res.end();
    }
  }
});

router.put('/messages/read', (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!Array.isArray(messageIds) || messageIds.length === 0 || messageIds.length > 100) {
      return res.status(400).json({ error: 'messageIds must contain between 1 and 100 message IDs' });
    }
    const updatedCount = chatService.markAsReadForUser(
      req.user.id,
      [...new Set(messageIds.filter((id) => typeof id === 'string'))]
    );
    res.json({ updatedCount });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

function getAiChatContext(userId, sessionId) {
  const session = chatService.getOwnedSession(sessionId, userId);
  if (!session) {
    throw new Error('Chat session not found');
  }
  if (session.friend_type !== 'ai') {
    throw new Error('This operation is only available in an AI chat');
  }

  const aiFriend = db.prepare(`
    SELECT * FROM ai_friends WHERE id = ? AND owner_id = ? AND is_active = 1
  `).get(session.friend_id, userId);
  if (!aiFriend) {
    throw new Error('AI friend not found');
  }

  const user = db.prepare('SELECT nickname, username FROM users WHERE id = ?').get(userId);
  const userName = user?.nickname || user?.username || 'friend';
  const history = chatService.getMessages(sessionId, 20);
  const memories = llmService.getMemories(userId, aiFriend.id, 5);
  const memoryText = memories.length > 0
    ? `\n\n# Remembered facts about ${userName}\n${memories.map((memory) => `- ${memory.fact}`).join('\n')}`
    : '';
  const lastInteractionMs = session.last_message_at
    ? new Date(`${session.last_message_at}Z`).getTime()
    : null;
  const systemPrompt = llmService.buildSystemPrompt(aiFriend, {
    userName,
    messagesCount: history.length,
    lastInteractionMs,
    recentMessages: history.slice(-5),
  }) + memoryText;

  return {
    session,
    aiFriend,
    history,
    messages: [
      { role: 'system', content: systemPrompt },
      ...history.map((message) => ({
        role: message.sender_type === 'user' ? 'user' : 'assistant',
        content: message.content,
      })),
    ],
  };
}

function writeSse(res, payload) {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

async function extractMemories(userId, aiFriendId, history) {
  const userMessages = history
    .filter((message) => message.sender_type === 'user')
    .slice(-2);
  if (userMessages.length === 0) {
    return;
  }

  const sourceText = userMessages.map((message) => message.content).join('\n');
  const factsText = await llmService.chatCompletion(userId, [
    {
      role: 'system',
      content: 'Extract only explicit, durable facts about the user. Return each fact on a line starting with "- ". Return "None" when there are no useful facts.',
    },
    { role: 'user', content: sourceText },
  ], { temperature: 0.3, maxTokens: 100 });

  const facts = factsText
    .split('\n')
    .filter((fact) => fact.trim().startsWith('- '))
    .map((fact) => fact.trim().slice(2))
    .filter((fact) => fact.length > 3 && fact.length < 200);
  for (const fact of facts) {
    llmService.saveMemory(userId, aiFriendId, fact, sourceText);
  }
}

module.exports = router;
