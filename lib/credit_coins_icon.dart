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
    final double coinWidth = size;
    final double coinHeight = size * 0.58;
    final Color shadowColor = Colors.black.withOpacity(0.2);
    return SizedBox(
      width: coinWidth + (size * 0.6),
      height: size,
      child: Stack(
        children: <Widget>[
          _coin(
            offset: Offset(size * 0.04, size * 0.34),
            width: coinWidth,
            height: coinHeight,
            shade: color.withOpacity(0.72),
            shadowColor: shadowColor,
          ),
          _coin(
            offset: Offset(size * 0.30, size * 0.20),
            width: coinWidth,
            height: coinHeight,
            shade: color.withOpacity(0.82),
            shadowColor: shadowColor,
          ),
          _coin(
            offset: Offset(size * 0.56, size * 0.06),
            width: coinWidth,
            height: coinHeight,
            shade: color,
            shadowColor: shadowColor,
          ),
        ],
      ),
    );
  }

  Widget _coin({
    required Offset offset,
    required double width,
    required double height,
    required Color shade,
    required Color shadowColor,
  }) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              shade.withOpacity(0.95),
              shade.withOpacity(0.72),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
