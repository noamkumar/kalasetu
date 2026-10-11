import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../services/storage_service.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/language/language_select_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/auth_phone_screen.dart';
import '../../features/auth/auth_otp_screen.dart';
import '../../features/auth/auth_profile_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/product_detail/product_detail_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../features/cataloger/voice_catalog_screen.dart';
import '../../features/cataloger/voice_catalog_review_screen.dart';
import '../../features/studio/image_studio_screen.dart';
import '../../features/studio/photo_editor_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/marketplace/marketplace_home_screen.dart';
import '../../features/orders/order_tracking_screen.dart';
import '../../features/studio/simple_add_product_screen.dart';
import '../../features/product_detail/product_published_success_screen.dart';
import '../../features/catalogue/fair_mode_screen.dart';
import '../../features/orders/business_orders_screen.dart';
import '../../features/marketplace/marketplace_connect_screen.dart';
import '../../features/analytics/simple_earnings_screen.dart';

/// KalaSetu Application Router using GoRouter
/// Section 2 and 10.3 of Project Specification
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  redirect: (context, state) {
    final location = state.uri.path;
    final isGallery = location == RouteNames.gallery;
    final isSplash = location == RouteNames.splash;

    // Allow debug gallery route unconditionally
    if (isGallery || isSplash) return null;

    final langChosen = StorageService.isLanguageChosen;
    final onboardingDone = StorageService.isOnboardingCompleted;
    final loggedIn = StorageService.isLoggedIn;

    // First launch guard
    if (!langChosen && location != RouteNames.language) {
      return RouteNames.language;
    }
    // Onboarding guard
    if (langChosen && !onboardingDone && location != RouteNames.onboarding) {
      return RouteNames.onboarding;
    }
    // Auth guards
    final isAuthRoute = location.startsWith('/auth');
    if (langChosen && onboardingDone && !loggedIn && !isAuthRoute) {
      return RouteNames.authPhone;
    }
    if (loggedIn && (isAuthRoute || location == RouteNames.onboarding || location == RouteNames.language)) {
      return RouteNames.home;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: RouteNames.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RouteNames.language,
      name: 'language',
      builder: (context, state) => const LanguageSelectScreen(),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: RouteNames.authPhone,
      name: 'auth_phone',
      builder: (context, state) => const AuthPhoneScreen(),
    ),
    GoRoute(
      path: RouteNames.authOtp,
      name: 'auth_otp',
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        final debugOtp = state.uri.queryParameters['debug_otp'];
        return AuthOtpScreen(phone: phone, debugOtp: debugOtp);
      },
    ),
    GoRoute(
      path: RouteNames.authProfile,
      name: 'auth_profile',
      builder: (context, state) => const AuthProfileScreen(),
    ),
    GoRoute(
      path: RouteNames.home,
      name: 'home',
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = tabStr != null ? int.tryParse(tabStr) ?? 1 : 1;
        return HomeShell(initialTab: tab);
      },
    ),
    GoRoute(
      path: '/product/:id',
      name: 'product_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProductDetailScreen(productId: id);
      },
    ),
    GoRoute(
      path: RouteNames.gallery,
      name: 'gallery',
      builder: (context, state) => const GalleryScreen(),
    ),
    GoRoute(
      path: RouteNames.addDescribe,
      name: 'add_describe',
      builder: (context, state) {
        final cat = state.uri.queryParameters['category'] ?? 'pottery';
        final img = state.uri.queryParameters['image_url'];
        return VoiceCatalogScreen(initialCategory: cat, initialImageUrl: img);
      },
    ),
    GoRoute(
      path: RouteNames.addStudio,
      name: 'add_studio',
      builder: (context, state) => const ImageStudioScreen(),
    ),
    GoRoute(
      path: RouteNames.photoEditor,
      name: 'photo_editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final imageId = extra?['image_id']?.toString() ?? state.uri.queryParameters['image_id'] ?? '';
        final originalUrl = extra?['original_url']?.toString() ?? state.uri.queryParameters['original_url'] ?? '';
        final initialEditedUrl = extra?['initial_edited_url']?.toString() ?? state.uri.queryParameters['initial_edited_url'];
        final onSave = extra?['on_save'] as ValueChanged<String>?;
        return PhotoEditorScreen(
          imageId: imageId,
          originalUrl: originalUrl,
          initialEditedUrl: initialEditedUrl,
          onSave: onSave,
        );
      },
    ),
    GoRoute(
      path: RouteNames.addPrice,
      name: 'add_price',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final category = extra?['category']?.toString() ?? state.uri.queryParameters['category'] ?? 'pottery';
        final listing = extra?['listing'] as CatalogListingResult?;
        final imageUrl = extra?['image_url']?.toString() ?? state.uri.queryParameters['image_url'];
        return PricingScreen(
          category: category,
          listing: listing,
          imageUrl: imageUrl,
        );
      },
    ),
    GoRoute(
      path: RouteNames.addReview,
      name: 'add_review',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final category = extra?['category']?.toString() ?? 'pottery';
        final listing = extra?['listing'] as CatalogListingResult;
        final price = extra?['price'] as int?;
        final imageUrl = extra?['image_url']?.toString();
        return VoiceCatalogReviewScreen(
          category: category,
          listing: listing,
          price: price,
          imageUrl: imageUrl,
        );
      },
    ),
    GoRoute(
      path: RouteNames.dashboard,
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: RouteNames.analytics,
      name: 'analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: RouteNames.notifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/order/track/:id',
      name: 'order_track',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return OrderTrackingScreen(orderId: id);
      },
    ),
    GoRoute(
      path: RouteNames.marketplace,
      name: 'marketplace',
      builder: (context, state) => const MarketplaceHomeScreen(),
    ),
    GoRoute(
      path: RouteNames.simpleAdd,
      name: 'simple_add',
      builder: (context, state) => const SimpleAddProductScreen(),
    ),
    GoRoute(
      path: RouteNames.publishedSuccess,
      name: 'published_success',
      builder: (context, state) {
        final productId = state.uri.queryParameters['product_id'] ?? '';
        final title = state.uri.queryParameters['title'] ?? 'Handmade Craft';
        final price = int.tryParse(state.uri.queryParameters['price'] ?? '0') ?? 0;
        final imageUrl = state.uri.queryParameters['image_url'];
        return ProductPublishedSuccessScreen(
          productId: productId,
          title: title,
          price: price,
          imageUrl: imageUrl,
        );
      },
    ),
    GoRoute(
      path: RouteNames.fairMode,
      name: 'fair_mode',
      builder: (context, state) => const FairModeScreen(),
    ),
    GoRoute(
      path: RouteNames.businessOrders,
      name: 'business_orders',
      builder: (context, state) => const BusinessOrdersScreen(),
    ),
    GoRoute(
      path: RouteNames.marketplaces,
      name: 'marketplaces',
      builder: (context, state) => const MarketplaceConnectScreen(),
    ),
    GoRoute(
      path: RouteNames.earnings,
      name: 'earnings',
      builder: (context, state) => const SimpleEarningsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
