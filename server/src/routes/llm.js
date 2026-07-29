const express = require('express');
const router = express.Router();
const llmService = require('../services/llmService');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/llm/config — 获取用户 LLM 配置
router.get('/config', (req, res) => {
  try {
    const llmConfig = llmService.getUserConfig(req.user.id);
    // 不返回完整 apiKey
    res.json({
      baseUrl: llmConfig.baseUrl,
      model: llmConfig.model,
      hasApiKey: !!llmConfig.apiKey,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/llm/config — 更新用户 LLM 配置
router.put('/config', (req, res) => {
  try {
    const { apiBaseUrl, apiKey, model } = req.body;
    llmService.saveUserConfig(req.user.id, { apiBaseUrl, apiKey, model });
    res.json({ message: '配置已更新' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
