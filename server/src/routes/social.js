const express = require('express');
const router = express.Router();
const socialService = require('../services/socialService');
const { authMiddleware } = require('../middleware/auth');

router.use(authMiddleware);

// GET /api/social/search?q=xxx — 搜索用户
router.get('/search', (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.status(400).json({ error: '搜索关键词不能为空' });
    const users = socialService.searchUsers(q, req.user.id);
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/social/friends — 好友列表
router.get('/friends', (req, res) => {
  try {
    const friends = socialService.getFriendList(req.user.id);
    res.json(friends);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/social/friends/request — 发送好友请求
router.post('/friends/request', (req, res) => {
  try {
    const { friendId } = req.body;
    if (!friendId) return res.status(400).json({ error: 'friendId 不能为空' });
    const result = socialService.sendFriendRequest(req.user.id, friendId);
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/social/friends/requests — 待处理的好友请求
router.get('/friends/requests', (req, res) => {
  try {
    const requests = socialService.getPendingRequests(req.user.id);
    res.json(requests);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/social/friends/accept/:requestId — 接受好友请求
router.post('/friends/accept/:requestId', (req, res) => {
  try {
    const result = socialService.acceptFriendRequest(req.user.id, req.params.requestId);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
