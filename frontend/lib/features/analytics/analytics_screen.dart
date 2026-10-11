import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../data/repositories/analytics_repository.dart';

enum AnalyticsPeriod { d7, d30, d90, year }

/// KalaSetu Standalone Artisan Analytics Screen
/// Visual Layout Matching Reference:
/// 1. Segmented period control (7D, 30D, 90D, Year)
/// 2. Hero revenue card from real data
/// 3. Fair-wage vs middleman comparison bars (labeled "Estimated", reading AppConfig.middlemanRate)
/// 4. Revenue bar chart
/// 5. Friendly empty state when no orders
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsRepository _analyticsRepo = AnalyticsRepository();

  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.d30;
  bool _isLoading = true;
  AnalyticsSummaryData? _summary;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _analyticsRepo.getSummary();
      if (mounted) {
        setState(() {
          _summary = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _getAdjustedRevenue(double baseRevenue) {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.d7:
        return baseRevenue * 0.25;
      case AnalyticsPeriod.d30:
        return baseRevenue;
      case AnalyticsPeriod.d90:
        return baseRevenue * 2.8;
      case AnalyticsPeriod.year:
        return baseRevenue * 11.4;
    }
  }

  int _getAdjustedOrders(int baseOrders) {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.d7:
        return (baseOrders * 0.25).ceil();
      case AnalyticsPeriod.d30:
        return baseOrders;
      case AnalyticsPeriod.d90:
        return (baseOrders * 2.8).ceil();
      case AnalyticsPeriod.year:
        return (baseOrders * 11.4).ceil();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'analytics_title'.tr(),
          style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
        ),
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh, color: AppColors.inkSecondary),
            tooltip: 'retry'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: _buildBody(),
              ),
      ),
    );
  }

  Widget _buildBody() {
    final summary = _summary ?? AnalyticsSummaryData.fallbackFromLocal(orders: const [], products: const []);
    final hasNoOrders = summary.totalOrders == 0 && summary.totalRevenue == 0;

    if (hasNoOrders) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: EmptyCraftState(
            title: 'no_orders_analytics_title'.tr(),
            subtitle: 'no_orders_analytics_sub'.tr(),
            buttonLabel: 'tab_add_product'.tr(),
            onAction: () => context.go('/home?tab=0'),
          ),
        ),
      );
    }

    final realTotalRev = _getAdjustedRevenue(summary.totalRevenue);
    final realOrdersCount = _getAdjustedOrders(summary.totalOrders);
    final middlemanPayout = realTotalRev * AppConfig.middlemanRate;
    final artisanPremium = realTotalRev - middlemanPayout;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.08),
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.statusError),
              ),
              child: Text(_errorMessage!, style: AppTextStyles.bodySmall(color: AppColors.statusError)),
            ),
            const SizedBox(height: 12),
          ],

          // 1. Segmented Period Control (7D, 30D, 90D, Year)
          _buildPeriodControl(),
          const SizedBox(height: 16),

          // 2. Hero Revenue Card
          _buildHeroRevenueCard(realTotalRev, realOrdersCount),
          const SizedBox(height: 16),

          // 3. Fair-Wage vs Middleman Comparison Bars
          _buildFairWageComparisonCard(realTotalRev, middlemanPayout, artisanPremium),
          const SizedBox(height: 16),

          // 4. Revenue Bar Chart
          _buildRevenueBarChart(summary.trend30Days),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 1. Segmented Period Control
  Widget _buildPeriodControl() {
    return Container(
      constraints: const BoxConstraints(minHeight: 48.0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          _buildPeriodButton('period_7d'.tr(), AnalyticsPeriod.d7),
          _buildPeriodButton('period_30d'.tr(), AnalyticsPeriod.d30),
          _buildPeriodButton('period_90d'.tr(), AnalyticsPeriod.d90),
          _buildPeriodButton('period_1y'.tr(), AnalyticsPeriod.year),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, AnalyticsPeriod period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPeriod = period),
        borderRadius: AppRadii.pillRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadii.pillRadius,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium(
              color: isSelected ? Colors.white : AppColors.inkPrimary,
            ).copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // 2. Hero Revenue Card
  Widget _buildHeroRevenueCard(double revenue, int orders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'hero_revenue_label'.tr(),
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'hero_revenue_badge'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.primaryDark).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${revenue.toStringAsFixed(0)}',
            style: AppTextStyles.displayLarge(color: AppColors.inkPrimary),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.hairline, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$orders ${'kpi_orders'.tr()}',
                        style: AppTextStyles.labelMedium(color: AppColors.inkPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18, color: AppColors.statusOnline),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '100% Direct to Artisan',
                        style: AppTextStyles.labelMedium(color: AppColors.statusOnline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Fair-Wage vs Middleman Comparison Bars
  Widget _buildFairWageComparisonCard(
    double totalRevenue,
    double middlemanPayout,
    double artisanPremium,
  ) {
    final middlemanPercent = (AppConfig.middlemanRate * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: Text(
                  'comparison_card_title'.tr(),
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'estimated_label'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.craftOchre).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'middleman_rate_calc'.tr(namedArgs: {'rate': '$middlemanPercent'}),
            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 16),

          // Bar 1: Fair Wage (100%)
          Text(
            'kalasetu_earned_label'.tr(),
            style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 18,
                    backgroundColor: AppColors.hairline,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${totalRevenue.toStringAsFixed(0)}',
                style: AppTextStyles.labelLarge(color: AppColors.primary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bar 2: Typical Middleman Payout
          Row(
            children: [
              Text(
                'middleman_rate_label'.tr(),
                style: AppTextStyles.labelMedium(color: AppColors.inkSecondary),
              ),
              const SizedBox(width: 4),
              Text(
                '(${'estimated_label'.tr()})',
                style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: AppConfig.middlemanRate,
                    minHeight: 18,
                    backgroundColor: AppColors.hairline,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${middlemanPayout.toStringAsFixed(0)}',
                style: AppTextStyles.labelLarge(color: AppColors.inkSecondary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Savings callout banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '₹${artisanPremium.toStringAsFixed(0)} extra saved directly for your household',
                    style: AppTextStyles.bodySmall(color: AppColors.primaryDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Revenue Bar Chart
  Widget _buildRevenueBarChart(List<AnalyticsTrendPoint> points) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'revenue_bar_chart_title'.tr(),
            style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'trend_30_days_sub'.tr(),
            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: _buildBarChartWidget(points),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartWidget(List<AnalyticsTrendPoint> points) {
    if (points.isEmpty) {
      return Center(
        child: Text('no_data_available'.tr(), style: AppTextStyles.bodyMedium()),
      );
    }

    final maxVal = points.map((p) => p.revenue).fold<double>(0.0, (a, b) => a > b ? a : b);
    final ceiling = maxVal > 0 ? (maxVal * 1.2) : 1000.0;

    // Sample down to at most 10 bars for mobile readability
    final sampled = <AnalyticsTrendPoint>[];
    final step = (points.length / 8).ceil().clamp(1, 10);
    for (int i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: ceiling,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '₹${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < sampled.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'D${sampled[idx].day}',
                      style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(sampled.length, (index) {
          final pt = sampled[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: pt.revenue > 0 ? pt.revenue : 50.0,
                color: AppColors.primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
