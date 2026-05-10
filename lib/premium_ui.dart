import 'dart:math';

import 'package:flutter/material.dart';
import 'app_sfx_service.dart';

class PremiumColors {
  const PremiumColors._();

  static const Color tableGreenDark = Color(0xFF0A3A2A);
  static const Color tableGreenMid = Color(0xFF115F42);
  static const Color panel = Color(0xFFF7F4EC);
  static const Color panelSoft = Color(0xFFEFE8D8);
  static const Color accent = Color(0xFFE2B34B);
  static const Color accentGreen = Color(0xFF4CD177);
  static const Color textDark = Color(0xFF13261D);
}

class PremiumCardEffects {
  const PremiumCardEffects._();

  static List<BoxShadow> get bevelShadow => const <BoxShadow>[
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ];

  static BoxDecoration bevelFace({
    required BorderRadius borderRadius,
    required Color color,
    Color borderColor = const Color(0x33000000),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor),
      boxShadow: bevelShadow,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(color, Colors.white, 0.18)!,
          color,
          Color.lerp(color, Colors.black, 0.08)!,
        ],
      ),
    );
  }

  static BoxDecoration bevelBack({
    required BorderRadius borderRadius,
    DecorationImage? image,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius,
      border: Border.all(color: Colors.white70),
      boxShadow: bevelShadow,
      image: image,
      gradient: image == null
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF1D7E54), Color(0xFF14563B)],
            )
          : null,
    );
  }
}


class PremiumGameDecorations {
  const PremiumGameDecorations._();

  static BoxDecoration glassPanel({
    double radius = 18,
    Color? borderColor,
    double opacity = 0.34,
    bool golden = false,
  }) {
    final Color glowColor = golden ? PremiumColors.accent : PremiumColors.accentGreen;
    return BoxDecoration(
      color: const Color(0xFF041E15).withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (golden
                ? PremiumColors.accent.withOpacity(0.42)
                : Colors.white.withOpacity(0.18)),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: glowColor.withOpacity(golden ? 0.11 : 0.08),
          blurRadius: golden ? 24 : 20,
          spreadRadius: 1,
        ),
      ],
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withOpacity(golden ? 0.16 : 0.11),
          const Color(0xFF062719).withOpacity(opacity),
          Colors.black.withOpacity(0.16),
        ],
      ),
    );
  }

  static BoxDecoration goldPill({bool active = false}) {
    return BoxDecoration(
      color: const Color(0xFF061F15).withOpacity(0.78),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: PremiumColors.accent.withOpacity(active ? 0.58 : 0.36),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: PremiumColors.accent.withOpacity(active ? 0.18 : 0.09),
          blurRadius: active ? 18 : 12,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.22),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          PremiumColors.accent.withOpacity(active ? 0.18 : 0.10),
          Colors.white.withOpacity(0.05),
          Colors.black.withOpacity(0.10),
        ],
      ),
    );
  }
}

class PremiumGamePanel extends StatelessWidget {
  const PremiumGamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.radius = 18,
    this.golden = false,
    this.opacity = 0.34,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool golden;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: PremiumGameDecorations.glassPanel(
        radius: radius,
        golden: golden,
        opacity: opacity,
      ),
      child: child,
    );
  }
}

class PremiumDividerLine extends StatelessWidget {
  const PremiumDividerLine({super.key, this.verticalPadding = 8});

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white.withOpacity(0.02),
              PremiumColors.accent.withOpacity(0.32),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumIconButtonShell extends StatelessWidget {
  const PremiumIconButtonShell({
    super.key,
    required this.child,
    this.golden = false,
  });

  final Widget child;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF031C12).withOpacity(0.72),
        border: Border.all(
          color: (golden ? PremiumColors.accent : PremiumColors.accentGreen)
              .withOpacity(golden ? 0.42 : 0.32),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (golden ? PremiumColors.accent : PremiumColors.accentGreen)
                .withOpacity(0.12),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
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
            Color(0xFF0B4D31),
            Color(0xFF062D20),
            Color(0xFF02170F),
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
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PremiumTableTexturePainter()),
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

class GlobalMusicToggleButton extends StatelessWidget {
  const GlobalMusicToggleButton({
    super.key,
    this.margin = const EdgeInsets.only(right: 12, bottom: 12),
    this.premiumSurface = false,
  });

  final EdgeInsets margin;
  final bool premiumSurface;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudioService.instance,
      builder: (BuildContext context, _) {
        final AudioService audio = AudioService.instance;
        final bool enabled = audio.isBackgroundMusicEnabled;
        return Padding(
          padding: margin,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: premiumSurface ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: premiumSurface ? null : BorderRadius.circular(16),
              color: premiumSurface
                  ? const Color(0xFF031C12).withOpacity(0.76)
                  : Colors.black.withOpacity(0.28),
              border: premiumSurface
                  ? Border.all(
                      color: const Color(0xFF72FF9E).withOpacity(0.42),
                      width: 1,
                    )
                  : null,
              boxShadow: premiumSurface
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF4CFF84).withOpacity(0.14),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () async {
                  await audio.toggleBackgroundMusicFromUserGesture();
                },
                customBorder: premiumSurface ? const CircleBorder() : null,
                borderRadius: premiumSurface ? null : BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 19,
                    color: Colors.white.withOpacity(enabled ? 0.95 : 0.72),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ResizableGameTableLayout extends StatefulWidget {
  const ResizableGameTableLayout({
    super.key,
    required this.opponent,
    required this.center,
    required this.player,
    this.footer,
    this.sectionGap = 8,
    this.minPlayerHeight = 220,
    this.maxPlayerHeight = 440,
    this.initialPlayerHeightFactor = 0.46,
    this.compact = false,
    this.desktopImmersive = false,
    this.opponentHeightFactor = 0.26,
    this.centerHeightFactor = 0.28,
    this.playerHeightFactor = 0.46,
    this.minCenterHeight = 120,
    this.safetyMargin = 10,
    this.fixedOpponentHeight,
  });

  final Widget opponent;
  final Widget center;
  final Widget player;
  final Widget? footer;
  final double sectionGap;
  final double minPlayerHeight;
  final double maxPlayerHeight;
  final double initialPlayerHeightFactor;
  final bool compact;
  final bool desktopImmersive;
  final double opponentHeightFactor;
  final double centerHeightFactor;
  final double playerHeightFactor;
  final double minCenterHeight;
  final double safetyMargin;
  /// Quand fourni, la hauteur du bloc adverse est fixe et seul le bloc joueur
  /// est affecté par le redimensionnement.
  final double? fixedOpponentHeight;

  @override
  State<ResizableGameTableLayout> createState() =>
      _ResizableGameTableLayoutState();
}

class _ResizableGameTableLayoutState extends State<ResizableGameTableLayout> {
  double? _manualPlayerHeight;

  static const double _handleHeight = 18;

  @override
  void didUpdateWidget(covariant ResizableGameTableLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_manualPlayerHeight != null &&
        (oldWidget.minPlayerHeight != widget.minPlayerHeight ||
            oldWidget.maxPlayerHeight != widget.maxPlayerHeight)) {
      _manualPlayerHeight = _manualPlayerHeight!.clamp(
        widget.minPlayerHeight,
        widget.maxPlayerHeight,
      ).toDouble();
    }
  }

  void _resetHeight() {
    if (_manualPlayerHeight == null) {
      return;
    }
    setState(() => _manualPlayerHeight = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double safeMaxHeight = min(
          widget.maxPlayerHeight,
          max(widget.minPlayerHeight, availableHeight * 0.62),
        );
        final double automaticHeight =
            (availableHeight * widget.initialPlayerHeightFactor)
                .clamp(
                  widget.minPlayerHeight,
                  safeMaxHeight,
                )
                .toDouble();
        final double playerHeight = (_manualPlayerHeight ?? automaticHeight)
            .clamp(
              widget.minPlayerHeight,
              safeMaxHeight,
            )
            .toDouble();
        final double safeGap = max(2, widget.sectionGap);
        final double reservedFooter =
            widget.footer == null ? 0 : (widget.sectionGap + 42);
        final double availableForSections = max(
          0,
          availableHeight - reservedFooter - (safeGap * 2),
        );
        final double combinedFactor =
            widget.opponentHeightFactor +
            widget.centerHeightFactor +
            widget.playerHeightFactor;
        final double normalizedCenterFactor = combinedFactor == 0
            ? 0.28
            : widget.centerHeightFactor / combinedFactor;
        final double centerBandHeight = max(
          widget.minCenterHeight,
          availableForSections * normalizedCenterFactor,
        );
        final double opponentBandHeight;
        final double actualCenterHeight;
        if (widget.fixedOpponentHeight != null) {
          opponentBandHeight = widget.fixedOpponentHeight!;
          final double budgetForCenterAndPlayer =
              max(0, availableForSections - opponentBandHeight);
          actualCenterHeight = max(
            widget.minCenterHeight,
            budgetForCenterAndPlayer * (widget.centerHeightFactor /
                (widget.centerHeightFactor + widget.playerHeightFactor)),
          );
        } else {
          opponentBandHeight = max(
            90,
            availableForSections - centerBandHeight - playerHeight.clamp(widget.minPlayerHeight, max(widget.minPlayerHeight, availableForSections - centerBandHeight - widget.safetyMargin)),
          );
          actualCenterHeight = centerBandHeight;
        }
        final double maxPlayerFromBudget = max(
          widget.minPlayerHeight,
          availableForSections - actualCenterHeight - opponentBandHeight - widget.safetyMargin,
        );
        final double constrainedPlayerHeight = min(playerHeight, maxPlayerFromBudget);

        final bool immersive = widget.desktopImmersive;
        final double opponentFlex = immersive ? 1.08 : 0.72;
        final double centerFlex = immersive ? 1.0 : 1.0;
        final double playerFlex = immersive ? 2.02 : 1.0;

        Widget centerStage = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: immersive ? max(2.0, widget.sectionGap * 0.45) : widget.sectionGap,
              ),
              child: Center(child: widget.center),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _TableResizeHandle(
                height: _handleHeight,
                compact: widget.compact,
                onDoubleTap: _resetHeight,
                onVerticalDragUpdate: (DragUpdateDetails details) {
                  setState(() {
                    final double nextPlayerHeight = playerHeight - details.delta.dy;
                    _manualPlayerHeight = nextPlayerHeight
                        .clamp(
                          widget.minPlayerHeight,
                          safeMaxHeight,
                        )
                        .toDouble();
                  });
                },
              ),
            ),
          ],
        );

        if (immersive) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                flex: (opponentFlex * 100).round(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: widget.opponent,
                ),
              ),
              Flexible(
                flex: (centerFlex * 100).round(),
                child: centerStage,
              ),
              Flexible(
                flex: (playerFlex * 100).round(),
                child: widget.player,
              ),
              if (widget.footer != null) ...<Widget>[
                SizedBox(height: widget.sectionGap),
                widget.footer!,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: opponentBandHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: widget.opponent,
              ),
            ),
            SizedBox(height: safeGap),
            SizedBox(
              height: actualCenterHeight,
              child: centerStage,
            ),
            SizedBox(height: safeGap),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: constrainedPlayerHeight,
              child: widget.player,
            ),
            if (widget.footer != null) ...<Widget>[
              SizedBox(height: widget.sectionGap),
              widget.footer!,
            ],
          ],
        );
      },
    );
  }
}

class _TableResizeHandle extends StatelessWidget {
  const _TableResizeHandle({
    required this.height,
    required this.compact,
    required this.onDoubleTap,
    required this.onVerticalDragUpdate,
  });

  final double height;
  final bool compact;
  final VoidCallback onDoubleTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: onDoubleTap,
        onVerticalDragUpdate: onVerticalDragUpdate,
        child: SizedBox(
          height: height,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: compact ? 52 : 68,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.white.withOpacity(0.18),
                    const Color(0xFFE8C65D).withOpacity(0.58),
                    Colors.white.withOpacity(0.18),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFE8C65D).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _PremiumTableTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint felt = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 0.7;
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 9), felt);
    }
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.78,
        colors: <Color>[
          const Color(0xFF7CF7A9).withOpacity(0.055),
          Colors.transparent,
          Colors.black.withOpacity(0.18),
        ],
        stops: const <double>[0, 0.48, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
