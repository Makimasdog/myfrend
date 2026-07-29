const db = require('../models/db');
const { v4: uuidv4 } = require('uuid');
const llmService = require('./llmService');
const chatService = require('./chatService');

/**
 * AI 军师服务
 * 在真人文字聊天中，用户可以召唤 AI 朋友给出建议
 */
const advisorService = {
  /**
   * 获取 AI 军师建议
   * @param {string} userId - 用户 ID
   * @param {string} sessionId - 聊天会话 ID（真人聊天）
   * @param {string} aiFriendId - 选择的 AI 朋友 ID
   * @param {string} context - 用户提供的上下文（可选，如最近的几条消息）
   */
  async getAdvice(userId, sessionId, aiFriendId, context) {
    // 获取 AI 朋友信息
    const aiFriend = db.prepare('SELECT * FROM ai_friends WHERE id = ? AND owner_id = ?')
      .get(aiFriendId, userId);
    if (!aiFriend) throw new Error('AI 朋友不存在');

    // 获取最近的聊天上下文（默认最近10条）
    const recentMessages = context
      ? [{ role: 'user', content: context }]
      : chatService.getMessages(sessionId, 10, 0).map(m => ({
          role: m.sender_id === userId ? 'user' : 'other',
          content: m.content,
        }));

    const systemPrompt = llmService.buildSystemPrompt(aiFriend);
    const advicePrompt = `
现在你正在扮演一个"恋爱/社交军师"的角色。你的朋友（用户）正在和另一个人进行聊天，他想向你寻求建议。

以下是最近聊天的部分内容：
${recentMessages.map(m => `[${m.role === 'user' ? '我' : '对方'}]: ${m.content}`).join('\n')}

请以朋友的身份，给出体贴、实用的建议。你的建议可以包括：
1. 如何回复对方的消息（给出具体的回复话术）
2. 当前聊天的氛围分析和注意事项
3. 下一步可以聊什么话题

保持轻松友好的语气，不要给出激进或有风险的社交建议。`;

    const messages = [
      { role: 'system', content: `${systemPrompt}\n\n${advicePrompt}` },
      { role: 'user', content: '请给我一些建议吧！' },
    ];

    const advice = await llmService.chatCompletion(userId, messages, { temperature: 0.9, maxTokens: 512 });

    // 保存军师记录
    const logId = uuidv4();
    db.prepare(`
      INSERT INTO advisor_logs (id, session_id, ai_friend_id, advice_content, context_snapshot)
      VALUES (?, ?, ?, ?, ?)
    `).run(logId, sessionId, aiFriendId, advice, JSON.stringify(recentMessages.slice(-5)));

    return { id: logId, advice, aiFriendName: aiFriend.name };
  },

  /**
   * 获取军师历史记录
   */
  getHistory(sessionId) {
    return db.prepare(`
      SELECT al.*, af.name as ai_friend_name
      FROM advisor_logs al
      JOIN ai_friends af ON al.ai_friend_id = af.id
      WHERE al.session_id = ?
      ORDER BY al.created_at DESC
    `).all(sessionId);
  },
};

module.exports = advisorService;
