import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/routing/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

/// KalaSetu Root Application Widget
class KalaSetuApp extends ConsumerWidget {
  const KalaSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: appRouter,
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: StorageService.largeTextNotifier,
          builder: (context, isLargeText, _) {
            final mediaQuery = MediaQuery.of(context);
            final baseScaler = mediaQuery.textScaler;
            // If large text mode is enabled, scale up to 1.3x minimum
            final targetScaler = isLargeText
                ? TextScaler.linear((baseScaler.scale(1.0) * 1.3).clamp(1.25, 1.35))
                : baseScaler;
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: targetScaler),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
