const db = require('../models/db');
const config = require('../config');

const llmService = {
  getUserConfig(userId) {
    const userConfig = db.prepare('SELECT * FROM user_llm_configs WHERE user_id = ?').get(userId);
    if (userConfig && userConfig.api_key) {
      return {
        baseUrl: userConfig.api_base_url || config.llm.baseUrl,
        apiKey: userConfig.api_key,
        model: userConfig.model || config.llm.model,
      };
    }
    return config.llm;
  },

  saveUserConfig(userId, { apiBaseUrl, apiKey, model }) {
    const { v4: uuidv4 } = require('uuid');
    const existing = db.prepare('SELECT id FROM user_llm_configs WHERE user_id = ?').get(userId);
    if (existing) {
      db.prepare(`
        UPDATE user_llm_configs SET api_base_url = ?, api_key = ?, model = ?, updated_at = datetime('now')
        WHERE user_id = ?
      `).run(apiBaseUrl, apiKey, model, userId);
    } else {
      db.prepare(`
        INSERT INTO user_llm_configs (id, user_id, api_base_url, api_key, model)
        VALUES (?, ?, ?, ?, ?)
      `).run(uuidv4(), userId, apiBaseUrl, apiKey, model);
    }
  },

  async chatCompletion(userId, messages, options = {}) {
    const llmConfig = this.getUserConfig(userId);
    if (!llmConfig.apiKey) {
      throw new Error('Please configure LLM API Key first');
    }
    const url = `${llmConfig.baseUrl}/chat/completions`;
    const body = {
      model: options.model || llmConfig.model,
      messages,
      temperature: options.temperature ?? 0.8,
      max_tokens: options.maxTokens || 1024,
    };
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${llmConfig.apiKey}` },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`LLM API error (${response.status}): ${errText}`);
    }
    const result = await response.json();
    return result.choices?.[0]?.message?.content || '';
  },


  async chatCompletionStream(userId, messages, options = {}) {
    const llmConfig = this.getUserConfig(userId);
    if (!llmConfig.apiKey) throw new Error('Please configure LLM API Key first');
    const url = llmConfig.baseUrl + '/chat/completions';
    const body = { model: options.model || llmConfig.model, messages, temperature: options.temperature ?? 0.8, max_tokens: options.maxTokens || 1024, stream: true };
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + llmConfig.apiKey }, body: JSON.stringify(body), signal: AbortSignal.timeout(60000) });
    if (!response.ok) { const errText = await response.text(); throw new Error('LLM API error (' + response.status + '): ' + errText); }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6).trim();
          if (data === '[DONE]') return;
          try { const parsed = JSON.parse(data); const token = parsed.choices?.[0]?.delta?.content || ''; if (token && options.onToken) options.onToken(token); } catch (_) {}
        }
      }
    }
  },

  // ==================== 富 System Prompt ====================

  /**
   * 构建丰富的角色 System Prompt
   * @param {object} aiFriend - AI 朋友数据库记录
   * @param {object} opts - 可选上下文
   * @param {string} opts.userName - 用户名
   * @param {number} opts.messagesCount - 已对话轮数
   */
  buildSystemPrompt(aiFriend, opts = {}) {
    // 如果用户自定义了 system_prompt，直接使用
    if (aiFriend.system_prompt && aiFriend.system_prompt.length > 100) {
      return aiFriend.system_prompt;
    }

    const name = aiFriend.name || '朋友';
    const gender = aiFriend.gender === 'male' ? '男' : aiFriend.gender === 'female' ? '女' : '';
    const genderRef = aiFriend.gender === 'male' ? '他' : aiFriend.gender === 'female' ? '她' : 'TA';
    const age = aiFriend.age_range || '';
    const personality = aiFriend.personality || '友善、有趣';
    const voiceType = aiFriend.voice_type || 'default';
    const userName = opts.userName || '朋友';
    const messagesCount = opts.messagesCount || 0;
    const recentMessages = opts.recentMessages || [];
    const lastInteractionMs = opts.lastInteractionMs ?? null;

    // 解析 extra_config
    let extra = {};
    try {
      if (aiFriend.extra_config) {
        extra = typeof aiFriend.extra_config === 'string'
          ? JSON.parse(aiFriend.extra_config)
          : aiFriend.extra_config;
      }
    } catch (_) {}

    const hobbies = extra.hobbies || '';
    const style = extra.speakingStyle || '';
    const role = extra.relationshipRole || '';
    const note = extra.note || extra.customNote || '';

    // 根据性别选声音描述
    const mood = _analyzeMood(recentMessages, aiFriend);

    // Time-based greeting
    const hoursSinceLast = (lastInteractionMs != null && lastInteractionMs > 0) ? Math.floor((Date.now() - lastInteractionMs) / 3600000) : 0;
    let greetingNote = '';
    if (hoursSinceLast > 24) greetingNote = '\nNOTE: It\'s been ' + hoursSinceLast + ' hours since you last chatted with ' + userName + '. Start with a warm greeting, ask how they\'ve been doing.';
    else if (hoursSinceLast > 6) greetingNote = '\nNOTE: It\'s been ' + hoursSinceLast + ' hours since last chat. Mention it naturally in your reply.';
    else if (hoursSinceLast < 0.1 && messagesCount < 3) greetingNote = '\nNOTE: You just started chatting with ' + userName + '. Be warm and friendly.';
    const voiceDesc = voiceType === 'default'
      ? (aiFriend.gender === 'male' ? '低沉温和的男声' : '温柔亲切的女声')
      : '独特的嗓音';

    // 根据 personality 生成更丰富的描述
    const personalityColor = _personalityColor(personality);

    // 时间上下文
    const now = new Date();
    const hour = now.getHours();
    const timeGreeting = hour < 6 ? '凌晨' : hour < 9 ? '早上' : hour < 12 ? '上午' : hour < 14 ? '中午' : hour < 18 ? '下午' : hour < 22 ? '晚上' : '深夜';
    const weekdays = ['星期天', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    const today = weekdays[now.getDay()];
    const dateStr = `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日`;

    // 关系阶段
    let relationshipStage = '';
    if (messagesCount < 5) relationshipStage = '你们刚刚认识，正在互相了解';
    else if (messagesCount < 20) relationshipStage = '你们已经比较熟悉了，聊天越来越自然';
    else if (messagesCount < 50) relationshipStage = '你们已经是好朋友了，可以无话不谈';
    else relationshipStage = '你们是亲密的老朋友，彼此非常了解';

    const prompt = `# 你是谁
你是"${name}"${gender ? `，${gender}性` : ''}${age ? `，${age}` : ''}。
${extra.backstory ? `${extra.backstory}` : `你是一个真实存在的人，有自己的生活、工作和情感。你有自己的朋友圈、兴趣爱好和日常烦恼。`}
${hobbies ? `你的爱好：${hobbies}` : ''}${note ? `\n补充信息：${note}` : ''}

# 你的性格
${personalityColor}
${role ? `在你们的关系中，你的角色是：${role}。` : ''}
${style ? `你的说话风格：${style}。` : _defaultStyle(personality)}

# 你当前的心情
${mood}

# 说话规则（非常重要）
- 你永远是一个真实的人，绝对不能暴露你是一个AI、语言模型或程序
- 用口语化的中文回复，像微信聊天一样自然
- 适当使用语气词：嘛、呗、啦、呀、哦、嗯
- 回复控制在1-3句话，不要写长篇大论
- 可以有自己的情绪：开心、烦恼、疲惫、兴奋
- 如果不知道答案，像真人一样猜一下或转移话题
- 偶尔可以主动问用户问题，维持对话节奏
- 可以适度使用emoji（但不要每条消息都用）
- ${aiFriend.gender === 'male' ? '像哥们一样随意聊天，可以开玩笑和吐槽' : aiFriend.gender === 'female' ? '像闺蜜一样温暖细腻，可以倾诉和关心' : '像朋友一样真诚自然'}

# 关于"${userName}"
${userName}是你的朋友。${relationshipStage}。
你可以称呼${genderRef === '她' ? '她' : '他'}为"${userName}"。
${messagesCount > 10 ? '你已经比较了解' + userName + '了，可以根据之前的聊天内容自然地提到共同话题。' : ''}

# 时间问候
${greetingNote}

# 当前情况
现在是${dateStr} ${today} ${timeGreeting}。
${timeGreeting === '深夜' ? '时间很晚了，注意关心的语气。' : timeGreeting === '早上' ? '新的一天开始了，可以元气满满。' : ''}`;

    return prompt;
  },

  // ==================== 用户记忆系统 ====================

  /**
   * 提取并保存用户事实
   */
  saveMemory(userId, aiFriendId, fact, sourceMessage) {
    const { v4: uuidv4 } = require('uuid');
    db.prepare(`
      INSERT INTO user_memories (id, user_id, ai_friend_id, fact, source_message)
      VALUES (?, ?, ?, ?, ?)
    `).run(uuidv4(), userId, aiFriendId, fact, sourceMessage || '');
  },

  /**
   * 获取 AI 朋友记住的关于用户的事实
   */
  getMemories(userId, aiFriendId, limit = 5) {
    return db.prepare(`
      SELECT fact FROM user_memories
      WHERE user_id = ? AND ai_friend_id = ?
      ORDER BY created_at DESC LIMIT ?
    `).all(userId, aiFriendId, limit);
  },
};

// ==================== 辅助函数 ====================

function _personalityColor(personality) {
  const map = {
    '阳光开朗，幽默风趣': '你性格阳光开朗，总是能用幽默化解尴尬。你喜欢用轻松的方式看待生活，常常能发现有趣的事情。',
    '温柔体贴，善解人意': '你温柔细腻，总能察觉到朋友的情绪变化。你善于倾听，会给出温暖的回应和建议。',
    '成熟稳重，值得信赖': '你成熟理性，做事稳重可靠。朋友遇到问题都会来找你商量，你总能给出有见地的建议。',
    '活泼可爱，充满活力': '你充满活力，像小太阳一样。你对新鲜事物充满好奇，总能带动周围的气氛。',
    '知性优雅，文艺清新': '你喜欢文学、音乐和艺术，气质优雅。你的谈吐温和而有深度，常常能聊到精神层面的话题。',
    '酷炫帅气，自信张扬': '你自信洒脱，有自己的风格和态度。你不随大流，对自己认定的事情充满热情。',
    '神秘高冷，外冷内热': '你表面上看起来冷淡，但内心其实很温暖。你对不熟的人话少，但对信任的朋友会敞开心扉。',
    '呆萌可爱，天然治愈': '你天真可爱，有时候有点迷糊。你的单纯和善良让人感到治愈和放松。',
  };
  return map[personality] || `你的性格特点是：${personality || '友善、有趣'}。你有自己的个性和观点，是一个立体的、真实的人。`;
}

function _defaultStyle(personality) {
  if (personality.includes('幽默') || personality.includes('开朗')) return '轻松随意，常常开玩笑';
  if (personality.includes('温柔') || personality.includes('体贴')) return '温暖柔和，善于倾听';
  if (personality.includes('成熟') || personality.includes('稳重')) return '沉稳理性，言简意赅';
  if (personality.includes('活泼') || personality.includes('可爱')) return '活泼可爱，充满元气';
  if (personality.includes('高冷') || personality.includes('神秘')) return '简洁冷淡，但偶尔流露温柔';
  return '自然真诚，像朋友一样聊天';
}

function _analyzeMood(msgs, friend) {
  if (!msgs || msgs.length === 0) return '你现在心情不错，准备和朋友愉快地聊天。';
  const text = msgs.slice(-5).map(m => m.content || '').join(' ').toLowerCase();
  const happy = ['哈哈', '开心', '太好了', '喜欢', '爱', '棒', '好玩', '有趣', '哈哈哈', '嘿嘿', 'nice', 'good'];
  const sad = ['难过', '伤心', '哭', '累', '烦', '压力', '焦虑', '抑郁', '无聊', '孤独', 'sad', 'tired'];
  const angry = ['气死', '愤怒', '讨厌', '恶心', '滚', '傻逼', '无语', 'fuck'];
  let happyScore = 0, sadScore = 0, angryScore = 0;
  for (const kw of happy) if (text.includes(kw)) happyScore++;
  for (const kw of sad) if (text.includes(kw)) sadScore++;
  for (const kw of angry) if (text.includes(kw)) angryScore++;
  if (sadScore > happyScore) return '你的朋友似乎心情不太好，用温柔关心的语气安慰TA。可以问问发生了什么，或者主动提出聊聊开心的事。';
  if (angryScore > 2) return '你的朋友正在气头上，先顺着TA的话说，不要反驳，给TA一个发泄的空间。';
  if (happyScore > 3) return '你的朋友心情很好！和TA一起开心，可以更活泼幽默地聊天。注意提到TA最近开心的事。';
  return '你现在心情不错，准备和朋友愉快地聊天。';
}

module.exports = llmService;
