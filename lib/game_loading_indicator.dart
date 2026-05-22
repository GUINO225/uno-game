import 'dart:async';

import 'package:flutter/material.dart';

import 'premium_ui.dart';

class CardSuitLoader extends StatefulWidget {
  const CardSuitLoader({
    super.key,
    this.label = 'Chargement',
    this.progress,
    this.compact = false,
    this.onDark = true,
  });

  final String? label;
  final double? progress;
  final bool compact;
  final bool onDark;

  @override
  State<CardSuitLoader> createState() => _CardSuitLoaderState();
}

class _CardSuitLoaderState extends State<CardSuitLoader> {
  static const Duration _stepDuration = Duration(milliseconds: 620);
  static const List<_LoadingSuit> _suits = <_LoadingSuit>[
    _LoadingSuit('♦', Color(0xFFD7363F)),
    _LoadingSuit('♣', Color(0xFF087D45)),
    _LoadingSuit('♠', Color(0xFF111111)),
    _LoadingSuit('♥', Color(0xFFD7363F)),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stepDuration, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _index = (_index + 1) % _suits.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _LoadingSuit active = _suits[_index];
    final double cardWidth = widget.compact ? 42 : 58;
    final double cardHeight = widget.compact ? 56 : 78;
    final Color textColor = widget.onDark
        ? Colors.white.withValues(alpha: 0.92)
        : PremiumColors.textDark;
    final double? progress = widget.progress?.clamp(0, 1).toDouble();

    return Semantics(
      label: widget.label ?? 'Chargement',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.86, end: 1).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: _SuitCard(
              key: ValueKey<String>(active.symbol),
              suit: active,
              width: cardWidth,
              height: cardHeight,
            ),
          ),
          SizedBox(height: widget.compact ? 8 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(_suits.length, (int i) {
              final _LoadingSuit suit = _suits[i];
              final bool selected = i == _index;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: selected ? 1 : 0.38,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    suit.symbol,
                    style: TextStyle(
                      color: widget.onDark ? Colors.white : suit.color,
                      fontSize: widget.compact ? 12 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (widget.label != null &&
              widget.label!.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: widget.compact ? 8 : 10),
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: widget.compact ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (progress != null) ...<Widget>[
            SizedBox(height: widget.compact ? 8 : 12),
            SizedBox(
              width: widget.compact ? 112 : 170,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: widget.compact ? 5 : 7,
                  value: progress,
                  color: PremiumColors.accentGreen,
                  backgroundColor: widget.onDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : PremiumColors.textDark.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.86),
                fontSize: widget.compact ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuitCard extends StatelessWidget {
  const _SuitCard({
    super.key,
    required this.suit,
    required this.width,
    required this.height,
  });

  final _LoadingSuit suit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFF7FFF9),
            Color(0xFFE8F2EA),
          ],
        ),
        border: Border.all(color: PremiumColors.accent.withValues(alpha: 0.58)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(color: suit.color.withValues(alpha: 0.16), blurRadius: 14),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 7,
            left: 7,
            child: Text(
              suit.symbol,
              style: TextStyle(
                color: suit.color,
                fontSize: width * 0.28,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Center(
            child: Text(
              suit.symbol,
              style: TextStyle(
                color: suit.color,
                fontSize: height * 0.50,
                height: 1,
                fontWeight: FontWeight.w700,
                shadows: <Shadow>[
                  Shadow(
                    color: suit.color.withValues(alpha: 0.18),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(
                suit.symbol,
                style: TextStyle(
                  color: suit.color,
                  fontSize: width * 0.28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSuit {
  const _LoadingSuit(this.symbol, this.color);

  final String symbol;
  final Color color;
}
