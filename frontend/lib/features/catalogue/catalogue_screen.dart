import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/artisan_card.dart';
import '../../core/widgets/connectivity_pill.dart';
import '../../core/widgets/craft_category_badge.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';

class CatalogueScreen extends StatefulWidget {
  final bool showHeaderRow;

  const CatalogueScreen({super.key, this.showHeaderRow = true});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final OrderRepository _orderRepo = OrderRepository();
  final TextEditingController _searchController = TextEditingController();

  CraftCategory? _selectedCategory;
  String _searchQuery = '';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadUnreadNotifications();
    });
  }

  Future<void> _loadUnreadNotifications() async {
    final count = await _orderRepo.getUnreadCount();
    if (mounted) {
      setState(() => _unreadNotifications = count);
    }
  }

  Future<void> _refresh() async {
    final lang = context.locale.languageCode;
    await _productRepo.refreshProducts(lang);
    await _loadUnreadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(CraftCategory? category) {
    if (category == null) return Icons.grid_view_rounded;
    switch (category) {
      case CraftCategory.all:
        return Icons.grid_view_rounded;
      case CraftCategory.pottery:
        return Icons.eco_rounded;
      case CraftCategory.handloom:
        return Icons.style_rounded;
      case CraftCategory.jewelry:
        return Icons.diamond_rounded;
      case CraftCategory.wood:
        return Icons.forest_rounded;
      case CraftCategory.bamboo:
        return Icons.grass_rounded;
    }
  }

  String _getCategoryLabel(CraftCategory? category) {
    if (category == null) return 'category_all'.tr();
    return category.label;
  }

  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.notifications_outlined, color: AppColors.inkPrimary),
          tooltip: 'notifications_title'.tr(),
          onPressed: () => context.push('/notifications'),
        ),
        if (_unreadNotifications > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.craftTerracotta,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Title Row: Analytics Shortcut, Bell with Badge, Online Pill
                  if (widget.showHeaderRow) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'tab_catalogue'.tr(),
                            style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: const Icon(Icons.bar_chart_rounded, color: AppColors.inkPrimary),
                          tooltip: 'shortcut_analytics'.tr(),
                          onPressed: () => context.push('/analytics'),
                        ),
                        _buildNotificationBell(),
                        const SizedBox(width: 4),
                        const ConnectivityPill(state: ConnectivityState.online),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 2. Pill Search Bar
                  Container(
                    constraints: const BoxConstraints(minHeight: 48.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.pillRadius,
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                      decoration: InputDecoration(
                        hintText: 'search_hint'.tr(),
                        hintStyle: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                        prefixIcon: const Icon(Icons.search, color: AppColors.inkSecondary, size: 22),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.inkSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Fair Mode Quick Access (Section 12: "I am at a fair" button)
                  ValueListenableBuilder<bool>(
                    valueListenable: StorageService.fairModeNotifier,
                    builder: (context, isFairActive, _) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Material(
                          color: isFairActive ? AppColors.craftTerracotta : AppColors.surface,
                          borderRadius: AppRadii.cardRadius,
                          elevation: isFairActive ? 2 : 0,
                          child: InkWell(
                            onTap: () => context.push(RouteNames.fairMode),
                            borderRadius: AppRadii.cardRadius,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: AppRadii.cardRadius,
                                border: Border.all(
                                  color: isFairActive ? AppColors.craftTerracotta : AppColors.secondary,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isFairActive
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : AppColors.secondaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.festival_rounded,
                                      color: isFairActive ? Colors.white : AppColors.craftTerracotta,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isFairActive ? 'fair_active_badge'.tr() : 'i_am_at_a_fair_btn'.tr(),
                                          style: AppTextStyles.titleMedium(
                                            color: isFairActive ? Colors.white : AppColors.inkPrimary,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          isFairActive
                                              ? 'fair_active_sub'.tr()
                                              : 'fair_mode_fast_add_desc'.tr(),
                                          style: AppTextStyles.bodySmall(
                                            color: isFairActive
                                                ? Colors.white.withValues(alpha: 0.9)
                                                : AppColors.inkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: isFairActive ? Colors.white : AppColors.inkSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 3. Horizontally Scrolling Category Chips with Icons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CraftCategory.values.map((cat) {
                        final isAll = cat == CraftCategory.all;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildCategoryChip(isAll ? null : cat),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // 4. StreamBuilder for 2-Column Grid
          StreamBuilder<List<DisplayProduct>>(
            stream: _productRepo.watchProducts(lang),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];

              // Filter by category and search
              final filtered = products.where((p) {
                if (_selectedCategory != null) {
                  final catName = _selectedCategory!.name.toLowerCase();
                  if (!p.category.toLowerCase().contains(catName)) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final matchesTitle = p.title.toLowerCase().contains(_searchQuery);
                  final matchesDesc = p.description?.toLowerCase().contains(_searchQuery) ?? false;
                  if (!matchesTitle && !matchesDesc) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyCraftState(
                      title: 'no_products_title'.tr(),
                      subtitle: 'no_products_subtitle'.tr(),
                      buttonLabel: 'tab_add_product'.tr(),
                      onAction: () => context.go('/home?tab=0'),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.58,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      final isRecentLive = item.status == 'live' &&
                          DateTime.now().difference(item.createdAt).inMinutes < 60;
                      return ArtisanCard(
                        title: item.title,
                        price: '₹${item.price.toStringAsFixed(0)}',
                        category: item.category,
                        imageUrl: item.primaryImageUrl,
                        status: isRecentLive ? 'new' : item.status,
                        onTap: () => context.push('/product/${item.id}'),
                        onSocialMediaHelperTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('social_share_success'.tr()),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(CraftCategory? category) {
    final isSelected = _selectedCategory == category;
    final label = _getCategoryLabel(category);
    final icon = _getCategoryIcon(category);

    return InkWell(
      onTap: () {
        setState(() => _selectedCategory = category);
      },
      borderRadius: AppRadii.pillRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium(
                color: isSelected ? Colors.white : AppColors.inkPrimary,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
