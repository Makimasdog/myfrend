import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme.dart';

class VoiceCallPage extends StatefulWidget {
  final String token;
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  const VoiceCallPage({super.key, required this.token, required this.friendId, required this.friendName, this.friendAvatar});
  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> with TickerProviderStateMixin {
  // WebSocket
  WebSocketChannel? _channel;
  String _connState = 'connecting';
  String _statusText = 'Connecting...';
  bool _disposed = false;

  // Speech recognition
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _recognizedText = '';
  final _textCtrl = TextEditingController(); // fallback text input

  // Audio
  final _player = AudioPlayer();
  StreamSubscription? _completeSub;
  final List<Uint8List> _audioChunks = [];
  bool _isAiSpeaking = false;
  String _aiText = '';

  // UI
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;

  // Get the WebSocket host - use current page hostname for web, or localhost
  String get _wsHost {
    // For web: use the current page's hostname (same as API server)
    // For mobile: connects to the same host as the API
    try {
      final uri = Uri.base;
      if (uri.host.isNotEmpty && uri.host != 'localhost') {
        return uri.host; // e.g. 192.168.1.5 if accessing via IP
      }
    } catch (_) {}
    return 'localhost';
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnim = Tween(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _waveAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut));
    _waveCtrl.repeat(reverse: true);
    _initCall();
  }

  Future<void> _initCall() async {
    // Try speech recognition (may fail on web)
    try {
      final available = await _speech.initialize(
        onStatus: (status) { if (!_disposed && status == 'notListening') _startListening(); },
        onError: (e) => debugPrint('STT: $e'),
      );
      if (!_disposed) setState(() => _speechEnabled = available);
    } catch (_) {
      debugPrint('STT init failed - using text fallback');
    }
    _connectWebSocket();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  void _connectWebSocket() {
    if (_disposed) return;
    setState(() { _connState = 'connecting'; _statusText = 'Connecting...'; });
    try {
      final host = _wsHost;
      final uri = Uri(scheme: 'ws', host: _wsHost, port: 3000, path: '/ws/call', queryParameters: {
        'friend_id': widget.friendId,
      });
      debugPrint('[Call] WS connected');
      _channel = WebSocketChannel.connect(uri);
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': widget.token}));
      setState(() { _connState = 'connected'; _statusText = 'Connected - listening...'; });
      _channel!.stream.listen(
        (data) { final msg = jsonDecode(data as String) as Map<String, dynamic>; _handleMessage(msg); },
        onError: (e) {
          debugPrint('[Call] WS error: $e');
          setState(() { _connState = 'failed'; _statusText = 'Connection lost, retrying...'; });
          Future.delayed(const Duration(seconds: 3), () {
            if (!_disposed && _connState == 'failed') _connectWebSocket();
          });
        },
        onDone: () {
          debugPrint('[Call] WS closed');
          if (!_disposed) { setState(() { _connState = 'failed'; _statusText = 'Disconnected, retrying...'; }); }
          Future.delayed(const Duration(seconds: 3), () { if (!_disposed && _connState == 'failed') _connectWebSocket(); });
        },
      );
      _startListening();
    } catch (e) {
      debugPrint('[Call] Connect failed: $e');
      setState(() { _connState = 'failed'; _statusText = 'Failed: $e'; });
      Future.delayed(const Duration(seconds: 3), () {
        if (!_disposed && _connState == 'failed') _connectWebSocket();
      });
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    if (_disposed) return;
    switch (msg['type']) {
      case 'ready':
        debugPrint('[Call] Server ready, session=${msg['sessionId']}');
        break;
      case 'recognized':
        setState(() { _recognizedText = msg['text'] ?? ''; _statusText = 'Heard: ${msg['text']}'; });
        break;
      case 'tts_start':
        setState(() {
          _isAiSpeaking = true;
          _aiText = msg['text'] ?? '';
          _statusText = 'AI speaking...';
          _audioChunks.clear();
        });
        break;
      case 'tts_chunk':
        final raw = msg['data'];
        if (raw != null) {
          _audioChunks.add(base64Decode(raw as String));
          if (_audioChunks.length >= 3 && _player.state != PlayerState.playing) {
            _playAudioChunks();
          }
        }
        break;
      case 'tts_end':
        _playAudioChunks();
        break;
      case 'tts_stop':
        _player.stop();
        setState(() => _isAiSpeaking = false);
        break;
      case 'text_reply':
        setState(() { _aiText = msg['text'] ?? ''; _statusText = 'AI replied (text)'; });
        break;
      case 'error':
        setState(() { _statusText = 'Error: ${msg['error']}'; _aiText = msg['error']?.toString() ?? ''; });
        break;
    }
  }

  Future<void> _playAudioChunks() async {
    if (_audioChunks.isEmpty) return;
    final allBytes = _concatenateChunks();
    try {
      _completeSub?.cancel();
      await _player.stop(); // ensure clean state
      await _player.play(BytesSource(allBytes));
      _completeSub = _player.onPlayerComplete.listen((_) {
        if (!_disposed) {
          setState(() { _isAiSpeaking = false; _statusText = 'Connected - listening...'; });
          _startListening();
        }
      });
    } catch (e) {
      debugPrint('[Call] Play error: $e');
      _audioChunks.clear();
      if (!_disposed) { setState(() { _isAiSpeaking = false; _statusText = 'Connected - listening...'; }); _startListening(); }
    }
  }

  Uint8List _concatenateChunks() {
    int total = 0;
    for (final c in _audioChunks) total += c.length;
    final result = Uint8List(total);
    int offset = 0;
    for (final c in _audioChunks) { result.setRange(offset, offset + c.length, c); offset += c.length; }
    return result;
  }

  Future<void> _startListening() async {
    if (_isAiSpeaking || _disposed) return;
    if (_isListening) return;
    if (_connState != 'connected') return;

    if (_speechEnabled) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (_disposed) return;
            if (result.finalResult) {
              final text = result.recognizedWords.trim();
              if (text.isNotEmpty) {
                debugPrint('[Call] Speech: $text');
                _channel?.sink.add(jsonEncode({'type': 'speech', 'text': text}));
                setState(() => _recognizedText = '');
              }
            } else {
              setState(() => _recognizedText = result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
          localeId: 'zh_CN',
        );
        setState(() { _isListening = true; _statusText = 'Listening...'; });
      } catch (e) {
        debugPrint('[Call] STT listen error: $e');
      }
    } else {
      // Speech not available - user types instead
      setState(() { _statusText = 'Type your message below'; });
    }
  }

  void _sendText() {
    if (_disposed) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    debugPrint('[Call] Text: $text');
    _channel?.sink.add(jsonEncode({'type': 'speech', 'text': text}));
    _textCtrl.clear();
    setState(() { _recognizedText = text; _statusText = 'Sent: $text'; });
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);
  void _toggleSpeaker() => setState(() => _isSpeakerOn = !_isSpeakerOn);

  void _hangUp() {
    _disposed = true;
    _channel?.sink.add(jsonEncode({'type': 'hangup'}));
    _channel?.sink.close();
    _callTimer?.cancel();
    try { _speech.stop(); } catch (_) {}
    _completeSub?.cancel();
    try { _player.stop(); } catch (_) {}
    _pulseCtrl.stop();
    _waveCtrl.stop();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _disposed = true;
    _textCtrl.dispose();
    _callTimer?.cancel();
    _channel?.sink.close();
    try { _speech.stop(); } catch (_) {}
    _completeSub?.cancel();
    try { _player.stop(); } catch (_) {}
    try { _player.dispose(); } catch (_) {}
    try { _pulseCtrl.dispose(); } catch (_) {}
    try { _waveCtrl.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)]),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 40),
            Text(_formatDuration(_callDuration), style: TextStyle(fontSize: 16, color: Colors.white.withAlpha(180), letterSpacing: 2)),
            const Spacer(),

            // Avatar
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Container(
                width: 100 * _pulseAnim.value, height: 100 * _pulseAnim.value,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primaryLight, AppTheme.primary]), shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(80), blurRadius: 30, spreadRadius: 5)]),
                child: Center(child: Text(widget.friendName[0], style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.friendName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),

            // Status
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: _connState == 'connected' ? Colors.green.withAlpha(60) : Colors.orange.withAlpha(60), borderRadius: BorderRadius.circular(20)),
              child: Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),

            // Recognized / AI text
            if (_recognizedText.isNotEmpty || _aiText.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Text(_isAiSpeaking ? _aiText : _recognizedText, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14), maxLines: 4),
              ),

            // Wave animation
            if (_isAiSpeaking)
              AnimatedBuilder(animation: _waveAnim, builder: (_, __) => CustomPaint(size: const Size(120, 30), painter: _CallWavePainter(progress: _waveAnim.value, color: AppTheme.primaryLight))),

            const Spacer(),

            // Text input fallback (when speech not available)
            if (!_speechEnabled && _connState == 'connected')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type here (speech not available on web)...',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withAlpha(80))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendText),
                ]),
              ),

            // Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _CallButton(icon: _isMuted ? Icons.mic_off : Icons.mic, label: 'Mute', active: !_isMuted, onTap: _toggleMute),
                GestureDetector(onTap: _hangUp, child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 36))),
                _CallButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down, label: 'Speaker', active: _isSpeakerOn, onTap: _toggleSpeaker),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _CallButton({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 56, height: 56, decoration: BoxDecoration(color: active ? Colors.white.withAlpha(40) : Colors.white.withAlpha(20), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 26)),
    const SizedBox(height: 6), Text(label, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12))]));
}

class _CallWavePainter extends CustomPainter {
  final double progress; final Color color;
  _CallWavePainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withAlpha(120)..strokeWidth = 2..strokeCap = StrokeCap.round;
    final bars = 30; final barW = size.width / (bars * 1.5);
    for (int i = 0; i < bars; i++) {
      final x = i * barW * 1.5; double h;
      if (i < bars / 3) h = (i / (bars / 3)) * size.height * 0.8;
      else if (i < bars * 2 / 3) h = size.height * 0.8;
      else h = (1 - (i - bars * 2 / 3) / (bars / 3)) * size.height * 0.8;
      h *= 0.4 + 0.6 * (progress * (i % 3 + 1) / 3);
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - h), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _CallWavePainter old) => old.progress != progress;
}
