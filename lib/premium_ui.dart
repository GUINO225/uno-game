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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF06623B),
            Color(0xFF004F2C),
            Color(0xFF013C25),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -70,
            left: -40,
            child: _GlowCircle(
              size: 230,
              color: Colors.black.withOpacity(0.12),
            ),
          ),
          Positioned(
            right: -90,
            bottom: -110,
            child: _GlowCircle(
              size: 260,
              color: Colors.black.withOpacity(0.1),
            ),
          ),
          Positioned(
            top: 62,
            left: -35,
            child: Text(
              '♠',
              style: TextStyle(
                fontSize: 148,
                color: Colors.white.withOpacity(0.055),
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 34,
            child: Text(
              '♣',
              style: TextStyle(
                fontSize: 126,
                color: Colors.white.withOpacity(0.05),
                height: 1,
              ),
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
