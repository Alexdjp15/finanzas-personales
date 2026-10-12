import 'package:flutter/material.dart';
import '../../domain/services/dashboard_visuals.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Counts up to [value] whenever it changes (microinteraction for key metrics).
class AnimatedCopText extends StatelessWidget {
  const AnimatedCopText({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(Formatters.cop(animated.round()), style: style),
    );
  }
}

/// Container with a subtle border/elevation change on pointer hover.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 14,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovered ? colors.brandAccent : colors.borderSubtle,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

Color creditUsageColor(AppPalette colors, double ratio) {
  switch (DashboardVisuals.creditUsageLevel(ratio)) {
    case CreditUsageLevel.healthy:
      return colors.assetPositive;
    case CreditUsageLevel.moderate:
      return colors.warning;
    case CreditUsageLevel.critical:
      return colors.liabilityNegative;
  }
}

/// Animated bar showing used credit; colour follows the stress thresholds.
class CreditUsageBar extends StatelessWidget {
  const CreditUsageBar({super.key, required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: 8,
          backgroundColor: colors.surfaceCard,
          valueColor: AlwaysStoppedAnimation<Color>(creditUsageColor(colors, animated)),
        ),
      ),
    );
  }
}
