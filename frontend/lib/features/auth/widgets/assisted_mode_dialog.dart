import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';

/// Dialog enabling an NGO or cluster helper to sign in and list products
/// on behalf of the artisan, storing helper details on the session.
class AssistedModeDialog extends StatefulWidget {
  final VoidCallback onHelperRegistered;

  const AssistedModeDialog({super.key, required this.onHelperRegistered});

  static Future<void> show(BuildContext context, {required VoidCallback onHelperRegistered}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AssistedModeDialog(onHelperRegistered: onHelperRegistered),
    );
  }

  @override
  State<AssistedModeDialog> createState() => _AssistedModeDialogState();
}

class _AssistedModeDialogState extends State<AssistedModeDialog> {
  final TextEditingController _helperNameController = TextEditingController();
  final TextEditingController _helperCodeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _helperNameController.dispose();
    _helperCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _helperNameController.text.trim();
    final code = _helperCodeController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'helper_name_required'.tr());
      return;
    }

    final effectiveCode = code.isNotEmpty ? code : 'NGO-${DateTime.now().millisecondsSinceEpoch % 10000}';
    await StorageService.setAssistedHelper(helperName: name, code: effectiveCode);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onHelperRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.secondaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'assisted_mode_title'.tr(),
              style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'assisted_mode_subtitle'.tr(),
              style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 18),
            Text('helper_name_label'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _helperNameController,
              decoration: InputDecoration(
                hintText: 'helper_name_hint'.tr(),
                border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text('helper_code_label'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _helperCodeController,
              decoration: InputDecoration(
                hintText: 'e.g. NGO-1042',
                border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.statusError)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr(), style: AppTextStyles.labelLarge(color: AppColors.inkSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _handleSave,
          child: Text('continue_as_helper'.tr()),
        ),
      ],
    );
  }
}
