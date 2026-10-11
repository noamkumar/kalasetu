import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/developer_log_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../data/api/api_client.dart';

class DeveloperSettingsDialog extends StatefulWidget {
  const DeveloperSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const DeveloperSettingsDialog(),
    );
  }

  @override
  State<DeveloperSettingsDialog> createState() => _DeveloperSettingsDialogState();
}

class _DeveloperSettingsDialogState extends State<DeveloperSettingsDialog> {
  late final TextEditingController _controller;
  final ApiClient _apiClient = ApiClient();

  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final current = StorageService.serverBaseUrl.isNotEmpty
        ? StorageService.serverBaseUrl
        : _apiClient.baseUrl;
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    final candidate = _controller.text.trim();
    if (candidate.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
    });

    try {
      final info = await _apiClient.testConnection(candidate);
      if (!mounted) return;
      final aiMode = info['ai_mode'] ?? 'unknown';
      final version = info['version'] ?? '1.0.0';
      final appName = info['app'] ?? 'KalaSetu';
      final isKeyConfigured = info['key_configured'] == true || info['gemini_key_configured'] == true;
      setState(() {
        _isTesting = false;
        _testSuccess = true;
        _testMessage = '${'server_connected_friendly'.tr()}: $appName v$version (AI mode: $aiMode, Gemini: ${isKeyConfigured ? "configured" : "mock"})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _handleSave() async {
    final candidate = _controller.text.trim();
    if (candidate.isNotEmpty) {
      await StorageService.setServerBaseUrl(candidate);
    } else {
      await StorageService.clearServerBaseUrl();
    }
    ConnectivityService.instance.checkConnectivity();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('server_connected_success'.tr()),
        backgroundColor: AppColors.statusOnline,
      ),
    );
  }

  Future<void> _handleReset() async {
    await StorageService.clearServerBaseUrl();
    ConnectivityService.instance.checkConnectivity();
    setState(() {
      _controller.text = ApiClient.defaultBaseUrl;
      _testMessage = null;
      _testSuccess = null;
    });
  }

  void _applyPreset(String preset) {
    setState(() {
      _controller.text = preset;
      _testMessage = null;
      _testSuccess = null;
    });
  }

  Widget _buildTroubleshootingChecklist() {
    final checklistItems = [
      'checklist_wifi'.tr(),
      'checklist_server'.tr(),
      'checklist_firewall'.tr(),
      'checklist_ip'.tr(),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 18, color: AppColors.craftOchre),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'checklist_title'.tr(),
                  style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in checklistItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_box_outline_blank_rounded, size: 16, color: AppColors.craftOchre),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLastErrorView() {
    return ValueListenableBuilder<DeveloperErrorInfo?>(
      valueListenable: DeveloperLogService.lastErrorNotifier,
      builder: (context, errorInfo, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_outlined, size: 18, color: AppColors.statusError),
                      const SizedBox(width: 8),
                      Text(
                        'dev_last_error_title'.tr(),
                        style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (errorInfo != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => DeveloperLogService.clearLastError(),
                      child: Text(
                        'dev_clear_error'.tr(),
                        style: AppTextStyles.labelSmall(color: AppColors.statusError),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (errorInfo == null)
                Text(
                  'dev_no_last_error'.tr(),
                  style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.statusError.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${errorInfo.statusCode != null ? "HTTP ${errorInfo.statusCode}" : "NETWORK FAIL"} • ${errorInfo.method} ${errorInfo.url}',
                        style: AppTextStyles.labelSmall(color: AppColors.statusError).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${errorInfo.errorType} | Time: ${errorInfo.timestamp.toIso8601String().substring(11, 19)}',
                        style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                      ),
                      if (errorInfo.modelName != null && errorInfo.modelName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.psychology_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Model: ${errorInfo.modelName} ${errorInfo.geminiStatus != null ? "(${errorInfo.geminiStatus})" : ""}',
                                style: AppTextStyles.labelSmall(color: AppColors.primary).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (errorInfo.hint != null && errorInfo.hint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.craftOchre.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.craftOchre.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.craftOchre),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Hint: ${errorInfo.hint}',
                                  style: AppTextStyles.bodySmall(color: AppColors.inkPrimary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (errorInfo.responseBody != null && errorInfo.responseBody!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Body: ${errorInfo.responseBody}',
                          style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (errorInfo.rawError != null && errorInfo.rawError!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Detail: ${errorInfo.rawError}',
                          style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.developer_mode_rounded, color: AppColors.craftOchre, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'developer_settings_title'.tr(),
                    style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.inkSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'developer_settings_desc'.tr(),
              style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 16),

            // Server Address label & TextField
            Text(
              'server_address'.tr(),
              style: AppTextStyles.labelMedium(color: AppColors.inkPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
              decoration: InputDecoration(
                hintText: 'server_url_hint'.tr(),
                hintStyle: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                prefixIcon: const Icon(Icons.lan_outlined, color: AppColors.inkSecondary, size: 20),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick presets
            Text(
              'Quick Presets',
              style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi PC (10.124.188.51)'),
                  labelStyle: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                  backgroundColor: AppColors.background,
                  onPressed: () => _applyPreset('http://10.124.188.51:8000/api/v1'),
                ),
                ActionChip(
                  label: const Text('Localhost (ADB Reverse)'),
                  labelStyle: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                  backgroundColor: AppColors.background,
                  onPressed: () => _applyPreset('http://127.0.0.1:8000/api/v1'),
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)'),
                  labelStyle: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                  backgroundColor: AppColors.background,
                  onPressed: () => _applyPreset('http://10.0.2.2:8000/api/v1'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Developer Mode Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppColors.craftOchre, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'dev_mode_label'.tr(),
                          style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'dev_mode_desc'.tr(),
                          style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: StorageService.isDeveloperMode,
                    activeColor: AppColors.craftOchre,
                    onChanged: (val) async {
                      await StorageService.setDeveloperMode(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Last Error View
            _buildLastErrorView(),
            const SizedBox(height: 16),

            // Test status feedback banner
            if (_isTesting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'testing_connection'.tr(),
                        style: AppTextStyles.bodySmall(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              )
            else if (_testMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_testSuccess == true ? AppColors.statusOnline : AppColors.statusError)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_testSuccess == true ? AppColors.statusOnline : AppColors.statusError)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle_outline : Icons.error_outline,
                      color: _testSuccess == true ? AppColors.statusOnline : AppColors.statusError,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testMessage!,
                        style: AppTextStyles.labelSmall(
                          color: _testSuccess == true ? AppColors.statusOnline : AppColors.statusError,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_testSuccess == false) _buildTroubleshootingChecklist(),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: Text('test_connection_btn'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isTesting ? null : _handleTest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'save_server_url_btn'.tr(),
                    isFullWidth: true,
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _handleReset,
                child: Text(
                  'reset_default_btn'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
