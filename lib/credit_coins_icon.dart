import 'package:flutter/material.dart';

class CreditCoinsIcon extends StatelessWidget {
  const CreditCoinsIcon({
    super.key,
    this.size = 18,
    this.color = const Color(0xFFFFD45F),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.28, -0.36),
            radius: 0.92,
            colors: <Color>[
              color.withOpacity(0.98),
              color.withOpacity(0.85),
              const Color(0xFFC08A24),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.9),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: size * 0.58,
              height: size * 0.58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x00FFFFFF),
                border: Border.all(
                  color: Colors.white.withOpacity(0.46),
                  width: 0.85,
                ),
              ),
            ),
            Positioned(
              top: size * 0.16,
              child: Container(
                width: size * 0.34,
                height: size * 0.14,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(size * 0.08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
