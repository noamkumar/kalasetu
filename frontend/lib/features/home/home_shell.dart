import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/connectivity_pill.dart';
import '../../core/widgets/kalamitra_fab.dart';
import '../../core/widgets/language_picker.dart';
import '../../core/widgets/motifs/warli_painter.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../data/repositories/order_repository.dart';
import '../catalogue/catalogue_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../kalamitra/kalamitra_bottom_sheet.dart';
import '../marketplace/marketplace_home_screen.dart';
import '../orders/buyer_orders_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../studio/image_studio_screen.dart';
import '../studio/simple_add_product_screen.dart';

class _CraftNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _CraftNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// KalaSetu Home Shell
/// Visual Layout Matching Reference:
/// 1. Header Pattern: Serif title, bell with unread badge, Online pill
/// 2. Dark blue-teal KalaMitra pill bottom-right above the nav
/// 3. Bottom nav with dashed active mark (Kantha/Tanka stitch)
/// 4. Subtle Warli watermark pattern on background
class HomeShell extends StatefulWidget {
  final int initialTab;

  const HomeShell({super.key, this.initialTab = 1});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final OrderRepository _orderRepo = OrderRepository();
  late int _currentTab;
  int _unreadNotifications = 0;
  bool _isScrolling = false;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    StorageService.simpleModeNotifier.addListener(_onSimpleModeChanged);
    StorageService.userRoleNotifier.addListener(_onUserRoleChanged);
    if (StorageService.isBuyer) {
      _currentTab = (widget.initialTab == 1) ? 0 : (widget.initialTab <= 2 ? widget.initialTab : 0);
    } else {
      _currentTab = widget.initialTab;
    }
    _loadUnreadCount();
  }

  void _onSimpleModeChanged() {
    if (mounted) setState(() {});
  }

  void _onUserRoleChanged() {
    if (mounted) {
      setState(() {
        _currentTab = StorageService.isBuyer ? 0 : 1;
      });
    }
  }

  @override
  void dispose() {
    StorageService.simpleModeNotifier.removeListener(_onSimpleModeChanged);
    StorageService.userRoleNotifier.removeListener(_onUserRoleChanged);
    _scrollDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await _orderRepo.getUnreadCount();
    if (mounted) {
      setState(() => _unreadNotifications = count);
    }
  }

  void _openLanguagePicker() async {
    final currentCode = context.locale.languageCode;
    final selected = await LanguagePicker.showBottomSheet(
      context: context,
      currentCode: currentCode,
    );
    if (selected != null && mounted) {
      final newLocale = Locale(selected.code);
      await context.setLocale(newLocale);
      await StorageService.saveLocale(newLocale);
      VoiceService.instance.prefetchFixedPhrases(selected.code);
      setState(() {});
    }
  }

  String _getTitleForTab(int tab, bool isDesktop) {
    if (StorageService.isBuyer) {
      switch (tab) {
        case 0:
          return 'tab_marketplace'.tr();
        case 1:
          return 'tab_my_orders'.tr();
        case 2:
          return 'tab_profile'.tr();
        default:
          return 'app_name'.tr();
      }
    }

    if (isDesktop) {
      switch (tab) {
        case 0:
          return 'dashboard_title'.tr();
        case 1:
          return 'tab_add_product'.tr();
        case 2:
          return 'tab_catalogue'.tr();
        case 3:
          return 'tab_my_orders'.tr();
        case 4:
          return 'tab_profile'.tr();
        default:
          return 'app_name'.tr();
      }
    } else {
      switch (tab) {
        case 0:
          return 'tab_add_product'.tr();
        case 1:
          return 'tab_catalogue'.tr();
        case 2:
          return 'tab_my_orders'.tr();
        case 3:
          return 'tab_profile'.tr();
        case 4:
          return 'dashboard_title'.tr();
        default:
          return 'app_name'.tr();
      }
    }
  }

  String _getScreenIdentifier(bool isDesktop) {
    if (StorageService.isBuyer) {
      switch (_currentTab) {
        case 0:
          return 'marketplace';
        case 1:
          return 'orders';
        case 2:
          return 'profile';
        default:
          return 'marketplace';
      }
    }

    if (isDesktop) {
      switch (_currentTab) {
        case 0:
          return 'dashboard';
        case 1:
          return 'add_product';
        case 2:
          return 'catalogue';
        case 3:
          return 'orders';
        case 4:
          return 'profile';
        default:
          return 'dashboard';
      }
    } else {
      switch (_currentTab) {
        case 0:
          return 'add_product';
        case 1:
          return 'catalogue';
        case 2:
          return 'orders';
        case 3:
          return 'profile';
        case 4:
          return 'dashboard';
        default:
          return 'catalogue';
      }
    }
  }

  Widget _buildBody(int tab, bool isDesktop) {
    if (StorageService.isBuyer) {
      switch (tab) {
        case 0:
          return const MarketplaceHomeScreen();
        case 1:
          return const BuyerOrdersScreen();
        case 2:
          return const ProfileScreen();
        default:
          return const MarketplaceHomeScreen();
      }
    }

    if (isDesktop) {
      switch (tab) {
        case 0:
          return DashboardScreen(
            onNavigateTab: (index) => setState(() => _currentTab = index == 0 ? 1 : 2),
          );
        case 1:
          return const ImageStudioScreen();
        case 2:
          return const CatalogueScreen(showHeaderRow: false);
        case 3:
          return const OrdersScreen();
        case 4:
          return const ProfileScreen();
        default:
          return const CatalogueScreen(showHeaderRow: false);
      }
    } else {
      switch (tab) {
        case 0:
          return StorageService.isSimpleMode
              ? const SimpleAddProductScreen(showAppBar: false)
              : const ImageStudioScreen();
        case 1:
          return const CatalogueScreen(showHeaderRow: false);
        case 2:
          return const OrdersScreen();
        case 3:
          return const ProfileScreen();
        case 4:
          return DashboardScreen(
            onNavigateTab: (index) => setState(() => _currentTab = index),
          );
        default:
          return const CatalogueScreen(showHeaderRow: false);
      }
    }
  }

  void _openKalaMitra(bool isDesktop) {
    KalaMitraBottomSheet.show(
      context,
      currentScreen: _getScreenIdentifier(isDesktop),
      onSwitchTab: (tabIndex) {
        setState(() {
          if (StorageService.isBuyer) {
            _currentTab = tabIndex.clamp(0, 2);
          } else if (isDesktop) {
            if (tabIndex == 2) {
              _currentTab = 3; // Orders
            } else if (tabIndex == 0) {
              _currentTab = 1; // Add product
            } else {
              _currentTab = 2; // Catalogue
            }
          } else {
            _currentTab = tabIndex;
          }
        });
        _loadUnreadCount();
      },
    );
  }

  Widget _buildCraftBottomNavBar() {
    final items = StorageService.isBuyer
        ? [
            _CraftNavItem(
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront,
              label: 'tab_marketplace'.tr(),
            ),
            _CraftNavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag,
              label: 'tab_my_orders'.tr(),
            ),
            _CraftNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'tab_profile'.tr(),
            ),
          ]
        : [
            _CraftNavItem(
              icon: Icons.add_circle_outline,
              activeIcon: Icons.add_circle,
              label: 'tab_add_product'.tr(),
            ),
            _CraftNavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view,
              label: 'tab_catalogue'.tr(),
            ),
            _CraftNavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag,
              label: 'tab_my_orders'.tr(),
            ),
            _CraftNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'tab_profile'.tr(),
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = _currentTab == index;
              final item = items[index];

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _currentTab = index);
                    _loadUnreadCount();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dashed active mark (Kantha/Tanka dashed stitch line above active tab)
                        if (isSelected)
                          Container(
                            width: 28,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            child: const CustomPaint(
                              painter: TankaStitchPainter(
                                color: AppColors.primary,
                                isSolid: false,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 7),

                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? AppColors.primary : AppColors.inkSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: AppTextStyles.labelSmall(
                            color: isSelected ? AppColors.primaryDark : AppColors.inkSecondary,
                          ).copyWith(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isCatalogueTab = (!isDesktop && _currentTab == 1) || (isDesktop && _currentTab == 2);

    final header = AppHeader(
      title: _getTitleForTab(_currentTab, isDesktop),
      unreadNotifications: _unreadNotifications,
      onNotificationTap: () {
        context.push('/notifications');
      },
      connectivityState: ConnectivityState.online,
      actions: [
        if (isDesktop && !StorageService.isBuyer && isCatalogueTab)
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.inkPrimary),
            tooltip: 'shortcut_analytics'.tr(),
            onPressed: () => context.push('/analytics'),
          ),
        if (isDesktop && !StorageService.isBuyer)
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.dashboard_outlined, color: AppColors.inkPrimary),
            tooltip: 'dashboard_title'.tr(),
            onPressed: () => setState(() => _currentTab = 0),
          ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: const Icon(Icons.translate, color: AppColors.inkPrimary),
          tooltip: 'language_settings_title'.tr(),
          onPressed: _openLanguagePicker,
        ),
      ],
    );

    // On screens with primary bottom buttons (e.g. Add Product with Take Photo/Upload),
    // hide KalaMitra so it never covers buttons.
    final bool hideKalaMitra = StorageService.isBuyer
        ? false
        : (isDesktop ? _currentTab == 1 : _currentTab == 0);

    final scrollableBody = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification) {
          if (!_isScrolling) {
            setState(() => _isScrolling = true);
          }
          _scrollDebounce?.cancel();
          _scrollDebounce = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _isScrolling) {
              setState(() => _isScrolling = false);
            }
          });
        }
        return false;
      },
      child: CustomPaint(
        painter: const WarliWatermarkPainter(),
        child: _buildBody(_currentTab, isDesktop),
      ),
    );

    final interactiveBody = Stack(
      fit: StackFit.expand,
      children: [
        scrollableBody,
        KalaMitraFab(
          onTap: () => _openKalaMitra(isDesktop),
          isScrolling: _isScrolling,
          hide: hideKalaMitra,
        ),
      ],
    );

    if (isDesktop) {
      final destinations = StorageService.isBuyer
          ? [
              NavigationRailDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront),
                label: Text('tab_marketplace'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.shopping_bag_outlined),
                selectedIcon: const Icon(Icons.shopping_bag),
                label: Text('tab_my_orders'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: Text('tab_profile'.tr()),
              ),
            ]
          : [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: Text('dashboard_title'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.add_circle_outline),
                selectedIcon: const Icon(Icons.add_circle),
                label: Text('tab_add_product'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view),
                label: Text('tab_catalogue'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.shopping_bag_outlined),
                selectedIcon: const Icon(Icons.shopping_bag),
                label: Text('tab_my_orders'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: Text('tab_profile'.tr()),
              ),
            ];

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: header,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentTab.clamp(0, destinations.length - 1),
              onDestinationSelected: (index) {
                setState(() => _currentTab = index);
                _loadUnreadCount();
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              unselectedIconTheme: const IconThemeData(color: AppColors.inkSecondary),
              destinations: destinations,
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
            Expanded(child: interactiveBody),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: header,
      body: interactiveBody,
      bottomNavigationBar: _buildCraftBottomNavBar(),
    );
  }
}
