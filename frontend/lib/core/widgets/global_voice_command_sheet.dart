import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../routing/route_names.dart';
import '../services/audio_recording_service.dart';
import '../services/storage_service.dart';
import '../services/voice_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../../data/api/api_client.dart';
import '../../features/kalamitra/services/kalamitra_service.dart';

/// KalaSetu Global Voice Command Sheet
/// Requirement 3: Voice First global mic in header handled by Gemini intent routing.
/// Allows saying "add product", "my orders", "my price", "my earnings", "fair mode", "help".
class GlobalVoiceCommandSheet extends StatefulWidget {
  final String currentScreen;

  const GlobalVoiceCommandSheet({
    super.key,
    this.currentScreen = 'home',
  });

  static Future<void> show(BuildContext context, {String currentScreen = 'home'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlobalVoiceCommandSheet(currentScreen: currentScreen),
    );
  }

  @override
  State<GlobalVoiceCommandSheet> createState() => _GlobalVoiceCommandSheetState();
}

class _GlobalVoiceCommandSheetState extends State<GlobalVoiceCommandSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecordingService _audioService = AudioRecordingService();
  final ApiClient _apiClient = ApiClient();

  bool _isListening = false;
  bool _isProcessing = false;
  String? _recognizedText;
  String? _feedbackMessage;

  late AnimationController _pulseController;

  final List<Map<String, String>> _quickCommands = [
    {'labelKey': 'cmd_add_product', 'query': 'add product'},
    {'labelKey': 'cmd_my_orders', 'query': 'my orders'},
    {'labelKey': 'cmd_my_earnings', 'query': 'my earnings'},
    {'labelKey': 'cmd_fair_mode', 'query': 'fair mode'},
    {'labelKey': 'cmd_help_me', 'query': 'help me'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Auto-prompt voice prompt on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startVoiceListening() async {
    final hasPerm = await _audioService.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'mic_permission_denied'.tr();
        });
      }
      return;
    }

    final path = await _audioService.startRecording();
    if (path != null && mounted) {
      setState(() {
        _isListening = true;
        _feedbackMessage = 'listening_voice_cmd'.tr();
      });
    }
  }

  Future<void> _stopVoiceListeningAndSend() async {
    final path = await _audioService.stopRecording();
    if (!mounted) return;

    setState(() {
      _isListening = false;
      _isProcessing = true;
      _feedbackMessage = 'processing_voice_cmd'.tr();
    });

    if (path != null) {
      try {
        final lang = context.locale.languageCode;
        final res = await _apiClient.postMultipart(
          '/api/v1/catalog/transcribe',
          filePath: path,
          fileField: 'audio',
          fields: {'language_hint': lang},
        );

        final text = (res['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) {
          _executeCommand(text);
          return;
        }
      } catch (_) {
        // Fallback to text prompt if audio transcription fails
      } finally {
        await AudioRecordingService.deleteAudioFile(path);
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _feedbackMessage = 'could_not_hear_try_again'.tr();
      });
    }
  }

  Future<void> _executeCommand(String query) async {
    setState(() {
      _recognizedText = query;
      _isProcessing = true;
      _feedbackMessage = 'routing_voice_cmd'.tr();
    });

    final lang = context.locale.languageCode;

    try {
      final res = await _apiClient.post(
        '/api/v1/assistant/chat',
        body: {
          'message': query,
          'current_screen': widget.currentScreen,
          'app_language': lang,
        },
      );

      final chatRes = KalaMitraResponse.fromJson(res);
      final reply = chatRes.reply;
      final action = chatRes.action;
      final route = chatRes.route;
      final targetLang = chatRes.targetLang;

      if (!mounted) return;

      // Speak confirmation
      await VoiceService.instance.speak(text: reply, languageCode: lang);
      if (!mounted) return;

      // Handle navigation actions
      if (action == 'navigate' && route != null && route.isNotEmpty) {
        Navigator.of(context).pop();
        if (route.startsWith('/studio') || route.startsWith('/add')) {
          if (StorageService.isSimpleMode) {
            context.push('/add/simple');
          } else {
            context.push(RouteNames.addStudio);
          }
        } else if (route.contains('/earnings')) {
          context.push('/earnings');
        } else if (route.contains('/fair-mode')) {
          context.push('/fair-mode');
        } else if (route.contains('/business')) {
          context.push('/orders/business');
        } else if (route.contains('/marketplaces')) {
          context.push('/marketplaces');
        } else if (route.contains('/orders')) {
          context.go('${RouteNames.home}?tab=2');
        } else {
          context.push(route);
        }
        return;
      }

      if (action == 'change_language' && targetLang != null) {
        final newLocale = Locale(targetLang);
        await context.setLocale(newLocale);
        await StorageService.saveLocale(newLocale);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      setState(() {
        _isProcessing = false;
        _feedbackMessage = reply;
      });
    } catch (_) {
      // Local keyword fallback if offline
      _handleOfflineKeywordRouting(query);
    }
  }

  void _handleOfflineKeywordRouting(String query) {
    final lower = query.toLowerCase();
    Navigator.of(context).pop();

    if (lower.contains('add') || lower.contains('photo') || lower.contains('craft') || lower.contains('उत्पाद') || lower.contains('படம்')) {
      if (StorageService.isSimpleMode) {
        context.push('/add/simple');
      } else {
        context.push(RouteNames.addStudio);
      }
    } else if (lower.contains('earning') || lower.contains('income') || lower.contains('कमाई') || lower.contains('வருமானம்')) {
      context.push('/earnings');
    } else if (lower.contains('fair') || lower.contains('mela') || lower.contains('मेला') || lower.contains('கண்காட்சி')) {
      context.push('/fair-mode');
    } else if (lower.contains('business') || lower.contains('bulk') || lower.contains('थोक')) {
      context.push('/orders/business');
    } else if (lower.contains('marketplace') || lower.contains('gem') || lower.contains('ondc')) {
      context.push('/marketplaces');
    } else {
      context.go('${RouteNames.home}?tab=2');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Header title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'voice_command_title'.tr(),
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.inkSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                _feedbackMessage ?? 'voice_command_hint'.tr(),
                style: AppTextStyles.bodyMedium(
                  color: _isListening ? AppColors.primary : AppColors.inkPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_recognizedText != null) ...[
              const SizedBox(height: 8),
              Text(
                '“$_recognizedText”',
                style: AppTextStyles.titleSmall(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),

            // Giant Microphone Button (76 dp)
            GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopVoiceListeningAndSend();
                } else if (!_isProcessing) {
                  _startVoiceListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isListening ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.craftTerracotta : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppColors.craftTerracotta : AppColors.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: _isListening ? 4 : 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                            : Icon(
                                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? 'tap_to_stop'.tr() : 'tap_to_speak'.tr(),
              style: AppTextStyles.labelMedium(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 24),

            // Quick suggestion chips
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'or_tap_command'.tr(),
                style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickCommands.map((cmd) {
                return ActionChip(
                  avatar: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    cmd['labelKey']!.tr(),
                    style: AppTextStyles.labelMedium(color: AppColors.inkPrimary),
                  ),
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
                  onPressed: () => _executeCommand(cmd['query']!),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
