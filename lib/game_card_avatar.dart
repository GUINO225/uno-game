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
    GameCardAvatarData(rank: 'A', suitSymbol: '♠', suitColor: Color(0xFF13261D)),
    GameCardAvatarData(rank: 'K', suitSymbol: '♥', suitColor: Color(0xFFC62828)),
    GameCardAvatarData(rank: 'Q', suitSymbol: '♦', suitColor: Color(0xFFD84315)),
    GameCardAvatarData(rank: 'J', suitSymbol: '♣', suitColor: Color(0xFF0D47A1)),
    GameCardAvatarData(rank: '10', suitSymbol: '♠', suitColor: Color(0xFF004D40)),
    GameCardAvatarData(rank: '9', suitSymbol: '♥', suitColor: Color(0xFFAD1457)),
    GameCardAvatarData(rank: '8', suitSymbol: '♦', suitColor: Color(0xFFBF360C)),
    GameCardAvatarData(rank: '7', suitSymbol: '♣', suitColor: Color(0xFF1A237E)),
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
    final BorderRadius cardRadius = BorderRadius.circular(size * 0.16);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.3),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: ClipOval(
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: cardRadius,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD8E7DC)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.1,
                    vertical: size * 0.06,
                  ),
                  child: Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topLeft,
                        child: _CardGlyph(
                          rank: data.rank,
                          suitSymbol: data.suitSymbol,
                          color: data.suitColor,
                          fontSize: size * 0.23,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          data.suitSymbol,
                          style: TextStyle(
                            fontSize: size * 0.42,
                            color: data.suitColor.withOpacity(0.95),
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Transform.rotate(
                          angle: 3.14159,
                          child: _CardGlyph(
                            rank: data.rank,
                            suitSymbol: data.suitSymbol,
                            color: data.suitColor,
                            fontSize: size * 0.23,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardGlyph extends StatelessWidget {
  const _CardGlyph({
    required this.rank,
    required this.suitSymbol,
    required this.color,
    required this.fontSize,
  });

  final String rank;
  final String suitSymbol;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: color,
          height: 1,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
        children: <InlineSpan>[
          TextSpan(text: rank),
          TextSpan(
            text: '\n$suitSymbol',
            style: TextStyle(
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
