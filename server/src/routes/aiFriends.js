const express = require('express');
const router = express.Router();
const aiFriendService = require('../services/aiFriendService');
const { authMiddleware } = require('../middleware/auth');

// 所有 AI 朋友路由都需要认证
router.use(authMiddleware);

// GET /api/ai-friends — 获取我的 AI 朋友列表
router.get('/', (req, res) => {
  try {
    const friends = aiFriendService.listByOwner(req.user.id);
    res.json(friends);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/ai-friends — 创建 AI 朋友
router.post('/', (req, res) => {
  try {
    const friend = aiFriendService.create(req.user.id, req.body);
    res.status(201).json(friend);
  } catch (err) {
    console.error('[ai-friends POST]', err);
    res.status(400).json({ error: err.message || String(err) });
  }
});

// GET /api/ai-friends/:id — 获取 AI 朋友详情
router.get('/:id', (req, res) => {
  try {
    const friend = aiFriendService.getById(req.params.id, req.user.id);
    if (!friend) return res.status(404).json({ error: 'AI 朋友不存在' });
    res.json(friend);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/ai-friends/:id — 更新 AI 朋友
router.put('/:id', (req, res) => {
  try {
    const friend = aiFriendService.update(req.params.id, req.user.id, req.body);
    res.json(friend);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/ai-friends/:id — 删除 AI 朋友
router.delete('/:id', (req, res) => {
  try {
    aiFriendService.remove(req.params.id, req.user.id);
    res.json({ message: '删除成功' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
