import 'package:flutter/material.dart';

class GameCardAvatarData {
  const GameCardAvatarData({
    required this.rank,
    required this.suit,
    required this.suitSymbol,
    required this.suitColor,
  });

  final String rank;
  final String suit;
  final String suitSymbol;
  final Color suitColor;
}

class GameCardAvatarPalette {
  const GameCardAvatarPalette._();

  static const List<String> ranks = <String>[
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
    'A',
  ];

  static const List<String> suits = <String>[
    'spades',
    'hearts',
    'clubs',
    'diamonds',
  ];

  static const Map<String, String> _suitSymbols = <String, String>{
    'spades': '♠',
    'hearts': '♥',
    'clubs': '♣',
    'diamonds': '♦',
  };

  static const Map<String, Color> _suitColors = <String, Color>{
    'spades': Color(0xFF151515),
    'clubs': Color(0xFF151515),
    'hearts': Color(0xFFD32F2F),
    'diamonds': Color(0xFFD32F2F),
  };

  static GameCardAvatarData fromSeed(String seed, {int salt = 0}) {
    final int hash = seed.isEmpty
        ? salt
        : seed.runes.fold<int>(salt, (int value, int rune) => value + rune);
    final String rank = ranks[hash.abs() % ranks.length];
    final String suit = suits[(hash.abs() ~/ ranks.length) % suits.length];
    return fromSelection(rank: rank, suit: suit);
  }

  static GameCardAvatarData fromSelection({
    required String rank,
    required String suit,
  }) {
    final String safeRank = ranks.contains(rank) ? rank : ranks.first;
    final String safeSuit = suits.contains(suit) ? suit : suits.first;
    return GameCardAvatarData(
      rank: safeRank,
      suit: safeSuit,
      suitSymbol: _suitSymbols[safeSuit] ?? '♠',
      suitColor: _suitColors[safeSuit] ?? const Color(0xFF151515),
    );
  }
}

class GameCardAvatar extends StatelessWidget {
  const GameCardAvatar({
    super.key,
    required this.data,
    this.size = 42,
  });

  factory GameCardAvatar.fromSelection({
    Key? key,
    required String rank,
    required String suit,
    double size = 42,
  }) {
    return GameCardAvatar(
      key: key,
      size: size,
      data: GameCardAvatarPalette.fromSelection(rank: rank, suit: suit),
    );
  }

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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
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
        ),
      ),
    );
  }
}
