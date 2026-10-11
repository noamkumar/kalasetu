import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/motifs/warli_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    if (!StorageService.isLanguageChosen) {
      context.go(RouteNames.language);
    } else if (!StorageService.isOnboardingCompleted) {
      context.go(RouteNames.onboarding);
    } else if (!StorageService.isLoggedIn) {
      context.go(RouteNames.authPhone);
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Warli motif watermark
          Positioned.fill(
            child: CustomPaint(
              painter: const WarliWatermarkPainter(color: AppColors.primaryDark),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/app_logo_transparent.png',
                    width: 140,
                    height: 140,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.spa,
                      size: 96,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'KalaSetu',
                    style: AppTextStyles.displayLarge(color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bridging Artisans to the World',
                    style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
