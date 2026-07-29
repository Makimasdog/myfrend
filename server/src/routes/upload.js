const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// 确保上传目录存在
const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// 配置 multer — 只接受音频文件
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.m4a';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = [
      'audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/wav',
      'audio/x-wav', 'audio/webm', 'audio/ogg',
      'audio/aac', 'audio/x-m4a', 'application/octet-stream',
    ];
    // 也接受常见的音频扩展名
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExt = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.webm', '.opus', '.flac'];
    if (allowed.includes(file.mimetype) || allowedExt.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`不支持的音频格式: ${file.mimetype} (${ext})`));
    }
  },
});

// POST /api/upload/voice — 上传语音消息
router.post('/voice', authMiddleware, upload.single('audio'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: '未提供音频文件' });
  }

  const voiceUrl = `/uploads/${req.file.filename}`;
  res.json({
    voiceUrl,
    filename: req.file.filename,
    size: req.file.size,
    duration: req.body.duration || null,
  });
});

module.exports = router;
