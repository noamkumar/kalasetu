import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/services/audio_recording_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/image_compare_slider.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/api/api_client.dart';
import 'models/image_edit_models.dart';
import 'services/image_editor_service.dart';

/// KalaSetu Photo Editor Screen
/// Interactive photo editor with before/after comparison slider,
/// big mic button ("Tell me what to change"), typed command input,
/// big touch-target icon buttons for common edits (remove bg, change color,
/// brighter, shadow, zoom, auto enhance, rotate), non-destructive undo/redo/reset,
/// and audible + visible feedback confirmations.
class PhotoEditorScreen extends StatefulWidget {
  final String imageId;
  final String originalUrl;
  final String? initialEditedUrl;
  final ValueChanged<String>? onSave;

  const PhotoEditorScreen({
    super.key,
    required this.imageId,
    required this.originalUrl,
    this.initialEditedUrl,
    this.onSave,
  });

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final ImageEditorService _editorService = ImageEditorService();
  final AudioRecordingService _audioService = AudioRecordingService();
  final TextEditingController _commandController = TextEditingController();

  late String _currentEditedUrl;
  int _imageVersion = DateTime.now().millisecondsSinceEpoch;
  bool _canUndo = false;
  bool _canRedo = false;
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _shadowOn = true;

  String? _feedbackMessage;
  String? _clarificationQuestion;
  String? _errorMessage;
  VoidCallback? _pendingRetryAction;

  void _handleEditError(String errorMsg, VoidCallback retryAction) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = errorMsg;
      _pendingRetryAction = retryAction;
    });
    _speakFeedback(errorMsg);
  }

  @override
  void initState() {
    super.initState();
    _currentEditedUrl = widget.initialEditedUrl ?? widget.originalUrl;
  }

  @override
  void dispose() {
    _commandController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Widget _buildImageWidget(String path) {
    if (path.isEmpty) {
      return Container(color: AppColors.surface);
    }
    final resolved = ApiClient().resolveMediaUrl(path);
    if (path.startsWith('http') || path.startsWith('/static')) {
      final cacheBusted = resolved.contains('?')
          ? '$resolved&t=$_imageVersion'
          : '$resolved?t=$_imageVersion';
      return Image.network(
        cacheBusted,
        key: ValueKey(cacheBusted),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
        ),
      );
    }
    return Image.file(
      File(path),
      key: ValueKey('$path-$_imageVersion'),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
      ),
    );
  }

  void _speakFeedback(String message) {
    if (message.isEmpty) return;
    try {
      final lang = context.locale.languageCode;
      VoiceService.instance.speak(text: message, languageCode: lang);
    } catch (_) {}
  }

  Future<void> _applyAction(String action) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final res = await _editorService.editImage(
        imageId: widget.imageId,
        action: action,
      );

      if (res.status == 'error' || res.imageUrl.isEmpty) {
        _handleEditError('photo_edit_failed_spoken'.tr(), () => _applyAction(action));
        return;
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = null;
          _pendingRetryAction = null;
          if (res.imageUrl.isNotEmpty) {
            _currentEditedUrl = res.imageUrl;
            _imageVersion = DateTime.now().millisecondsSinceEpoch;
            PaintingBinding.instance.imageCache.clear();
          }
          _canUndo = res.canUndo;
          _canRedo = res.canRedo;
          if (action == 'undo') {
            _feedbackMessage = 'btn_undo'.tr();
          } else if (action == 'redo') {
            _feedbackMessage = 'btn_redo'.tr();
          } else if (action == 'reset') {
            _feedbackMessage = 'btn_reset'.tr();
          }
        });
        if (_feedbackMessage != null) {
          _speakFeedback(_feedbackMessage!);
        }
      }
    } catch (e) {
      _handleEditError('photo_edit_failed_spoken'.tr(), () => _applyAction(action));
    }
  }

  Future<void> _applyOperation(EditOperation op, {String? feedback}) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final res = await _editorService.editImage(
        imageId: widget.imageId,
        operations: [op],
        action: 'apply',
      );

      if (res.status == 'error' || res.imageUrl.isEmpty) {
        _handleEditError('photo_edit_failed_spoken'.tr(), () => _applyOperation(op, feedback: feedback));
        return;
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = null;
          _pendingRetryAction = null;
          if (res.imageUrl.isNotEmpty) {
            _currentEditedUrl = res.imageUrl;
            _imageVersion = DateTime.now().millisecondsSinceEpoch;
            PaintingBinding.instance.imageCache.clear();
          }
          _canUndo = res.canUndo;
          _canRedo = res.canRedo;
          _feedbackMessage = feedback ?? 'applied_feedback_title'.tr();
        });
        if (_feedbackMessage != null) {
          _speakFeedback(_feedbackMessage!);
        }
      }
    } catch (e) {
      _handleEditError('photo_edit_failed_spoken'.tr(), () => _applyOperation(op, feedback: feedback));
    }
  }

  Future<void> _submitTypedCommand() async {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    _commandController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _clarificationQuestion = null;
    });

    try {
      final res = await _editorService.sendVoiceCommand(
        imageId: widget.imageId,
        text: text,
        lang: context.locale.languageCode,
      );

      if (res.status == 'error' || res.imageUrl == null || res.imageUrl!.isEmpty) {
        _handleEditError('photo_edit_failed_spoken'.tr(), () {
          _commandController.text = text;
          _submitTypedCommand();
        });
        return;
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = null;
          _pendingRetryAction = null;
          if (res.imageUrl != null && res.imageUrl!.isNotEmpty) {
            _currentEditedUrl = res.imageUrl!;
            _imageVersion = DateTime.now().millisecondsSinceEpoch;
            PaintingBinding.instance.imageCache.clear();
          }
          _canUndo = res.canUndo;
          _canRedo = res.canRedo;
          if (res.clarificationNeeded) {
            _clarificationQuestion = res.clarifyingQuestion ?? res.confirmation;
            _feedbackMessage = null;
          } else {
            _feedbackMessage = res.confirmation;
          }
        });

        if (res.clarificationNeeded) {
          _speakFeedback(_clarificationQuestion ?? '');
        } else if (_feedbackMessage != null) {
          _speakFeedback(_feedbackMessage!);
        }
      }
    } catch (e) {
      _handleEditError('photo_edit_failed_spoken'.tr(), () {
        _commandController.text = text;
        _submitTypedCommand();
      });
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      // Stop recording and send command
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _errorMessage = null;
        _clarificationQuestion = null;
      });

      final lang = context.locale.languageCode;
      final recordedPath = await _audioService.stopRecording();
      if (recordedPath == null || !File(recordedPath).existsSync()) {
        setState(() => _isProcessing = false);
        return;
      }

      try {
        final res = await _editorService.sendVoiceCommand(
          imageId: widget.imageId,
          audioFilePath: recordedPath,
          lang: lang,
        );

        if (res.status == 'error' || res.imageUrl == null || res.imageUrl!.isEmpty) {
          _handleEditError('photo_edit_failed_spoken'.tr(), () => _toggleVoiceRecording());
          return;
        }

        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = null;
            _pendingRetryAction = null;
            if (res.imageUrl != null && res.imageUrl!.isNotEmpty) {
              _currentEditedUrl = res.imageUrl!;
              _imageVersion = DateTime.now().millisecondsSinceEpoch;
              PaintingBinding.instance.imageCache.clear();
            }
            _canUndo = res.canUndo;
            _canRedo = res.canRedo;
            if (res.clarificationNeeded) {
              _clarificationQuestion = res.clarifyingQuestion ?? res.confirmation;
              _feedbackMessage = null;
            } else {
              _feedbackMessage = res.confirmation;
            }
          });

          if (res.clarificationNeeded) {
            _speakFeedback(_clarificationQuestion ?? '');
          } else if (_feedbackMessage != null) {
            _speakFeedback(_feedbackMessage!);
          }
        }
      } catch (e) {
        _handleEditError('photo_edit_failed_spoken'.tr(), () => _toggleVoiceRecording());
      } finally {
        await AudioRecordingService.deleteAudioFile(recordedPath);
      }
    } else {
      // Start recording
      final hasPerm = await _audioService.hasPermission();
      if (!hasPerm) {
        setState(() => _errorMessage = 'mic_permission_denied'.tr());
        return;
      }
      final path = await _audioService.startRecording();
      if (path != null) {
        setState(() {
          _isRecording = true;
          _feedbackMessage = null;
          _clarificationQuestion = null;
          _errorMessage = null;
        });
      }
    }
  }

  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'tool_change_bg'.tr(),
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.inkSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBgChoiceChip(ctx, 'bg_choice_white'.tr(), 'white', const Color(0xFFFFFFFF)),
                _buildBgChoiceChip(ctx, 'bg_choice_linen'.tr(), 'linen', const Color(0xFFFAF6F0)),
                _buildBgChoiceChip(ctx, 'bg_choice_blue'.tr(), 'blue', const Color(0xFF2980B9)),
                _buildBgChoiceChip(ctx, 'bg_choice_gradient'.tr(), 'soft gradient', const Color(0xFFE8ECE4)),
                _buildBgChoiceChip(ctx, 'bg_choice_blur'.tr(), 'blur', const Color(0xFFBDC3C7)),
                _buildBgChoiceChip(ctx, 'bg_choice_textured'.tr(), 'textured', const Color(0xFFD7CCC8)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBgChoiceChip(BuildContext ctx, String label, String styleKey, Color previewColor) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _applyOperation(
          EditOperation(type: 'replace_background', value: styleKey),
          feedback: '$label ${'tool_change_bg'.tr()}',
        );
      },
      borderRadius: AppRadii.pillRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: previewColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary)),
          ],
        ),
      ),
    );
  }

  void _saveAndExit() {
    if (widget.onSave != null) {
      widget.onSave!(_currentEditedUrl);
    }
    Navigator.of(context).pop(_currentEditedUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'photo_editor_title'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Undo Button
          IconButton(
            tooltip: 'btn_undo'.tr(),
            icon: Icon(
              Icons.undo,
              color: _canUndo ? AppColors.inkPrimary : AppColors.hairline,
            ),
            onPressed: _canUndo ? () => _applyAction('undo') : null,
          ),
          // Redo Button
          IconButton(
            tooltip: 'btn_redo'.tr(),
            icon: Icon(
              Icons.redo,
              color: _canRedo ? AppColors.inkPrimary : AppColors.hairline,
            ),
            onPressed: _canRedo ? () => _applyAction('redo') : null,
          ),
          // Reset Button
          IconButton(
            tooltip: 'btn_reset'.tr(),
            icon: const Icon(Icons.restart_alt, color: AppColors.inkPrimary),
            onPressed: () => _applyAction('reset'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Before / After Comparison Slider
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ImageCompareSlider(
                        beforeWidget: _buildImageWidget(widget.originalUrl),
                        afterWidget: _buildImageWidget(_currentEditedUrl),
                        height: 320,
                        beforeLabel: 'slider_before'.tr(),
                        afterLabel: 'slider_after'.tr(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Audible & Visible Feedback Banner
                    if (_feedbackMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                              ),
                            ),
                            SpeakerAffordance(textToSpeak: _feedbackMessage!, isCompact: true),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.inkSecondary),
                              onPressed: () => setState(() => _feedbackMessage = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 3. Clarification Question Banner
                    if (_clarificationQuestion != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.secondary),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.help_outline, color: AppColors.secondary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'clarification_needed_title'.tr(),
                                  style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                                ),
                                const Spacer(),
                                SpeakerAffordance(textToSpeak: _clarificationQuestion!, isCompact: true),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _clarificationQuestion!,
                              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 4. Processing / Loading State
                    if (_isProcessing) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'voice_edit_processing'.tr(),
                              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 5. Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.statusError.withValues(alpha: 0.1),
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.statusError),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.statusError, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodyMedium(color: AppColors.statusError),
                              ),
                            ),
                            if (_pendingRetryAction != null) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusError,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                                ),
                                onPressed: () {
                                  final act = _pendingRetryAction;
                                  setState(() {
                                    _errorMessage = null;
                                    _pendingRetryAction = null;
                                  });
                                  act?.call();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: Text('try_again_btn'.tr()),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 6. Big Mic Button ("Tell me what to change")
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleVoiceRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: _isRecording ? AppColors.statusError : AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRecording ? AppColors.statusError : AppColors.primary)
                                        .withValues(alpha: 0.35),
                                    blurRadius: _isRecording ? 18 : 10,
                                    spreadRadius: _isRecording ? 4 : 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRecording ? 'voice_edit_listening'.tr() : 'voice_edit_mic_btn'.tr(),
                            style: AppTextStyles.labelLarge(
                              color: _isRecording ? AppColors.statusError : AppColors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 7. Typed Commands Input Field
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.pillRadius,
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: TextField(
                              controller: _commandController,
                              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                              decoration: InputDecoration(
                                hintText: 'type_command_hint'.tr(),
                                hintStyle: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (_) => _submitTypedCommand(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_upward, color: Colors.white),
                            onPressed: _submitTypedCommand,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 8. Big Icon Buttons for Common Edits (>=48dp touch targets)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickToolButton(
                            icon: Icons.layers_clear,
                            label: 'tool_remove_bg'.tr(),
                            onTap: () => _applyOperation(
                              const EditOperation(type: 'remove_background', value: true),
                              feedback: 'tool_remove_bg'.tr(),
                            ),
                          ),
                          _buildQuickToolButton(
                            icon: Icons.palette_outlined,
                            label: 'tool_change_bg'.tr(),
                            onTap: _showBackgroundPicker,
                          ),
                          _buildQuickToolButton(
                            icon: Icons.wb_sunny_outlined,
                            label: 'tool_brighter'.tr(),
                            onTap: () => _applyOperation(
                              const EditOperation(type: 'brightness', value: 1.25),
                              feedback: 'tool_brighter'.tr(),
                            ),
                          ),
                          _buildQuickToolButton(
                            icon: _shadowOn ? Icons.tonality : Icons.radio_button_unchecked,
                            label: 'tool_shadow'.tr(),
                            onTap: () {
                              final next = !_shadowOn;
                              setState(() => _shadowOn = next);
                              _applyOperation(
                                EditOperation(type: 'shadow', value: next),
                                feedback: '${'tool_shadow'.tr()}: ${next ? "On" : "Off"}',
                              );
                            },
                          ),
                          _buildQuickToolButton(
                            icon: Icons.zoom_in,
                            label: 'tool_zoom'.tr(),
                            onTap: () => _applyOperation(
                              const EditOperation(type: 'product_size', value: 0.88),
                              feedback: 'tool_zoom'.tr(),
                            ),
                          ),
                          _buildQuickToolButton(
                            icon: Icons.auto_fix_high,
                            label: 'tool_auto_enhance'.tr(),
                            onTap: () => _applyOperation(
                              const EditOperation(type: 'auto_enhance', value: true),
                              feedback: 'tool_auto_enhance'.tr(),
                            ),
                          ),
                          _buildQuickToolButton(
                            icon: Icons.rotate_right,
                            label: 'tool_rotate'.tr(),
                            onTap: () => _applyOperation(
                              const EditOperation(type: 'rotate', value: 90),
                              feedback: 'tool_rotate'.tr(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 9. Sticky Save & Continue Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: AppButton(
                label: 'btn_save_photo'.tr(),
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.check, color: Colors.white, size: 20),
                isFullWidth: true,
                onPressed: _saveAndExit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          constraints: const BoxConstraints(minWidth: 80, minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
