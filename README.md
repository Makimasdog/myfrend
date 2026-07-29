# myfrends — AI 聊天交友平台

多平台（Windows / Android）AI 聊天软件，支持语音对话、文字聊天、真人交友。

## 项目结构

```
myfrends/
├── server/          # Node.js Express 后端
│   ├── src/
│   │   ├── config/        # 配置
│   │   ├── models/        # 数据库（SQLite via sql.js）
│   │   ├── services/      # 业务逻辑
│   │   ├── routes/        # API 路由
│   │   └── middleware/    # 中间件（JWT认证等）
│   └── package.json
├── client/          # Flutter 跨平台前端
│   ├── lib/
│   │   ├── main.dart
│   │   └── src/
│   │       ├── models/    # 数据模型
│   │       ├── services/  # API 服务
│   │       ├── providers/ # 状态管理
│   │       ├── pages/     # 页面
│   │       └── widgets/   # 组件
│   └── pubspec.yaml
└── README.md
```

## 技术栈

| 层 | 技术 |
|------|------|
| 前端 | Flutter (Dart) — Windows + Android |
| 后端 | Node.js + Express |
| 数据库 | SQLite (sql.js) |
| 实时通信 | WebSocket (ws) |
| 认证 | JWT |

## 功能概览

1. **AI 朋友** — 通过向导创建个性化 AI 朋友（性别/年龄/性格）
2. **语音对话** — 与 AI 朋友实时语音交流
3. **文字聊天** — 与 AI 朋友文字聊天，LLM 自动回复
4. **真人交友** — 社区搜索、添加好友、文字/语音聊天
5. **AI 军师** — 在真人聊天中召唤 AI 朋友提供建议
6. **自定义 LLM** — 支持用户配置自己的 API Key

## 快速开始

### 后端

```bash
cd server
npm install
npm run dev    # 开发模式（端口 3000）
```

### 前端

```bash
# 确保已安装 Flutter SDK (>=3.1.0)
cd client
flutter pub get
flutter run    # 选择目标平台：windows / android
```

## API 端点

| 路径 | 方法 | 描述 |
|------|------|------|
| `/api/auth/register` | POST | 注册 |
| `/api/auth/login` | POST | 登录 |
| `/api/auth/me` | GET | 个人信息 |
| `/api/ai-friends` | GET/POST | AI朋友列表/创建 |
| `/api/chat/sessions` | GET/POST | 会话列表/创建 |
| `/api/chat/sessions/:id/messages` | GET/POST | 消息 |
| `/api/chat/sessions/:id/ai-reply` | POST | AI回复 |
| `/api/social/search` | GET | 搜索用户 |
| `/api/social/friends` | GET | 好友列表 |
| `/api/social/friends/request` | POST | 发送好友请求 |
| `/api/advisor/advice` | POST | 获取AI军师建议 |
| `/api/llm/config` | GET/PUT | LLM 配置 |
