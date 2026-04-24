import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GamePopupButton extends StatelessWidget {
  const GamePopupButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
    this.backgroundColor = const Color(0xFF111111),
    this.foregroundColor = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: const Color(0xFFBDBDBD),
        disabledForegroundColor: const Color(0xFF666666),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
      ),
    );

    if (icon == null) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFBDBDBD),
          disabledForegroundColor: const Color(0xFF666666),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
          ),
        ),
        child: Text(label),
      );
    }

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class GamePopupIconButton extends StatelessWidget {
  const GamePopupIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.expanded = false,
    this.backgroundColor = const Color(0xFF111111),
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool expanded;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget button = Semantics(
      button: true,
      label: semanticLabel,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFBDBDBD),
          disabledForegroundColor: const Color(0xFF666666),
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 22),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class GamePopupDialog extends StatelessWidget {
  const GamePopupDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final String formattedTitle = _popupTitleCase(title);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.92, end: 1),
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formattedTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.1,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              child,
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                ...actions,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _popupTitleCase(String rawTitle) {
  final String normalized = rawTitle.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final String lower = normalized.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

class GameStakeBillsStack extends StatelessWidget {
  const GameStakeBillsStack({
    super.key,
    required this.amount,
  });

  final int amount;

  @override
  Widget build(BuildContext context) {
    final List<double> rotations = <double>[-0.16, -0.06, 0.08];
    final List<Offset> offsets = <Offset>[
      const Offset(-16, 8),
      const Offset(0, 2),
      const Offset(14, -2),
    ];
    return SizedBox(
      width: 190,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: List<Widget>.generate(rotations.length, (int index) {
          return Transform.translate(
            offset: offsets[index],
            child: Transform.rotate(
              angle: rotations[index],
              child: _StakeBillCard(
                amount: amount,
                elevation: 0.24 + (index * 0.06),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StakeBillCard extends StatelessWidget {
  const _StakeBillCard({required this.amount, required this.elevation});

  final int amount;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB8DEBF), width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(elevation),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'MISE',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: const Color(0xFF2D5938),
            ),
          ),
          const Spacer(),
          Text(
            '$amount',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF183D24),
              height: 1,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

enum DrawPenaltyType { two, joker, other }

class DrawPenaltyPopupPanel extends StatelessWidget {
  const DrawPenaltyPopupPanel({
    super.key,
    required this.drawCount,
    required this.penaltyType,
    this.jokerIsRed,
    this.suitSymbol = '♠',
  });

  final int drawCount;
  final DrawPenaltyType penaltyType;
  final bool? jokerIsRed;
  final String suitSymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: min(MediaQuery.of(context).size.width * 0.8, 300),
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'TU PIOCHES',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$drawCount',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 76,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PenaltyCardsStack(
            penaltyType: penaltyType,
            jokerIsRed: jokerIsRed,
            suitSymbol: suitSymbol,
          ),
          const SizedBox(height: 10),
          Text(
            'CARTES',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyCardsStack extends StatelessWidget {
  const _PenaltyCardsStack({
    required this.penaltyType,
    required this.jokerIsRed,
    required this.suitSymbol,
  });

  final DrawPenaltyType penaltyType;
  final bool? jokerIsRed;
  final String suitSymbol;

  @override
  Widget build(BuildContext context) {
    if (penaltyType == DrawPenaltyType.other) {
      return const SizedBox.shrink();
    }
    final bool isJoker = penaltyType == DrawPenaltyType.joker;
    final Color ink = isJoker
        ? ((jokerIsRed ?? false) ? const Color(0xFFC52626) : Colors.black87)
        : ((suitSymbol == '♥' || suitSymbol == '♦') ? const Color(0xFFC52626) : Colors.black87);

    return SizedBox(
      width: 132,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.translate(
            offset: const Offset(-14, 3),
            child: Transform.rotate(
              angle: -0.12,
              child: _OverlayCardFace(
                rank: isJoker ? 'JK' : '2',
                symbol: isJoker ? ((jokerIsRed ?? false) ? '🃏' : '♛') : suitSymbol,
                inkColor: ink,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(14, -3),
            child: Transform.rotate(
              angle: 0.12,
              child: _OverlayCardFace(
                rank: isJoker ? 'JK' : '2',
                symbol: isJoker ? ((jokerIsRed ?? false) ? '♛' : '🃏') : suitSymbol,
                inkColor: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCardFace extends StatelessWidget {
  const _OverlayCardFace({
    required this.rank,
    required this.symbol,
    required this.inkColor,
  });

  final String rank;
  final String symbol;
  final Color inkColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            rank,
            style: TextStyle(
              color: inkColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              symbol,
              style: TextStyle(
                color: inkColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumCardStack extends StatelessWidget {
  const PremiumCardStack({
    super.key,
    required this.count,
    this.suit = '♠',
    this.rankLabel = '2',
    this.inkColor = const Color(0xFF1B9A51),
  });

  final int count;
  final String suit;
  final String rankLabel;
  final Color inkColor;

  @override
  Widget build(BuildContext context) {
    final int total = max(2, min(count, 4));
    return SizedBox(
      width: 145,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (int index = 0; index < total; index++)
            Transform.translate(
              offset: Offset(8.0 * index, -4.0 * index),
              child: Transform.rotate(
                angle: (-0.1) + (index * 0.06),
                child: _MiniCardFace(rankLabel: rankLabel, suit: suit, inkColor: inkColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCardFace extends StatelessWidget {
  const _MiniCardFace({
    required this.rankLabel,
    required this.suit,
    required this.inkColor,
  });

  final String rankLabel;
  final String suit;
  final Color inkColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 106,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E7DC)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 6,
            left: 7,
            child: Text('$rankLabel$suit', style: TextStyle(color: inkColor, fontWeight: FontWeight.w700)),
          ),
          Center(
            child: Text(
              suit,
              style: TextStyle(color: inkColor, fontSize: 30, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
