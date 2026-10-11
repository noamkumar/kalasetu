import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/artisan_card.dart';
import '../../core/widgets/craft_category_badge.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/repositories/product_repository.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final MarketplaceRepository _marketRepo = MarketplaceRepository();
  final TextEditingController _searchController = TextEditingController();

  List<DisplayProduct> _products = [];
  bool _isLoading = true;
  CraftCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final lang = context.locale.languageCode;
    setState(() => _isLoading = true);

    try {
      final res = await _marketRepo.getMarketplaceProducts(
        category: _selectedCategory?.name,
        search: _searchQuery,
        lang: lang,
      );
      if (mounted) {
        setState(() {
          _products = res.items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadProducts,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
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
                      onSubmitted: (val) {
                        setState(() => _searchQuery = val.trim());
                        _loadProducts();
                      },
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
                                  _loadProducts();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal Category Chips
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

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyCraftState(
                  title: 'no_products_title'.tr(),
                  subtitle: 'no_products_subtitle'.tr(),
                  buttonLabel: 'retry'.tr(),
                  onAction: _loadProducts,
                ),
              ),
            )
          else
            SliverPadding(
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
                    final item = _products[index];
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
                  childCount: _products.length,
                ),
              ),
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
        _loadProducts();
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
