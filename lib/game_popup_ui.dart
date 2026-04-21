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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5DD978),
        foregroundColor: const Color(0xFF013C25),
        disabledBackgroundColor: const Color(0xFF6C8A74),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          backgroundColor: const Color(0xFF5DD978),
          foregroundColor: const Color(0xFF013C25),
          disabledBackgroundColor: const Color(0xFF6C8A74),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.92, end: 1),
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x40FFFFFF)),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF13261D),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2A463A),
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
