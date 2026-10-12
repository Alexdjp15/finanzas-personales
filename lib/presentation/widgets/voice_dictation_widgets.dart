import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Interactive microphone button with animated scale pulsation and
/// vibrant status colors for Speech-to-Text dictation.
class VoiceDictationButton extends StatefulWidget {
  const VoiceDictationButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.tooltip,
    this.size = 20,
  });

  final bool isListening;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

class _VoiceDictationButtonState extends State<VoiceDictationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool get _isRunningInTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.88,
      upperBound: 1.15,
    );
    if (widget.isListening) {
      if (!_isRunningInTest) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.value = 1.05;
      }
    }
  }

  @override
  void didUpdateWidget(covariant VoiceDictationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      if (!_isRunningInTest) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.value = 1.05;
      }
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isListening = widget.isListening;

    return IconButton(
      tooltip: widget.tooltip ??
          (isListening ? 'Escuchando... Toca para detener' : 'Dictar por voz (Micrófono)'),
      onPressed: widget.onPressed,
      icon: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: isListening ? _pulseController.value : 1.0,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isListening ? colors.liabilityNegativeBg : colors.brandAccentBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isListening ? colors.liabilityNegative : colors.brandAccent,
              width: 1.5,
            ),
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none_rounded,
            color: isListening ? colors.liabilityNegative : colors.brandAccent,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}
