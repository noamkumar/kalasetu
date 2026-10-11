import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/craft_category_badge.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/repositories/auth_repository.dart';
import 'widgets/cluster_voice_picker.dart';

class AuthProfileScreen extends StatefulWidget {
  const AuthProfileScreen({super.key});

  @override
  State<AuthProfileScreen> createState() => _AuthProfileScreenState();
}

class _AuthProfileScreenState extends State<AuthProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();

  CraftCategory _selectedCraft = CraftCategory.pottery;
  String _selectedRole = 'artisan'; // 'artisan' or 'buyer'
  bool _isLoading = false;
  String? _errorMessage;

  final List<CraftCategory> _craftCategories = [
    CraftCategory.pottery,
    CraftCategory.handloom,
    CraftCategory.wood,
    CraftCategory.jewelry,
    CraftCategory.bamboo,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'profile_setup_instruction'.tr(),
      );
    });
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final state = _stateController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'full_name_required'.tr());
      return;
    }

    if (_selectedRole == 'buyer') {
      if (location.isEmpty) {
        setState(() => _errorMessage = 'delivery_address_required'.tr());
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _authRepo.updateBuyerProfile(
          name: name,
          address: location,
          state: state.isNotEmpty ? state : 'India',
        );
        if (!mounted) return;
        context.go(RouteNames.home);
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorMessage = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (location.isEmpty) {
        setState(() => _errorMessage = 'cluster_location_required'.tr());
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _authRepo.updateProfile(
          name: name,
          craftType: _selectedCraft.name,
          location: location,
          state: state.isNotEmpty ? state : 'India',
        );
        if (!mounted) return;
        context.go(RouteNames.home);
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorMessage = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = _selectedRole == 'buyer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isBuyer ? 'buyer_profile_title'.tr() : 'register_title'.tr(),
                      style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
                    ),
                  ),
                  SpeakerAffordance(
                    textToSpeak: 'profile_setup_instruction'.tr(),
                    languageCode: context.locale.languageCode,
                    label: 'listen_instruction'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isBuyer ? 'role_buyer_sub'.tr() : 'register_subtitle'.tr(),
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 24),

              // Role selection: "I want to sell" vs "I want to buy"
              Text('choose_role_prompt'.tr(), style: AppTextStyles.labelMedium()),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      role: 'artisan',
                      title: 'role_artisan_seller'.tr(),
                      subtitle: 'role_seller_sub'.tr(),
                      icon: Icons.storefront_rounded,
                      isSelected: _selectedRole == 'artisan',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRoleCard(
                      role: 'buyer',
                      title: 'role_buyer'.tr(),
                      subtitle: 'role_buyer_sub'.tr(),
                      icon: Icons.shopping_bag_rounded,
                      isSelected: _selectedRole == 'buyer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Full Name
              Text('full_name_label'.tr(), style: AppTextStyles.labelMedium()),
              const SizedBox(height: 6),
              _buildTextField(_nameController, 'full_name_hint'.tr()),
              const SizedBox(height: 20),

              if (!isBuyer) ...[
                // Craft Type (for Artisan)
                Text('craft_type_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _craftCategories.map((cat) {
                    return CraftCategoryBadge(
                      category: cat,
                      isSelected: _selectedCraft == cat,
                      onSelected: (cat) => setState(() => _selectedCraft = cat),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Cluster / Village (for Artisan) with Voice & Visual picker
                Text('cluster_location_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 8),
                ClusterVoicePicker(
                  initialCluster: _locationController.text,
                  onClusterSelected: (cluster, state) {
                    setState(() {
                      _locationController.text = cluster;
                      if (state.isNotEmpty) {
                        _stateController.text = state;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
              ]
 else ...[
                // Delivery Address (for Buyer)
                Text('delivery_address_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 6),
                _buildTextField(_locationController, 'delivery_address_hint'.tr(), maxLines: 2),
                const SizedBox(height: 20),
              ],

              // State
              Text('state_label'.tr(), style: AppTextStyles.labelMedium()),
              const SizedBox(height: 6),
              _buildTextField(_stateController, 'state_hint'.tr()),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall(color: AppColors.statusError),
                ),
              ],
              const SizedBox(height: 36),
              AppButton(
                label: 'done'.tr(),
                variant: AppButtonVariant.primary,
                isLoading: _isLoading,
                isFullWidth: true,
                onPressed: _handleSave,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: AppRadii.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: isSelected ? AppColors.primary : AppColors.inkSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.labelMedium(
                color: isSelected ? AppColors.primary : AppColors.inkPrimary,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.inputRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.bodyLarge(color: AppColors.inkPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
