/**
 * TTS 语音合成服务 — 使用 Microsoft Edge TTS (免费)
 */
const https = require('https');
const http = require('http');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

// Edge TTS 配置
const EDGE_TTS_URL = 'speech.platform.bing.com';
const EDGE_TTS_PATH = '/consumer/speech/synthesize/readaloud/edge/v1';

const VOICES = {
  'zh-CN-female': 'zh-CN-XiaoxiaoNeural',   // 女声 — 温柔
  'zh-CN-male': 'zh-CN-YunxiNeural',         // 男声
  'zh-CN-female2': 'zh-CN-XiaoyiNeural',     // 女声 — 活泼
  'en-US-female': 'en-US-JennyNeural',        // 英文女声
  'en-US-male': 'en-US-GuyNeural',            // 英文男声
};

const ttsService = {
  /**
   * 文本转语音 — 返回音频文件路径
   * @param {string} text — 要转换的文本
   * @param {string} voice — 声音类型 (默认女声)
   * @returns {Promise<{filePath: string, url: string}>}
   */
  async synthesize(text, voice = 'zh-CN-female') {
    const voiceName = VOICES[voice] || VOICES['zh-CN-female'];
    const ssml = `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="zh-CN">
      <voice name="${voiceName}">
        <prosody rate="1.0" pitch="0%">
          ${text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}
        </prosody>
      </voice>
    </speak>`;

    const postData = ssml;
    const options = {
      hostname: EDGE_TTS_URL,
      path: EDGE_TTS_PATH + '?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4',
      method: 'POST',
      headers: {
        'Content-Type': 'application/ssml+xml',
        'Content-Length': Buffer.byteLength(postData),
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        'User-Agent': 'Mozilla/5.0',
        'Origin': 'https://www.bing.com',
        'Accept': '*/*',
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const buffer = Buffer.concat(chunks);
          const filename = `tts_${uuidv4()}.mp3`;
          const uploadsDir = path.join(__dirname, '..', '..', 'uploads', 'tts');
          if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
          const filePath = path.join(uploadsDir, filename);
          fs.writeFileSync(filePath, buffer);
          resolve({
            filePath,
            url: `/uploads/tts/${filename}`,
            size: buffer.length,
          });
        });
      });

      req.on('error', (e) => reject(e));
      req.write(postData);
      req.end();
    });
  },

  /**
   * 流式 TTS — 逐块返回音频数据（用于实时通话）
   */
  async synthesizeStream(text, voice = 'zh-CN-female', onChunk) {
    const voiceName = VOICES[voice] || VOICES['zh-CN-female'];
    const ssml = `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="zh-CN">
      <voice name="${voiceName}">
        <prosody rate="1.1" pitch="0%">
          ${text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}
        </prosody>
      </voice>
    </speak>`;

    const options = {
      hostname: EDGE_TTS_URL,
      path: EDGE_TTS_PATH + '?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4',
      method: 'POST',
      headers: {
        'Content-Type': 'application/ssml+xml',
        'Content-Length': Buffer.byteLength(ssml),
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        'User-Agent': 'Mozilla/5.0',
        'Origin': 'https://www.bing.com',
        'Accept': '*/*',
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let firstChunk = true;
        res.on('data', (chunk) => {
          if (firstChunk) { firstChunk = false; return; } // 跳过 header
          onChunk(chunk);
        });
        res.on('end', resolve);
        res.on('error', reject);
      });
      req.on('error', reject);
      req.write(ssml);
      req.end();
    });
  },
};

module.exports = ttsService;
