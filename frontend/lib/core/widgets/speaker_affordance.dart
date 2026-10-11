import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Speaker Affordance
///
/// Capsule or icon button labelled "Tap to hear" that invokes VoiceService.
/// Displays an animated soundwave bar visualizer and a Stop button while speaking.
/// Section 5.5 of Project Specification & Voice requirement.
class SpeakerAffordance extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool? isPlaying;
  final bool isCompact;
  final String? textToSpeak;
  final String? languageCode;

  const SpeakerAffordance({
    super.key,
    this.onTap,
    this.label = 'Tap to hear',
    this.isPlaying,
    this.isCompact = false,
    this.textToSpeak,
    this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: VoiceService.instance,
      builder: (context, _) {
        final voice = VoiceService.instance;
        final bool active = isPlaying ??
            (textToSpeak != null
                ? voice.currentlySpeaking == textToSpeak
                : false);

        void handleTap() {
          if (active) {
            voice.stop();
            if (isPlaying != null && onTap != null) {
              onTap!();
            }
          } else if (onTap != null) {
            onTap!();
          } else if (textToSpeak != null && languageCode != null) {
            voice.speak(text: textToSpeak!, languageCode: languageCode!);
          }
        }

        if (isCompact) {
          if (active) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SoundWaveBarIndicator(color: AppColors.primary),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.stop_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  tooltip: 'Stop',
                  onPressed: handleTap,
                ),
              ],
            );
          }

          return IconButton(
            icon: const Icon(
              Icons.volume_up_outlined,
              color: AppColors.inkPrimary,
              size: 22,
            ),
            tooltip: label,
            onPressed: handleTap,
          );
        }

        if (active) {
          return Semantics(
            button: true,
            label: 'Stop speech',
            child: Material(
              color: AppColors.primaryLight,
              borderRadius: AppRadii.buttonRadius,
              child: InkWell(
                onTap: handleTap,
                borderRadius: AppRadii.buttonRadius,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.buttonRadius,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SoundWaveBarIndicator(color: AppColors.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Stop',
                          style: AppTextStyles.labelMedium(
                            color: AppColors.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.stop_circle_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Semantics(
          button: true,
          label: label,
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadii.buttonRadius,
            child: InkWell(
              onTap: handleTap,
              borderRadius: AppRadii.buttonRadius,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.buttonRadius,
                  border: Border.all(
                    color: AppColors.hairline,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.volume_up_outlined,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.labelMedium(
                          color: AppColors.inkPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small animated sound wave equalizer bars indicating active speech
class _SoundWaveBarIndicator extends StatefulWidget {
  final Color color;
  const _SoundWaveBarIndicator({required this.color});

  @override
  State<_SoundWaveBarIndicator> createState() => _SoundWaveBarIndicatorState();
}

class _SoundWaveBarIndicatorState extends State<_SoundWaveBarIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3.0,
              height: 6.0 + 8.0 * v,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 3.0,
              height: 14.0 - 8.0 * v,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 3.0,
              height: 7.0 + 7.0 * (1.0 - v),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}
