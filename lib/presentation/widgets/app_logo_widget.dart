import 'package:flutter/material.dart';

class AppLogoWidget extends StatelessWidget {
  const AppLogoWidget({
    super.key,
    this.size = 36,
    this.color,
    this.useIsotype = true,
  });

  final double size;
  final Color? color;
  final bool useIsotype;

  @override
  Widget build(BuildContext context) {
    // By default, load the clean isotipo (favicon.png, bar chart & ascending arrow without embedded text)
    final primaryAsset = useIsotype ? 'assets/images/favicon.png' : 'assets/images/logo.png';
    final fallbackAsset = useIsotype ? 'assets/images/logo.png' : 'assets/images/favicon.png';

    return Image.asset(
      primaryAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          fallbackAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.account_balance_wallet_rounded,
            size: size,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}
