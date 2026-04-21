import 'package:flutter/material.dart';

class GameCardAvatarData {
  const GameCardAvatarData({
    required this.rank,
    required this.suitSymbol,
    required this.suitColor,
  });

  final String rank;
  final String suitSymbol;
  final Color suitColor;
}

class GameCardAvatarPalette {
  const GameCardAvatarPalette._();

  static const List<GameCardAvatarData> cards = <GameCardAvatarData>[
    GameCardAvatarData(rank: '2', suitSymbol: '♥', suitColor: Color(0xFFD32F2F)),
    GameCardAvatarData(rank: '2', suitSymbol: '♠', suitColor: Color(0xFF151515)),
    GameCardAvatarData(rank: '2', suitSymbol: '♦', suitColor: Color(0xFFD32F2F)),
    GameCardAvatarData(rank: '2', suitSymbol: '♣', suitColor: Color(0xFF151515)),
  ];

  static GameCardAvatarData fromSeed(String seed, {int salt = 0}) {
    if (seed.isEmpty) {
      return cards[salt % cards.length];
    }
    final int raw = seed.runes.fold<int>(salt, (int value, int rune) => value + rune);
    return cards[raw % cards.length];
  }
}

class GameCardAvatar extends StatelessWidget {
  const GameCardAvatar({
    super.key,
    required this.data,
    this.size = 42,
  });

  final GameCardAvatarData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE6EAF0), width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${data.rank}${data.suitSymbol}',
            style: TextStyle(
              color: data.suitColor,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
