import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FunnyGameToast {
  FunnyGameToast._();

  static OverlayEntry? _activeEntry;
  static Timer? _hideTimer;
  static bool enabled = true;

  static void show(
    BuildContext context, {
    required String playerName,
    required String message,
    Duration duration = const Duration(seconds: 3),
    Alignment alignment = Alignment.topCenter,
  }) {
    if (!enabled) {
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _hideTimer?.cancel();
    _activeEntry?.remove();

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return IgnorePointer(
          ignoring: true,
          child: SafeArea(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: _FunnyToastCard(playerName: playerName, message: message),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);
    _hideTimer = Timer(duration, () {
      if (_activeEntry == entry) {
        _activeEntry?.remove();
        _activeEntry = null;
      }
    });
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _FunnyToastCard extends StatelessWidget {
  const _FunnyToastCard({required this.playerName, required this.message});

  final String playerName;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * -16),
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              children: <TextSpan>[
                TextSpan(text: playerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ', $message'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
