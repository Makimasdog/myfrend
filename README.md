# myfrends

myfrends is a Flutter chat client with a Node.js backend. It supports AI friends,
human friendships, text and voice messages, streamed AI responses, and per-user
LLM provider settings.

## Structure

```text
client/  Flutter application for Windows and Android
server/  Express API, WebSocket endpoints, and sql.js data storage
```

## Local development

1. Create the server environment file.

```powershell
Copy-Item server/.env.example server/.env
```

Set a strong `JWT_SECRET` in `server/.env`. Configure a default LLM provider
there only when required; users can instead set their own provider in the app.

2. Start the backend.

```powershell
Set-Location server
npm ci
npm run dev
```

The server listens on `http://127.0.0.1:3000` by default.

3. Start the Flutter client.

```powershell
Set-Location client
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

The client uses `http://127.0.0.1:3000/api` by default on desktop and
`http://10.0.2.2:3000/api` on an Android emulator. For a physical device or a
remote deployment, pass its reachable API address with `API_BASE_URL`.

```powershell
flutter run --dart-define=API_BASE_URL=https://example.com/api
```

## Verification

```powershell
Set-Location server
npm test -- --runInBand
npm audit --omit=dev

Set-Location ../client
flutter analyze
```

## Container deployment

For a single-host deployment, populate `server/.env`, then run:

```powershell
docker compose up --build -d
```

Persist `server/data` and `server/uploads`; they contain the application
database and uploaded voice files. Place the server behind an HTTPS reverse
proxy in production. The proxy must forward both `/api` HTTP traffic and
WebSocket upgrades for `/ws/chat` and `/ws/call`.
