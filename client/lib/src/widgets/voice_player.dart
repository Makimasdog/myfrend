import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

/// 语音消息播放气泡
class VoicePlayerBubble extends StatefulWidget {
  final String voiceUrl;
  final bool isMe;
  final String? duration;

  const VoicePlayerBubble({
    super.key,
    required this.voiceUrl,
    required this.isMe,
    this.duration,
  });

  @override
  State<VoicePlayerBubble> createState() => _VoicePlayerBubbleState();
}

class _VoicePlayerBubbleState extends State<VoicePlayerBubble>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  double _position = 0;
  double _maxDuration = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos.inMilliseconds.toDouble());
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      if (state == PlayerState.completed) {
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String sourceUrl) async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(sourceUrl));
      // 获取时长
      final d = await _player.getDuration();
      if (d != null && mounted) {
        setState(() => _maxDuration = d.inMilliseconds.toDouble());
      }
    }
  }

  String get _baseUrl {
    // 从 voiceUrl 中提取基础 URL
    final uri = Uri.tryParse(widget.voiceUrl);
    if (uri != null && uri.host.isNotEmpty) return widget.voiceUrl;
    // 如果是相对路径，拼接 API 基础地址
    return widget.voiceUrl;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = widget.isMe ? cs.primary : cs.surfaceContainerHighest;
    final fgColor = widget.isMe ? cs.onPrimary : cs.onSurface;
    final sourceUrl = context.read<ApiService>().resolveServerUrl(_baseUrl);
    final messenger = ScaffoldMessenger.of(context);

    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          if (_isPlaying) {
            await _toggle(sourceUrl);
            return;
          }
          // 使用完整URL播放
          await _player.stop(); // 确保干净的播放状态
          try {
            await _player.play(
              UrlSource(sourceUrl),
            );
            final d = await _player.getDuration();
            if (d != null && mounted) {
              setState(() => _maxDuration = d.inMilliseconds.toDouble());
            }
            if (mounted) setState(() => _isPlaying = true);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text('播放失败: $e')));
            }
          }
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // 播放/暂停图标
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(_isPlaying),
              color: fgColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          // 波形进度条
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 20,
                child: LayoutBuilder(builder: (_, constraints) {
                  return CustomPaint(
                    painter: _ProgressWavePainter(
                      progress: _maxDuration > 0 ? _position / _maxDuration : 0,
                      color: fgColor.withAlpha(150),
                      playedColor: fgColor,
                    ),
                    size: Size(constraints.maxWidth, 20),
                  );
                }),
              ),
              const SizedBox(height: 2),
              Text(
                _isPlaying
                    ? '${(_position / 1000).toStringAsFixed(1)}s'
                    : (widget.duration != null
                        ? '${widget.duration}s'
                        : (_maxDuration > 0
                            ? '${(_maxDuration / 1000).toStringAsFixed(1)}s'
                            : '语音消息')),
                style: TextStyle(fontSize: 10, color: fgColor.withAlpha(180)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ProgressWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color playedColor;

  _ProgressWavePainter(
      {required this.progress, required this.color, required this.playedColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const barCount = 20;
    final barWidth = (size.width - (barCount - 1) * 2) / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 2);
      final p = i / barCount;
      final height = (3 + (p < 0.5 ? p * 2 : (1 - p) * 2) * 14)
          .clamp(3.0, size.height - 4);
      paint.color = p <= progress ? playedColor : color;
      canvas.drawLine(Offset(x + barWidth / 2, size.height / 2 - height / 2),
          Offset(x + barWidth / 2, size.height / 2 + height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressWavePainter old) =>
      old.progress != progress;
}
