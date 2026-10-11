import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/product_repository.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final AnalyticsSummaryData? initialSummary;
  final Stream<List<DisplayProduct>>? productsStream;
  final bool enableRefresh;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
    this.initialSummary,
    this.productsStream,
    this.enableRefresh = true,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AnalyticsRepository _analyticsRepo = AnalyticsRepository();
  final ProductRepository _productRepo = ProductRepository();

  int _selectedSidebarIndex = 0; // 0: Overview, 1: Products, 2: Analytics
  bool _isLoading = true;
  AnalyticsSummaryData? _summaryData;

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summaryData = widget.initialSummary;
      _isLoading = false;
    } else if (widget.enableRefresh) {
      _loadData();
    } else {
      _summaryData = AnalyticsSummaryData.fallbackFromLocal(orders: const [], products: const []);
      _isLoading = false;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _analyticsRepo.getSummary();
    if (mounted) {
      setState(() {
        _summaryData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _buildDesktopSidebar(),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _buildMainContent(isDesktop),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet layout
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: _buildMainContent(isDesktop),
            ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('app_name'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('dashboard_portal_sub'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 12),
          _buildSidebarItem(0, Icons.dashboard_outlined, Icons.dashboard, 'dashboard_nav_overview'.tr()),
          _buildSidebarItem(1, Icons.inventory_2_outlined, Icons.inventory_2, 'dashboard_nav_products'.tr()),
          _buildSidebarItem(2, Icons.analytics_outlined, Icons.analytics, 'dashboard_nav_analytics'.tr()),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: AppColors.primary, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'dashboard_ondc_badge'.tr(),
                          style: AppTextStyles.labelMedium(color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'dashboard_ondc_desc'.tr(),
                    style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedSidebarIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedSidebarIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(isSelected ? activeIcon : icon, color: isSelected ? AppColors.primary : AppColors.inkSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelMedium(
                  color: isSelected ? AppColors.primary : AppColors.inkPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    final summary = _summaryData ?? AnalyticsSummaryData.fallbackFromLocal(orders: const [], products: const []);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: isDesktop ? 28 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar / Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedSidebarIndex == 1
                        ? 'dashboard_nav_products'.tr()
                        : (_selectedSidebarIndex == 2 ? 'dashboard_nav_analytics'.tr() : 'dashboard_title'.tr()),
                    style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'dashboard_subtitle'.tr(),
                    style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.inkSecondary),
                    tooltip: 'retry'.tr(),
                    onPressed: _loadData,
                  ),
                  if (widget.onNavigateTab != null)
                    AppButton(
                      label: 'tab_add_product'.tr(),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      isFullWidth: false,
                      onPressed: () => widget.onNavigateTab!(0),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Render selected tab view
          if (_selectedSidebarIndex == 0) ...[
            _buildKpiGrid(summary, isDesktop),
            const SizedBox(height: 24),
            _buildAnalyticsSection(summary, isDesktop),
            const SizedBox(height: 28),
            _buildProductsTableSection(isDesktop),
          ] else if (_selectedSidebarIndex == 1) ...[
            _buildProductsTableSection(isDesktop, isFullPage: true),
          ] else ...[
            _buildKpiGrid(summary, isDesktop),
            const SizedBox(height: 24),
            _buildAnalyticsSection(summary, isDesktop, isFullPage: true),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // 1. KPI Cards
  Widget _buildKpiGrid(AnalyticsSummaryData summary, bool isDesktop) {
    final cards = [
      _buildKpiCard(
        title: 'kpi_revenue'.tr(),
        value: '₹${summary.totalRevenue.toStringAsFixed(0)}',
        sub: 'kpi_revenue_sub'.tr(),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.primary,
      ),
      _buildKpiCard(
        title: 'kpi_orders'.tr(),
        value: '${summary.totalOrders}',
        sub: 'kpi_orders_sub'.tr(args: ['${summary.deliveredOrders}']),
        icon: Icons.shopping_bag_outlined,
        color: AppColors.secondary,
      ),
      _buildKpiCard(
        title: 'kpi_pending'.tr(),
        value: '${summary.pendingOrders}',
        sub: 'kpi_pending_sub'.tr(),
        icon: Icons.pending_actions_outlined,
        color: AppColors.craftOchre,
      ),
      _buildKpiCard(
        title: 'kpi_products'.tr(),
        value: '${summary.activeProducts}',
        sub: 'kpi_products_sub'.tr(),
        icon: Icons.inventory_2_outlined,
        color: AppColors.accentBlue,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = constraints.maxWidth > 550 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxis,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: cards,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x082B2E2A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelMedium(color: AppColors.inkSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.displaySmall(color: AppColors.inkPrimary)),
              const SizedBox(height: 2),
              Text(sub, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Analytics: 30-Day Trend (fl_chart) + Popular Crafts
  Widget _buildAnalyticsSection(AnalyticsSummaryData summary, bool isDesktop, {bool isFullPage = false}) {
    final chartCard = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('trend_30_days_title'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
                    const SizedBox(height: 2),
                    Text('trend_30_days_sub'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('trend_last_30_days'.tr(), style: AppTextStyles.labelSmall(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 260 : 200,
            child: _buildLineChart(summary.trend30Days),
          ),
        ],
      ),
    );

    final popularCraftsCard = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('popular_crafts_title'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
          const SizedBox(height: 4),
          Text('popular_crafts_sub'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
          const SizedBox(height: 18),
          ...summary.popularCrafts.map((craft) => _buildPopularCraftBar(craft, summary.totalRevenue)),
        ],
      ),
    );

    if (isDesktop && !isFullPage) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: chartCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: popularCraftsCard),
        ],
      );
    }

    return Column(
      children: [
        chartCard,
        const SizedBox(height: 16),
        popularCraftsCard,
      ],
    );
  }

  Widget _buildLineChart(List<AnalyticsTrendPoint> points) {
    if (points.isEmpty) {
      return Center(child: Text('no_data_available'.tr(), style: AppTextStyles.bodyMedium()));
    }

    final spots = points.map((p) => FlSpot(p.day.toDouble(), p.revenue)).toList();
    final maxRev = points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRev > 0 ? (maxRev / 4) : 1000,
          getDrawingHorizontalLine: (val) => FlLine(
            color: AppColors.hairline.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
              getTitlesWidget: (val, meta) {
                if (val % 5 == 0 && val >= 1 && val <= 30) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('D${val.toInt()}', style: AppTextStyles.labelSmall(color: AppColors.inkSecondary)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: maxRev > 0 ? (maxRev / 3) : 1000,
              getTitlesWidget: (val, meta) {
                return Text(
                  '₹${(val / 1000).toStringAsFixed(0)}k',
                  style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: 30,
        minY: 0,
        maxY: maxRev * 1.15,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Day ${spot.x.toInt()}\n₹${spot.y.toStringAsFixed(0)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.35),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCraftBar(AnalyticsPopularCraft craft, double totalRevenue) {
    final pct = totalRevenue > 0 ? (craft.revenue / totalRevenue).clamp(0.0, 1.0) : 0.2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  craft.category,
                  style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${craft.ordersCount} orders • ₹${craft.revenue.toStringAsFixed(0)}',
                style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.hairline.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Products Management Table
  Widget _buildProductsTableSection(bool isDesktop, {bool isFullPage = false}) {
    String currentLang = 'en';
    try {
      currentLang = context.locale.languageCode;
    } catch (_) {
      currentLang = 'en';
    }

    return StreamBuilder<List<DisplayProduct>>(
      initialData: const [],
      stream: widget.productsStream ?? _productRepo.watchProducts(currentLang),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('products_table_title'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
                      const SizedBox(height: 2),
                      Text('products_table_sub'.tr(args: ['${products.length}']), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    ],
                  ),
                  if (!isFullPage)
                    TextButton(
                      onPressed: () => setState(() => _selectedSidebarIndex = 1),
                      child: Text('view_all'.tr(), style: AppTextStyles.labelMedium(color: AppColors.primary)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text('no_products_found'.tr(), style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary)),
                  ),
                )
              else if (isDesktop)
                _buildDataTable(products)
              else
                _buildMobileProductsList(products),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataTable(List<DisplayProduct> products) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        dataRowMaxHeight: 64,
        columns: [
          DataColumn(label: Text('table_header_product'.tr(), style: AppTextStyles.labelMedium())),
          DataColumn(label: Text('table_header_category'.tr(), style: AppTextStyles.labelMedium())),
          DataColumn(label: Text('table_header_price'.tr(), style: AppTextStyles.labelMedium())),
          DataColumn(label: Text('table_header_stock'.tr(), style: AppTextStyles.labelMedium())),
          DataColumn(label: Text('table_header_status'.tr(), style: AppTextStyles.labelMedium())),
        ],
        rows: products.map((prod) {
          final imageUrl = ApiClient().resolveMediaUrl(prod.enhancedImageUrl ?? prod.primaryImageUrl);
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: AppColors.background,
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20))
                            : const Icon(Icons.image, size: 20, color: AppColors.inkSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        prod.title,
                        style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(prod.category.toUpperCase(), style: AppTextStyles.bodySmall())),
              DataCell(Text('₹${prod.price.toStringAsFixed(0)}', style: AppTextStyles.labelLarge(color: AppColors.primary))),
              DataCell(Text('${prod.stockQuantity}', style: AppTextStyles.bodyMedium())),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: prod.status.toLowerCase() == 'active'
                        ? AppColors.statusOnline.withValues(alpha: 0.12)
                        : AppColors.inkSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prod.status.toUpperCase(),
                    style: TextStyle(
                      color: prod.status.toLowerCase() == 'active' ? AppColors.statusOnline : AppColors.inkSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileProductsList(List<DisplayProduct> products) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.take(6).length,
      separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.hairline),
      itemBuilder: (context, index) {
        final prod = products[index];
        final imageUrl = ApiClient().resolveMediaUrl(prod.enhancedImageUrl ?? prod.primaryImageUrl);
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: AppColors.background,
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20))
                    : const Icon(Icons.image, size: 20, color: AppColors.inkSecondary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prod.title, style: AppTextStyles.labelMedium(color: AppColors.inkPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${prod.category.toUpperCase()} • Qty: ${prod.stockQuantity}', style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                ],
              ),
            ),
            Text('₹${prod.price.toStringAsFixed(0)}', style: AppTextStyles.labelLarge(color: AppColors.primary)),
          ],
        );
      },
    );
  }
}
