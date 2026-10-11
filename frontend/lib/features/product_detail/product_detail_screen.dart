import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/api_client.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/repositories/product_repository.dart';
import '../marketplace/widgets/buy_now_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductRepository _productRepo = ProductRepository();
  DisplayProduct? _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final lang = context.locale.languageCode;
    final item = await _productRepo.getProductById(widget.productId, lang);
    if (mounted) {
      setState(() {
        _product = item;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text('Product not found', style: AppTextStyles.bodyLarge()),
        ),
      );
    }

    final p = _product!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProductImage(p.primaryImageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadii.pillRadius,
                        ),
                        child: Text(
                          p.category,
                          style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                        ),
                      ),
                      Text(
                        '₹${p.price.toStringAsFixed(0)}',
                        style: AppTextStyles.displaySmall(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    p.title,
                    style: AppTextStyles.headlineMedium(color: AppColors.inkPrimary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SpeakerAffordance(
                        label: 'tap_to_hear'.tr(),
                        textToSpeak: '${p.title}. ${p.description ?? ''}',
                        languageCode: context.locale.languageCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'product_description_label'.tr(),
                    style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.description ?? 'No description available.',
                    style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                  ),
                  if (p.materials != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Materials & Tradition',
                      style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.materials!,
                      style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                    ),
                  ],
                  const SizedBox(height: 36),
                  if (p.status == 'sold_out')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.statusError.withValues(alpha: 0.1),
                        borderRadius: AppRadii.buttonRadius,
                      ),
                      child: Center(
                        child: Text(
                          'stock_sold_out'.tr(),
                          style: AppTextStyles.labelLarge(color: AppColors.statusError).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    AppButton(
                      label: 'buy_now'.tr(),
                      variant: AppButtonVariant.primary,
                      isFullWidth: true,
                      onPressed: () => BuyNowSheet.show(context, p),
                    ),
                    if (!StorageService.isBuyer) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'edit'.tr(),
                        variant: AppButtonVariant.outlined,
                        isFullWidth: true,
                        onPressed: () {},
                      ),
                    ],
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }
    if (imageUrl.startsWith('/static/')) {
      final fullUrl = ApiClient().resolveMediaUrl(imageUrl);
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }
    final file = File(imageUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.image, size: 64, color: AppColors.hairline),
      ),
    );
  }
}
