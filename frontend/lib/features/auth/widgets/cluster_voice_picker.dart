import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/audio_recording_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/api/api_client.dart';

class CraftClusterItem {
  final String clusterName;
  final String state;
  final String craft;

  const CraftClusterItem({
    required this.clusterName,
    required this.state,
    required this.craft,
  });
}

const List<CraftClusterItem> kFamousClusters = [
  CraftClusterItem(clusterName: 'Kumhar Gram, Delhi', state: 'Delhi', craft: 'Pottery'),
  CraftClusterItem(clusterName: 'Varanasi', state: 'Uttar Pradesh', craft: 'Handloom Silk'),
  CraftClusterItem(clusterName: 'Kutch', state: 'Gujarat', craft: 'Embroidery & Wood'),
  CraftClusterItem(clusterName: 'Pochampally', state: 'Telangana', craft: 'Ikat Handloom'),
  CraftClusterItem(clusterName: 'Chanderi', state: 'Madhya Pradesh', craft: 'Handloom Weaving'),
  CraftClusterItem(clusterName: 'Jaipur', state: 'Rajasthan', craft: 'Blue Pottery & Jewelry'),
  CraftClusterItem(clusterName: 'Madhubani', state: 'Bihar', craft: 'Folk Art & Terracotta'),
  CraftClusterItem(clusterName: 'Kondapalli', state: 'Andhra Pradesh', craft: 'Wooden Toys'),
  CraftClusterItem(clusterName: 'Bastar', state: 'Chhattisgarh', craft: 'Bell Metal Craft'),
  CraftClusterItem(clusterName: 'Tripura', state: 'Tripura', craft: 'Bamboo & Cane'),
  CraftClusterItem(clusterName: 'Thanjavur', state: 'Tamil Nadu', craft: 'Art Plates & Bronze'),
  CraftClusterItem(clusterName: 'Aranmula', state: 'Kerala', craft: 'Metal Mirror & Bell Metal'),
];

/// Visual cluster picker and voice input for zero typing
class ClusterVoicePicker extends StatefulWidget {
  final String? initialCluster;
  final void Function(String cluster, String state) onClusterSelected;

  const ClusterVoicePicker({
    super.key,
    this.initialCluster,
    required this.onClusterSelected,
  });

  @override
  State<ClusterVoicePicker> createState() => _ClusterVoicePickerState();
}

class _ClusterVoicePickerState extends State<ClusterVoicePicker> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final ApiClient _apiClient = ApiClient();

  String? _selectedCluster;
  bool _isListening = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedCluster = widget.initialCluster;
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _recordVoiceLocation() async {
    final hasPerm = await _audioService.hasPermission();
    if (!hasPerm || !mounted) return;

    if (_isListening) {
      final lang = context.locale.languageCode;
      final path = await _audioService.stopRecording();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isProcessing = true;
      });

      if (path != null) {
        try {
          final res = await _apiClient.postMultipart(
            '/api/v1/catalog/transcribe',
            filePath: path,
            fileField: 'audio',
            fields: {'language_hint': lang},
          );
          final text = (res['text'] as String?)?.trim() ?? '';
          if (text.isNotEmpty) {
            setState(() => _selectedCluster = text);
            widget.onClusterSelected(text, 'India');
            VoiceService.instance.speak(
              text: '${'selected_location'.tr()}: $text',
              languageCode: lang,
            );
          }
        } catch (_) {}
      }
      setState(() => _isProcessing = false);
    } else {
      final path = await _audioService.startRecording();
      if (path != null) {
        setState(() => _isListening = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Voice Speak Location Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.inputRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedCluster?.isNotEmpty == true
                      ? _selectedCluster!
                      : 'speak_or_choose_cluster'.tr(),
                  style: AppTextStyles.bodyLarge(
                    color: _selectedCluster?.isNotEmpty == true
                        ? AppColors.inkPrimary
                        : AppColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening
                            ? AppColors.craftTerracotta
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.pillRadius,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _recordVoiceLocation,
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        size: 18,
                      ),
                      label: Text(
                        _isListening ? 'stop'.tr() : 'speak_city'.tr(),
                        style: AppTextStyles.labelSmall(color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Visual Cluster Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kFamousClusters.map((cluster) {
            final isSelected = _selectedCluster == cluster.clusterName;
            return ChoiceChip(
              label: Text(cluster.clusterName),
              selected: isSelected,
              selectedColor: AppColors.primaryLight,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.hairline,
              ),
              labelStyle: AppTextStyles.labelMedium(
                color: isSelected ? AppColors.primaryDark : AppColors.inkPrimary,
              ),
              avatar: Icon(
                Icons.location_on_outlined,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.inkSecondary,
              ),
              onSelected: (_) {
                setState(() => _selectedCluster = cluster.clusterName);
                widget.onClusterSelected(cluster.clusterName, cluster.state);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
