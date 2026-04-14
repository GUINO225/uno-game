import 'package:flutter/material.dart';

class PremiumColors {
  const PremiumColors._();

  static const Color tableGreenDark = Color(0xFF0A3A2A);
  static const Color tableGreenMid = Color(0xFF115F42);
  static const Color panel = Color(0xFFF7F4EC);
  static const Color panelSoft = Color(0xFFEFE8D8);
  static const Color accent = Color(0xFFE2B34B);
  static const Color textDark = Color(0xFF13261D);
}

class TableBackground extends StatelessWidget {
  const TableBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            PremiumColors.tableGreenMid,
            PremiumColors.tableGreenDark,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -50,
            right: -20,
            child: _GlowCircle(
              size: 200,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: _GlowCircle(
              size: 180,
              color: Colors.black.withOpacity(0.12),
            ),
          ),
          Positioned(
            top: 90,
            left: 20,
            child: Transform.rotate(
              angle: -0.24,
              child: const Icon(Icons.style, color: Colors.white24, size: 36),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 26,
            child: Transform.rotate(
              angle: 0.15,
              child: const Icon(Icons.style, color: Colors.white24, size: 32),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class PremiumPanel extends StatelessWidget {
  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PremiumColors.panel.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
