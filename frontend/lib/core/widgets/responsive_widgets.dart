import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// ResponsiveContainer: Constrains content to max width 1200 on desktop with 48px padding
/// Section 5.4 of Project Specification
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppSpacing.desktopContainerMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    EdgeInsets effectivePadding;
    if (padding != null) {
      effectivePadding = padding!.resolve(Directionality.of(context));
    } else {
      if (width >= AppSpacing.tabletMaxWidth) {
        effectivePadding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.desktopSidePadding,
          vertical: 24.0,
        );
      } else if (width >= AppSpacing.mobileMaxWidth) {
        effectivePadding = const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 20.0,
        );
      } else {
        effectivePadding = const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 16.0,
        );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// ResponsiveGridView: 2 columns on mobile, 3 on tablet, 4 on desktop
/// Section 5.4 of Project Specification
class ResponsiveGridView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 16.0,
    this.crossAxisSpacing = 16.0,
    this.childAspectRatio = 0.75,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    int crossAxisCount;
    if (width >= AppSpacing.tabletMaxWidth) {
      crossAxisCount = 4; // Desktop
    } else if (width >= AppSpacing.mobileMaxWidth) {
      crossAxisCount = 3; // Tablet
    } else {
      crossAxisCount = 2; // Mobile (<480 px)
    }

    return GridView.builder(
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: itemBuilder,
    );
  }
}

/// ResponsiveLayout: renders mobile, tablet, or desktop variant
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppSpacing.tabletMaxWidth && desktop != null) {
      return desktop!;
    }
    if (width >= AppSpacing.mobileMaxWidth && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}
