import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/catalog_repository.dart';
import '../studio/services/image_editor_service.dart';
import 'services/kalamitra_service.dart';

class KalaMitraBottomSheet extends StatefulWidget {
  final String currentScreen;
  final Function(int tabIndex)? onSwitchTab;

  const KalaMitraBottomSheet({
    super.key,
    this.currentScreen = 'home',
    this.onSwitchTab,
  });

  static Future<void> show(BuildContext context, {String currentScreen = 'home', Function(int)? onSwitchTab}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => KalaMitraBottomSheet(
        currentScreen: currentScreen,
        onSwitchTab: onSwitchTab,
      ),
    );
  }

  @override
  State<KalaMitraBottomSheet> createState() => _KalaMitraBottomSheetState();
}

class _KalaMitraBottomSheetState extends State<KalaMitraBottomSheet> {
  final KalaMitraService _assistantService = KalaMitraService();
  final AudioRecordingService _audioService = AudioRecordingService();
  final CatalogRepository _catalogRepo = CatalogRepository();
  final ImageEditorService _imageEditorService = ImageEditorService();
  final VoiceService _voiceService = VoiceService.instance;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isUploadingImage = false;
  bool _speechReviewActive = false;
  String? _recognizedPendingText;
  String? _currentlySpeaking;

  // Active attached image state for photo studio / conversational editing
  String? _activeImageId;
  String? _activeImageUrl;
  String? _activeOriginalUrl;

  // Selected language for speech & requests (defaults to 'auto')
  String _selectedLang = 'auto';

  final List<Map<String, dynamic>> _messages = [];
  List<String> _suggestions = [];

  final List<Map<String, String>> _availableLangs = [
    {'code': 'auto', 'label': 'kalamitra_lang_auto'},
    {'code': 'en', 'label': 'English'},
    {'code': 'te', 'label': 'తెలుగు'},
    {'code': 'ta', 'label': 'தமிழ்'},
    {'code': 'kn', 'label': 'ಕನ್ನಡ'},
    {'code': 'ml', 'label': 'മലയാളം'},
    {'code': 'hi', 'label': 'हिन्दी'},
  ];

  @override
  void initState() {
    super.initState();
    _voiceService.addListener(_onVoiceServiceStateChanged);
    _suggestions = [
      'kalamitra_sug_add'.tr(),
      'kalamitra_sug_orders'.tr(),
      'kalamitra_sug_lang'.tr(),
      'kalamitra_sug_explain'.tr(),
    ];
    // Initial greeting from KalaMitra
    _messages.add({
      'isUser': false,
      'text': 'kalamitra_greeting'.tr(),
    });
  }

  void _onVoiceServiceStateChanged() {
    if (mounted) {
      setState(() {
        if (!_voiceService.isPlaying && !_voiceService.isGenerating) {
          _currentlySpeaking = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceServiceStateChanged);
    _textController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _handleUserMessage(String query, [int? userActionStartMs]) async {
    final text = query.trim();
    if (text.isEmpty) return;
    final startMs = userActionStartMs ?? DateTime.now().millisecondsSinceEpoch;

    // Reset pending speech review state
    _speechReviewActive = false;
    _recognizedPendingText = null;

    // Collect conversation history for multi-turn context before adding current turn
    final historyList = <Map<String, String>>[];
    for (final m in _messages) {
      final isUser = m['isUser'] == true;
      final msgText = m['text']?.toString() ?? '';
      if (msgText.isNotEmpty) {
        historyList.add({
          'role': isUser ? 'user' : 'assistant',
          'content': msgText,
        });
      }
    }

    _textController.clear();
    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'imageId': _activeImageId,
      });
      _isProcessing = true;
    });
    _scrollToBottom();

    final requestLang = _selectedLang == 'auto' ? context.locale.languageCode : _selectedLang;
    final llmSw = Stopwatch()..start();
    final response = await _assistantService.sendMessage(
      message: text,
      currentScreen: widget.currentScreen,
      language: requestLang,
      history: historyList,
      imageId: _activeImageId,
    );
    final llmLatency = llmSw.elapsedMilliseconds;
    debugPrint('[KalaMitra LATENCY] LLM latency: ${llmLatency}ms');

    if (!mounted) return;

    if (response.imageUrl != null && response.imageUrl!.isNotEmpty) {
      _activeImageUrl = response.imageUrl;
      if (response.imageId != null && response.imageId!.isNotEmpty) {
        _activeImageId = response.imageId;
      }
    }

    setState(() {
      _isProcessing = false;
      _messages.add({
        'isUser': false,
        'text': response.reply,
        'action': response.action,
        'route': response.route,
        'targetLang': response.targetLang,
        'imageUrl': response.imageUrl,
        'imageId': response.imageId ?? _activeImageId,
        'originalUrl': _activeOriginalUrl,
        'canUndo': response.canUndo,
        'canRedo': response.canRedo,
      });
      if (response.suggestions.isNotEmpty) {
        _suggestions = response.suggestions;
      }
    });
    _scrollToBottom();

    // Auto-execute language change if requested
    if (response.action == 'change_language' && response.targetLang != null) {
      final code = response.targetLang!;
      final newLocale = Locale(code);
      await context.setLocale(newLocale);
      await StorageService.saveLocale(newLocale);
      _voiceService.prefetchFixedPhrases(code);
    }

    // Auto-speak reply with end-to-end latency measurement
    _handleSpeak(response.reply, startMs);
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isListening) {
      // Stop recording and transcribe
      setState(() {
        _isListening = false;
        _isProcessing = true;
      });

      final audioPath = await _audioService.stopRecording();
      if (audioPath != null) {
        try {
          final langHint = _selectedLang == 'auto' ? (mounted ? context.locale.languageCode : 'en') : _selectedLang;
          final sttSw = Stopwatch()..start();
          final res = await _catalogRepo.transcribeAudio(
            filePath: audioPath,
            languageHint: langHint,
          );
          final sttLatency = sttSw.elapsedMilliseconds;
          debugPrint('[KalaMitra LATENCY] STT latency: ${sttLatency}ms');

          final spoken = res.text.trim();
          if (spoken.isNotEmpty) {
            _textController.text = spoken;
            _textController.selection = TextSelection.fromPosition(TextPosition(offset: spoken.length));
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _speechReviewActive = true;
                _recognizedPendingText = spoken;
              });
            }
          } else {
            if (mounted) setState(() => _isProcessing = false);
          }
        } catch (_) {
          // If transcription fails, ask gently
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _messages.add({
                'isUser': false,
                'text': 'kalamitra_transcribe_error'.tr(),
              });
            });
          }
        } finally {
          await AudioRecordingService.deleteAudioFile(audioPath);
        }
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      // Start recording
      final hasPerm = await _audioService.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('mic_permission_denied'.tr()),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
        return;
      }

      final path = await _audioService.startRecording();
      if (path != null && mounted) {
        setState(() {
          _isListening = true;
          _speechReviewActive = false;
          _recognizedPendingText = null;
        });
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (_isListening) {
      await _audioService.cancelRecording();
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final up = await _imageEditorService.uploadProductImage(picked.path);
      final imgId = up['image_id']?.toString() ?? '';
      final origUrl = up['original_url']?.toString() ?? '';

      final requestLang = _selectedLang == 'auto'
          ? (mounted ? context.locale.languageCode : 'en')
          : _selectedLang;

      final editRes = await _imageEditorService.editImage(
        imageId: imgId,
        prompt: 'remove background and make background clean white',
        lang: requestLang,
      );

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _activeImageId = imgId;
          _activeImageUrl = editRes.imageUrl.isNotEmpty ? editRes.imageUrl : origUrl;
          _activeOriginalUrl = origUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error'.tr()),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    }
  }

  void _handleSpeak(String text, [int? startTimestamp]) {
    final langCode = _selectedLang == 'auto' ? context.locale.languageCode : _selectedLang;
    if (_currentlySpeaking == text) {
      _voiceService.stop();
      setState(() => _currentlySpeaking = null);
    } else {
      _voiceService.speak(
        text: text,
        languageCode: langCode,
        onStart: () {
          if (mounted) setState(() => _currentlySpeaking = text);
          if (startTimestamp != null) {
            final elapsed = DateTime.now().millisecondsSinceEpoch - startTimestamp;
            debugPrint('[KalaMitra LATENCY] Total time-to-first-audio: ${elapsed}ms');
          }
        },
        onComplete: () {
          if (mounted) setState(() => _currentlySpeaking = null);
        },
      );
    }
  }

  void _handleActionTap(Map<String, dynamic> msg) {
    final action = msg['action'] as String?;
    final route = msg['route'] as String?;

    if (action == 'navigate' && route != null) {
      Navigator.of(context).pop();
      if (route.contains('/orders')) {
        widget.onSwitchTab?.call(2);
      } else if (route.contains('/studio')) {
        context.push(RouteNames.addStudio);
      } else {
        context.push(route);
      }
    }
  }

  void _openImageInStudio(Map<String, dynamic> msg) {
    final imageId = msg['imageId']?.toString() ?? _activeImageId;
    final imageUrl = msg['imageUrl']?.toString() ?? _activeImageUrl;
    final originalUrl = msg['originalUrl']?.toString() ?? _activeOriginalUrl ?? imageUrl;

    if (imageId != null && imageUrl != null) {
      Navigator.of(context).pop();
      context.push(
        RouteNames.photoEditor,
        extra: {
          'image_id': imageId,
          'original_url': originalUrl,
          'initial_edited_url': imageUrl,
        },
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildImageWidget(String path) {
    if (path.isEmpty) return const SizedBox.shrink();
    final resolved = ApiClient().resolveMediaUrl(path);
    if (path.startsWith('http') || path.startsWith('/static')) {
      return Image.network(
        resolved,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Header with Language Picker and Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accentBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'kalamitra_title'.tr(),
                          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                        ),
                        Text(
                          'kalamitra_subtitle'.tr().replaceAll('{0}', widget.currentScreen).replaceAll('{screen}', widget.currentScreen),
                          style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Language selector dropdown chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLang,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.inkPrimary),
                        style: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                        items: _availableLangs.map((l) {
                          final label = l['code'] == 'auto' ? l['label']!.tr() : l['label']!;
                          return DropdownMenuItem<String>(
                            value: l['code'],
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLang = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.inkSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 12, color: AppColors.hairline),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  final isUser = msg['isUser'] == true;
                  final text = msg['text'] as String;
                  final action = msg['action'] as String?;
                  final imageUrl = msg['imageUrl'] as String?;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(18).copyWith(
                          bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(18),
                          bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(18),
                        ),
                        border: isUser ? null : Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  text,
                                  style: AppTextStyles.bodyMedium(
                                    color: isUser ? Colors.white : AppColors.inkPrimary,
                                  ),
                                ),
                              ),
                              if (!isUser) ...[
                                const SizedBox(width: 8),
                                SpeakerAffordance(
                                  isCompact: true,
                                  isPlaying: _currentlySpeaking == text,
                                  onTap: () => _handleSpeak(text),
                                ),
                              ],
                            ],
                          ),

                          // Image Studio Result Card
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                color: Colors.white,
                                child: _buildImageWidget(imageUrl),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Quick editing actions
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ActionChip(
                                  label: Text('bg_choice_white'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(color: AppColors.hairline),
                                  onPressed: () => _handleUserMessage('Make the background pure white'),
                                ),
                                ActionChip(
                                  label: Text('kalamitra_action_wood_table'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(color: AppColors.hairline),
                                  onPressed: () => _handleUserMessage('Put product on wooden table'),
                                ),
                                ActionChip(
                                  label: Text('kalamitra_action_studio'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(color: AppColors.hairline),
                                  onPressed: () => _handleUserMessage('Create studio background'),
                                ),
                                ActionChip(
                                  label: Text('tool_brighter'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(color: AppColors.hairline),
                                  onPressed: () => _handleUserMessage('Make it brighter'),
                                ),
                                if (msg['canUndo'] == true)
                                  ActionChip(
                                    label: Text('btn_undo'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                                    backgroundColor: AppColors.surface,
                                    side: const BorderSide(color: AppColors.hairline),
                                    onPressed: () => _handleUserMessage('undo'),
                                  ),
                                ActionChip(
                                  avatar: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                                  label: Text('kalamitra_open_studio'.tr(), style: AppTextStyles.labelSmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
                                  backgroundColor: AppColors.primaryLight,
                                  side: BorderSide.none,
                                  onPressed: () => _openImageInStudio(msg),
                                ),
                              ],
                            ),
                          ],

                          if (action == 'navigate' && msg['route'] != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: Text('kalamitra_go_to_btn'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _handleActionTap(msg),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Processing indicator
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kalamitra_thinking'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),

            // Listening indicator with Cancel button
            if (_isListening)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.statusError.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.statusError.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, size: 16, color: AppColors.statusError),
                    const SizedBox(width: 6),
                    Text(
                      'kalamitra_listening_hint'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.statusError).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _cancelVoiceRecording,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusError,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'kalamitra_cancel_recording'.tr(),
                          style: AppTextStyles.labelSmall(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Image uploading indicator
            if (_isUploadingImage)
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kalamitra_uploading_photo'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),

            // Speech review affordance banner
            if (_speechReviewActive && _recognizedPendingText != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.accentBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'kalamitra_review_hint'.tr(),
                        style: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _handleUserMessage(_textController.text),
                      child: Text('continue_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentBlue)),
                    ),
                  ],
                ),
              ),

            // Attached product photo preview chip
            if (_activeImageUrl != null && _activeImageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: _buildImageWidget(_activeImageUrl!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'kalamitra_attached_photo'.tr(),
                        style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primaryDark),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _activeImageId = null;
                          _activeImageUrl = null;
                          _activeOriginalUrl = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Voice generation or speaking indicator
            if (_voiceService.isGenerating)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generating voice...',
                      style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        _voiceService.stop();
                        setState(() => _currentlySpeaking = null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Stop',
                          style: AppTextStyles.labelSmall(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_voiceService.isPlaying || _currentlySpeaking != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Speaking...',
                      style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        _voiceService.stop();
                        setState(() => _currentlySpeaking = null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Stop',
                          style: AppTextStyles.labelSmall(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick suggestion chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _suggestions.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(s, style: AppTextStyles.labelSmall(color: AppColors.inkPrimary)),
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.hairline),
                      onPressed: () => _handleUserMessage(s),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Bottom Input & Voice Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Row(
                children: [
                  // Image attachment popup menu
                  PopupMenuButton<ImageSource>(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 24),
                    tooltip: 'kalamitra_attach_photo'.tr(),
                    onSelected: _pickImage,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: ImageSource.camera,
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.inkPrimary),
                            const SizedBox(width: 10),
                            Text('step_capture'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: ImageSource.gallery,
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.inkPrimary),
                            const SizedBox(width: 10),
                            Text('tab_catalogue'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                      decoration: InputDecoration(
                        hintText: 'kalamitra_input_hint'.tr(),
                        hintStyle: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _handleUserMessage,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Text Button
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: () => _handleUserMessage(_textController.text),
                  ),

                  // Big Voice Mic Button
                  GestureDetector(
                    onTap: _toggleVoiceRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.statusError : AppColors.accentBlue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? AppColors.statusError : AppColors.accentBlue).withValues(alpha: 0.35),
                            blurRadius: _isListening ? 14 : 6,
                            spreadRadius: _isListening ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
