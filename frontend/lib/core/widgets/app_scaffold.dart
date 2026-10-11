import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'motifs/warli_painter.dart';

class SidebarNavigationItem {
  final IconData icon;
  final String label;
  final String? route;

  const SidebarNavigationItem({
    required this.icon,
    required this.label,
    this.route,
  });
}

/// KalaSetu App Scaffold
/// Page frame with subtle Warli watermark pattern, optional header, and responsive navigation
/// Section 5.5 of Project Specification
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? header;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final int selectedNavIndex;
  final ValueChanged<int>? onNavItemSelected;
  final bool showWatermark;
  final List<SidebarNavigationItem>? sidebarItems;

  const AppScaffold({
    super.key,
    required this.body,
    this.header,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.selectedNavIndex = 0,
    this.onNavItemSelected,
    this.showWatermark = true,
    this.sidebarItems,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppSpacing.isDesktop(context);

    Widget contentBody = body;

    // Apply Warli Watermark background
    if (showWatermark) {
      contentBody = CustomPaint(
        painter: const WarliWatermarkPainter(),
        child: contentBody,
      );
    }

    // On Desktop (>= 900 px), render left sidebar navigation
    if (isDesktop && (sidebarItems != null && sidebarItems!.isNotEmpty)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left Desktop Sidebar
            _buildDesktopSidebar(context),
            // Main Content Area
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: header,
                body: contentBody,
                floatingActionButton: floatingActionButton,
                floatingActionButtonLocation: floatingActionButtonLocation,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile & Tablet Scaffold
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: header,
      body: contentBody,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final items = sidebarItems ?? const [];

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.hairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Title
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.palette_outlined, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KalaSetu', style: AppTextStyles.titleMedium()),
                    Text('Artisan AI', style: AppTextStyles.labelSmall(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Sidebar Nav Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedNavIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: isSelected ? AppColors.primaryLight : Colors.transparent,
                    leading: Icon(
                      item.icon,
                      color: isSelected ? AppColors.primary : AppColors.inkSecondary,
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: AppTextStyles.labelMedium(
                        color: isSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                      ).copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: onNavItemSelected != null ? () => onNavItemSelected!(index) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
