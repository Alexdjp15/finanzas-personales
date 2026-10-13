import 'package:flutter/material.dart';
import '../screens/dialogs/ai_copilot_dialog.dart';

/// Interactive glowing floating orb widget representing "Sof.IA",
/// the personal AI financial assistant.
///
/// Features:
/// - Smooth pulse / breathing animation in idle state.
/// - Elastic bounce scale feedback on tap (0.94 -> 1.0).
/// - Diffuse glowing multi-layered shadow with gradient.
/// - Floating badge label and tooltip.
/// - Opens [AiCopilotDialog.show] on tap.
class SofiaFloatingOrb extends StatefulWidget {
  const SofiaFloatingOrb({
    super.key,
    this.onTap,
    this.autoRepeat = true,
  });

  /// Optional tap override (e.g. for testing).
  final VoidCallback? onTap;

  /// Whether the breathing animation should loop infinitely.
  final bool autoRepeat;

  /// In automated widget tests, [WidgetTester.pumpAndSettle] will time out if an
  /// animation loops infinitely. By default, infinite looping is disabled in tests
  /// unless this flag is explicitly set to true.
  static bool enablePulseInTests = false;

  @override
  State<SofiaFloatingOrb> createState() => _SofiaFloatingOrbState();
}

class _SofiaFloatingOrbState extends State<SofiaFloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _haloOpacity;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _haloOpacity = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.autoRepeat &&
        (!isTestEnvironment || SofiaFloatingOrb.enablePulseInTests)) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      AiCopilotDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sof.IA · Tu asesora financiera',
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        key: const Key('sofia_floating_orb'),
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _handleTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer pulsating aura / glow halo
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.40 * _haloOpacity.value),
                            blurRadius: 22,
                            spreadRadius: 4 * _haloOpacity.value,
                          ),
                          BoxShadow(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.35 * _haloOpacity.value),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Main circular orb container
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2563EB), // Electric Blue
                            Color(0xFF7C3AED), // Vibrant Purple
                            Color(0xFF06B6D4), // Cyan Accent
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Subtle radial shimmer layer
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.3, 1.0],
                                ),
                              ),
                            ),
                            // Crisp sparkles icon
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Subtle floating badge at top-right
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Sof.IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
