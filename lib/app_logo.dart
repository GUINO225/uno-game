import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
  });

  static const String assetPath = 'assets/img/logo.png';

  final double size;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
