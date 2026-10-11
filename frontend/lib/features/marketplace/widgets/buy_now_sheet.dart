import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/marketplace_repository.dart';
import '../../../data/repositories/product_repository.dart';

class BuyNowSheet extends StatefulWidget {
  final DisplayProduct product;

  const BuyNowSheet({super.key, required this.product});

  static Future<void> show(BuildContext context, DisplayProduct product) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BuyNowSheet(product: product),
    );
  }

  @override
  State<BuyNowSheet> createState() => _BuyNowSheetState();
}

class _BuyNowSheetState extends State<BuyNowSheet> {
  final MarketplaceRepository _marketRepo = MarketplaceRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  int _quantity = 1;
  String _paymentMethod = 'cash_on_delivery'; // 'cash_on_delivery' or 'pay_later'
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: StorageService.artisanName ?? '');
    _phoneController = TextEditingController(text: StorageService.artisanPhone ?? '');
    _addressController = TextEditingController(text: StorageService.deliveryAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save address for future orders
      await StorageService.setDeliveryAddress(address);

      final orderRes = await _marketRepo.placeOrder(
        productId: widget.product.id,
        quantity: _quantity,
        unitPrice: widget.product.price,
        customerName: name,
        customerPhone: phone,
        customerAddress: address,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close sheet

      final orderId = orderRes['id']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_placed_success'.tr()),
          backgroundColor: AppColors.statusOnline,
        ),
      );

      if (orderId.isNotEmpty) {
        context.push('/order/track/$orderId');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalAmount = widget.product.price * _quantity;
    final maxStock = widget.product.stockQuantity.clamp(1, 999);

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'checkout_title'.tr(),
                      style: AppTextStyles.titleLarge(color: AppColors.inkPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.inkSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.title,
                              style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${widget.product.price.toStringAsFixed(0)} / piece',
                              style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('qty_label'.tr(), style: AppTextStyles.labelMedium()),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.hairline),
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Text(
                            '$_quantity',
                            style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _quantity < maxStock ? () => setState(() => _quantity++) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer Name
                Text('full_name_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 6),
                _buildTextFormField(
                  controller: _nameController,
                  hint: 'full_name_hint'.tr(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'full_name_required'.tr() : null,
                ),
                const SizedBox(height: 12),

                // Customer Phone
                Text('phone_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 6),
                _buildTextFormField(
                  controller: _phoneController,
                  hint: 'phone_hint'.tr(),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'phone_invalid'.tr() : null,
                ),
                const SizedBox(height: 12),

                // Delivery Address
                Text('delivery_address_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 6),
                _buildTextFormField(
                  controller: _addressController,
                  hint: 'delivery_address_hint'.tr(),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'delivery_address_required'.tr() : null,
                ),
                const SizedBox(height: 16),

                // Payment Method
                Text('payment_method_label'.tr(), style: AppTextStyles.labelMedium()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentOption(
                        label: 'payment_cod'.tr(),
                        icon: Icons.money_rounded,
                        value: 'cash_on_delivery',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPaymentOption(
                        label: 'payment_pay_later'.tr(),
                        icon: Icons.schedule_rounded,
                        value: 'pay_later',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Price Breakdown Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('total_amount_label'.tr(), style: AppTextStyles.titleMedium()),
                      Text(
                        '₹${totalAmount.toStringAsFixed(0)}',
                        style: AppTextStyles.titleLarge(color: AppColors.primary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall(color: AppColors.statusError),
                  ),
                ],
                const SizedBox(height: 20),

                // Place Order Button
                AppButton(
                  label: 'place_order_btn'.tr(),
                  variant: AppButtonVariant.primary,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  onPressed: _handlePlaceOrder,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.hairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.inkSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelMedium(
                  color: isSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.inputRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
