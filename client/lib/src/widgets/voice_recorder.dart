import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// 按住说话的语音录制按钮
class VoiceRecordButton extends StatefulWidget {
  final ApiService api;
  final Function(Map<String, dynamic> result) onUploaded; // {voiceUrl, duration}

  const VoiceRecordButton({super.key, required this.api, required this.onUploaded});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  double _amplitude = 0;
  StreamSubscription<RecordState>? _stateSub;
  StreamSubscription<Amplitude>? _ampSub;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseAnim = Tween(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
    _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请授权麦克风权限')));
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
        path: path,
      );

      setState(() { _isRecording = true; _seconds = 0; });
      _pulseCtrl.repeat(reverse: true);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
        if (_seconds >= 60) _stop(); // 最长60秒
      });

      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        if (mounted) setState(() => _amplitude = (amp.current + amp.max) / 2);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('录音失败: $e')));
    }
  }

  Future<void> _stop() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _ampSub?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    final path = await _recorder.stop();
    if (path == null || !File(path).existsSync()) {
      setState(() => _isRecording = false);
      return;
    }

    setState(() => _isRecording = false);

    // 上传到服务器
    try {
      final result = await widget.api.uploadVoice(path, duration: '$_seconds');
      widget.onUploaded({...result, 'localPath': path});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('语音上传失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: _isRecording ? _pulseAnim.value : 1.0,
          child: child,
        ),
        child: _isRecording ? _RecordingIndicator(seconds: _seconds, amplitude: _amplitude, cs: cs, onCancel: _stop)
            : Icon(Icons.mic_outlined, color: cs.primary, size: 26),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final int seconds;
  final double amplitude;
  final ColorScheme cs;
  final VoidCallback onCancel;
  const _RecordingIndicator({required this.seconds, required this.amplitude, required this.cs, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // 波形动画
        SizedBox(
          width: 24, height: 24,
          child: CustomPaint(painter: _WavePainter(amplitude: amplitude, color: Colors.red)),
        ),
        const SizedBox(width: 8),
        Text('${seconds}s', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCancel,
          child: const Icon(Icons.close, color: Colors.red, size: 20),
        ),
      ]),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double amplitude;
  final Color color;
  _WavePainter({required this.amplitude, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(180)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final w = size.width / 3;
    final a = (amplitude * 10).clamp(2.0, size.height * 0.45);
    canvas.drawLine(Offset(w, size.height / 2 - a), Offset(w, size.height / 2 + a), paint);
    canvas.drawLine(Offset(w * 1.5, size.height / 2 - a * 1.3), Offset(w * 1.5, size.height / 2 + a * 1.3), paint);
    canvas.drawLine(Offset(w * 2, size.height / 2 - a * 0.8), Offset(w * 2, size.height / 2 + a * 0.8), paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.amplitude != amplitude;
}
