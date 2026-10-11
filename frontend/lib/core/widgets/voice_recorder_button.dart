import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Voice Recorder Button
/// Large mic button, live waveform animation, timer, hold/tap to record, 90s limit
/// Section 5.5 of Project Specification
class VoiceRecorderButton extends StatefulWidget {
  final bool isRecording;
  final ValueChanged<bool>? onRecordingChanged;
  final ValueChanged<int>? onCompletedSeconds;
  final int maxDurationSeconds;

  const VoiceRecorderButton({
    super.key,
    this.isRecording = false,
    this.onRecordingChanged,
    this.onCompletedSeconds,
    this.maxDurationSeconds = 90,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _internalRecording = false;

  bool get _activeRecording => widget.onRecordingChanged == null
      ? _internalRecording
      : widget.isRecording;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isRecording) {
      _startRecordingFlow();
    }
  }

  @override
  void didUpdateWidget(covariant VoiceRecorderButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startRecordingFlow();
      } else {
        _stopRecordingFlow();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleRecording() {
    final nextState = !_activeRecording;
    if (widget.onRecordingChanged != null) {
      widget.onRecordingChanged!(nextState);
    } else {
      setState(() {
        _internalRecording = nextState;
      });
      if (nextState) {
        _startRecordingFlow();
      } else {
        _stopRecordingFlow();
      }
    }
  }

  void _startRecordingFlow() {
    _secondsElapsed = 0;
    _animController.repeat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
      });
      if (_secondsElapsed >= widget.maxDurationSeconds) {
        _stopRecordingFlow();
        if (widget.onRecordingChanged != null) {
          widget.onRecordingChanged!(false);
        } else {
          setState(() {
            _internalRecording = false;
          });
        }
      }
    });
  }

  void _stopRecordingFlow() {
    _animController.stop();
    _timer?.cancel();
    if (widget.onCompletedSeconds != null) {
      widget.onCompletedSeconds!(_secondsElapsed);
    }
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live Waveform & Timer display when recording
        if (_activeRecording) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.statusError,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDuration(_secondsElapsed)} / ${_formatDuration(widget.maxDurationSeconds)}',
                style: AppTextStyles.labelMedium(color: AppColors.statusError),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: 220,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AudioWaveformPainter(animationValue: _animController.value),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Mic Button with pulsing aura
        GestureDetector(
          onTap: _toggleRecording,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_activeRecording)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final scale = 1.0 + (_animController.value * 0.25);
                    final opacity = (1.0 - _animController.value).clamp(0.0, 0.4);
                    return Container(
                      width: 88 * scale,
                      height: 88 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.craftTerracotta.withValues(alpha: opacity),
                      ),
                    );
                  },
                ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _activeRecording ? AppColors.craftTerracotta : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_activeRecording ? AppColors.craftTerracotta : AppColors.primary)
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _activeRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text(
          _activeRecording ? 'Tap to stop' : 'Tap to speak (up to 90s)',
          style: AppTextStyles.labelMedium(
            color: _activeRecording ? AppColors.craftTerracotta : AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  final double animationValue;

  _AudioWaveformPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.craftTerracotta
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const barCount = 18;
    final spacing = size.width / barCount;
    final midY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      // Generate dynamic heights using sinusoidal offset with animation phase
      final phase = (animationValue * 2 * math.pi) + (i * 0.45);
      final heightRatio = (math.sin(phase).abs() * 0.75) + 0.25;
      final barHeight = (size.height * heightRatio) / 2;

      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWaveformPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
