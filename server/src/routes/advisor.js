const express = require('express');
const router = express.Router();
const advisorService = require('../services/advisorService');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// POST /api/advisor/advice — 获取 AI 军师建议
router.post('/advice', async (req, res) => {
  try {
    const { sessionId, aiFriendId, context } = req.body;
    if (!sessionId || !aiFriendId) {
      return res.status(400).json({ error: 'sessionId 和 aiFriendId 不能为空' });
    }
    const result = await advisorService.getAdvice(req.user.id, sessionId, aiFriendId, context);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/advisor/history/:sessionId — 获取军师历史
router.get('/history/:sessionId', (req, res) => {
  try {
    const history = advisorService.getHistory(req.params.sessionId);
    res.json(history);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
