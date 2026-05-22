import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GinoPopupStyle {
  static const Color screenGreen = Color(0xFF005A2F);
  static const Color popupGreen = Color(0xFF003B22);
  static const Color accentGreen = Color(0xFF13C76B);
  static const Color borderGreen = Color(0x667CC79A);
  static const Color cardWhite = Color(0xFFF7F7F5);
  static const Color textWhite = Color(0xFFFDFDFD);
  static const Color amountGreen = Color(0xFF004928);
  static const Color suitRed = Color(0xFFFF1E12);
  static const Color suitBlack = Color(0xFF111111);
  static const Color casinoGold = Color(0xFFFFD36A);
  static const Color premiumDeepGreen = Color(0xFF012A1B);
  static const Color premiumNeonGreen = Color(0xFF27F28A);

  static const double popupRadius = 16;
  static const double buttonRadius = 12;
  static const FontWeight titleWeight = FontWeight.w300;
  static const FontWeight textWeight = FontWeight.w300;
  static const FontWeight buttonWeight = FontWeight.w300;

  static TextStyle baseText({
    double fontSize = 18,
    FontWeight fontWeight = textWeight,
    Color color = textWhite,
    double height = 1.22,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

class GinoPopupFrame extends StatelessWidget {
  const GinoPopupFrame({
    super.key,
    required this.child,
    this.titleTag,
    this.width,
    this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 14),
    this.showTitleTag = true,
    this.isPremium = false,
  });

  final Widget child;
  final String? titleTag;
  final double? width;
  final EdgeInsets padding;
  final bool showTitleTag;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final double resolvedWidth =
        width ?? math.min(MediaQuery.of(context).size.width * 0.8, 330);
    final bool shouldShowTitle =
        showTitleTag && titleTag != null && titleTag!.trim().isNotEmpty;
    final double radius = isPremium ? 28 : GinoPopupStyle.popupRadius;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            width: resolvedWidth,
            padding: padding,
            decoration: BoxDecoration(
              color: isPremium ? null : GinoPopupStyle.popupGreen,
              gradient: isPremium
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        GinoPopupStyle.premiumDeepGreen.withOpacity(0.96),
                        GinoPopupStyle.popupGreen.withOpacity(0.92),
                        const Color(0xFF001D13).withOpacity(0.97),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isPremium
                    ? GinoPopupStyle.premiumNeonGreen.withOpacity(0.72)
                    : GinoPopupStyle.borderGreen,
                width: isPremium ? 1.15 : 1,
              ),
              boxShadow: isPremium
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.48),
                        blurRadius: 34,
                        offset: const Offset(0, 22),
                      ),
                      BoxShadow(
                        color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                          0.18,
                        ),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
          if (shouldShowTitle)
            Positioned(
              top: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isPremium
                      ? GinoPopupStyle.premiumDeepGreen.withOpacity(0.96)
                      : GinoPopupStyle.accentGreen,
                  borderRadius: BorderRadius.circular(isPremium ? 999 : 8),
                  border: isPremium
                      ? Border.all(
                          color: GinoPopupStyle.casinoGold.withOpacity(0.9),
                          width: 1,
                        )
                      : null,
                  boxShadow: isPremium
                      ? <BoxShadow>[
                          BoxShadow(
                            color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                              0.22,
                            ),
                            blurRadius: 18,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _popupTitleCase(titleTag!),
                  style: GinoPopupStyle.baseText(
                    fontSize: 17,
                    fontWeight: GinoPopupStyle.titleWeight,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
        ],
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

class GinoPopupButton extends StatelessWidget {
  const GinoPopupButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isPremium = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      height: 44,
      decoration: isPremium
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius),
              boxShadow: isPrimary
                  ? <BoxShadow>[
                      BoxShadow(
                        color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                          0.34,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            )
          : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isPremium
              ? (isPrimary
                    ? GinoPopupStyle.premiumNeonGreen.withOpacity(0.82)
                    : const Color(0xFF021D14).withOpacity(0.88))
              : (isPrimary
                    ? GinoPopupStyle.screenGreen.withOpacity(0.70)
                    : GinoPopupStyle.screenGreen.withOpacity(0.45)),
          side: BorderSide(
            color: isPremium
                ? (isPrimary
                      ? GinoPopupStyle.casinoGold.withOpacity(0.58)
                      : GinoPopupStyle.borderGreen.withOpacity(0.95))
                : GinoPopupStyle.borderGreen,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius),
          ),
          foregroundColor: GinoPopupStyle.textWhite,
        ),
        child: Text(
          label,
          style: GinoPopupStyle.baseText(
            fontSize: 15,
            fontWeight: GinoPopupStyle.buttonWeight,
          ),
        ),
      ),
    );
  }
}

class GinoDisabledPopupButton extends StatelessWidget {
  const GinoDisabledPopupButton({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: GinoPopupButton(label: label, onPressed: null),
    );
  }
}

class GinoAmountCard extends StatelessWidget {
  const GinoAmountCard({
    super.key,
    required this.amount,
    this.selected = false,
    this.onTap,
    this.width = 56,
    this.height = 84,
    this.isPremium = false,
  });

  final int amount;
  final bool selected;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      width: width + 10,
      height: height + 10,
      decoration: isPremium && selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GinoPopupStyle.premiumNeonGreen.withOpacity(0.34),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (!isPremium) ...<Widget>[
            Transform.rotate(
              angle: -0.05,
              child: Transform.translate(
                offset: const Offset(-4, 4),
                child: _BaseCardFace(
                  width: width,
                  height: height,
                  opacity: 0.86,
                ),
              ),
            ),
            Transform.rotate(
              angle: 0.04,
              child: Transform.translate(
                offset: const Offset(4, 3),
                child: _BaseCardFace(
                  width: width,
                  height: height,
                  opacity: 0.91,
                ),
              ),
            ),
          ],
          Transform.rotate(
            angle: selected ? -0.02 : 0.01,
            child: _BaseCardFace(
              width: width,
              height: height,
              selected: selected,
              isPremium: isPremium,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (isPremium) ...<Widget>[
                    Icon(
                      Icons.monetization_on_rounded,
                      color: GinoPopupStyle.casinoGold.withOpacity(0.92),
                      size: width >= 72 ? 22 : 18,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '$amount',
                    style: GinoPopupStyle.baseText(
                      color: GinoPopupStyle.amountGreen,
                      fontSize: width >= 72 ? 25 : 19,
                      fontWeight: GinoPopupStyle.titleWeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: selected ? (isPremium ? 1.07 : 1.05) : 1,
        child: card,
      ),
    );
  }
}

class GinoSpecialFinishBonusPopup extends StatelessWidget {
  const GinoSpecialFinishBonusPopup({
    super.key,
    required this.title,
    required this.message,
    required this.cardLabel,
    required this.cardSuitSymbol,
    required this.deltaLabel,
    required this.onContinue,
    this.detailLines = const <String>[],
    this.isPositive = false,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final String cardLabel;
  final String cardSuitSymbol;
  final String deltaLabel;
  final VoidCallback onContinue;
  final List<String> detailLines;
  final bool isPositive;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor = isPositive
        ? const Color(0xFF13C76B)
        : const Color(0xFFE16A6A);
    return GinoPopupFrame(
      titleTag: title,
      isPremium: true,
      width: math.min(MediaQuery.of(context).size.width * 0.84, 350),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: GinoPopupStyle.baseText(fontSize: 17),
          ),
          const SizedBox(height: 14),
          _BaseCardFace(
            width: 104,
            height: 146,
            opacity: 0.96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  cardLabel,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cardSuitSymbol,
                  style: TextStyle(
                    color: (cardSuitSymbol == '♥' || cardSuitSymbol == '♦')
                        ? const Color(0xFFC52626)
                        : Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              deltaLabel,
              textAlign: TextAlign.center,
              style: GinoPopupStyle.baseText(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: deltaColor,
              ),
            ),
          ),
          if (detailLines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              detailLines.join('\n'),
              textAlign: TextAlign.center,
              style: GinoPopupStyle.baseText(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (secondaryActionLabel == null || onSecondaryAction == null)
            SizedBox(
              width: double.infinity,
              child: GinoPopupButton(
                label: 'Continuer',
                onPressed: onContinue,
                isPremium: true,
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: GinoPopupButton(
                    label: 'Quitter',
                    isPrimary: false,
                    isPremium: true,
                    onPressed: onContinue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GinoPopupButton(
                    label: secondaryActionLabel!,
                    isPremium: true,
                    onPressed: onSecondaryAction,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BaseCardFace extends StatelessWidget {
  const _BaseCardFace({
    required this.width,
    required this.height,
    this.opacity = 1,
    this.selected = false,
    this.isPremium = false,
    this.child,
  });

  final double width;
  final double height;
  final double opacity;
  final bool selected;
  final bool isPremium;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GinoPopupStyle.cardWhite.withOpacity(opacity),
        borderRadius: BorderRadius.circular(isPremium ? 13 : 7),
        border: selected
            ? Border.all(
                color: isPremium
                    ? GinoPopupStyle.casinoGold
                    : GinoPopupStyle.accentGreen,
                width: isPremium ? 1.8 : 2,
              )
            : (isPremium
                  ? Border.all(
                      color: GinoPopupStyle.casinoGold.withOpacity(0.24),
                      width: 0.8,
                    )
                  : null),
        boxShadow: isPremium
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(selected ? 0.28 : 0.18),
                  blurRadius: selected ? 16 : 8,
                  offset: Offset(0, selected ? 9 : 5),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class GinoSuitCard extends StatelessWidget {
  const GinoSuitCard({
    super.key,
    required this.suit,
    this.onTap,
    this.selected = false,
    this.width = 64,
    this.height = 92,
  });

  final String suit;
  final VoidCallback? onTap;
  final bool selected;
  final double width;
  final double height;

  String get symbol {
    switch (suit.toLowerCase()) {
      case '♥':
      case 'hearts':
      case 'heart':
      case 'coeur':
      case 'cœur':
        return '♥';
      case '♠':
      case 'spades':
      case 'spade':
      case 'pique':
        return '♠';
      case '♣':
      case 'clubs':
      case 'club':
      case 'trefle':
      case 'trèfle':
        return '♣';
      case '♦':
      case 'diamonds':
      case 'diamond':
      case 'carreau':
        return '♦';
      default:
        return suit;
    }
  }

  Color get symbolColor {
    final String glyph = symbol;
    if (glyph == '♥' || glyph == '♦') {
      return GinoPopupStyle.suitRed;
    }
    return GinoPopupStyle.suitBlack;
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: GinoPopupStyle.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: GinoPopupStyle.accentGreen, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: GinoPopupStyle.baseText(
          color: symbolColor,
          fontSize: math.min(height * 0.58, 74),
          fontWeight: GinoPopupStyle.titleWeight,
          height: 1,
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: card,
    );
  }
}

class GinoStackedDrawCards extends StatelessWidget {
  const GinoStackedDrawCards({
    super.key,
    required this.rank,
    required this.suit,
    required this.count,
  });

  final String rank;
  final String suit;
  final int count;

  @override
  Widget build(BuildContext context) {
    final int totalCards = count <= 1 ? 2 : 3;
    final String symbol = _normalizeSuitSymbol(suit);
    final Color ink = _suitColor(symbol);

    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (int i = 0; i < totalCards; i++)
            Transform.translate(
              offset: Offset(-12 + (i * 12), 5 + (i * 2)),
              child: Transform.rotate(
                angle: -0.10 + (i * 0.11),
                child: GinoSuitCard(suit: symbol, width: 64, height: 92),
              ),
            ),
          Positioned(
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 64,
                height: 92,
                decoration: BoxDecoration(
                  color: GinoPopupStyle.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              rank,
                              style: GinoPopupStyle.baseText(
                                color: ink,
                                fontSize: 16,
                                fontWeight: GinoPopupStyle.titleWeight,
                                height: 1,
                              ),
                            ),
                            Text(
                              symbol,
                              style: GinoPopupStyle.baseText(
                                color: ink,
                                fontSize: 17,
                                fontWeight: GinoPopupStyle.titleWeight,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        symbol,
                        style: GinoPopupStyle.baseText(
                          color: ink,
                          fontSize: 30,
                          fontWeight: GinoPopupStyle.titleWeight,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GinoBetProposalPopup extends StatelessWidget {
  const GinoBetProposalPopup({
    super.key,
    required this.opponentName,
    required this.presetAmounts,
    required this.selectedAmount,
    required this.amountController,
    required this.onSelectAmount,
    required this.onAmountChanged,
    required this.validationError,
    required this.onCancel,
    required this.onValidate,
  });

  final String opponentName;
  final List<int> presetAmounts;
  final int? selectedAmount;
  final TextEditingController amountController;
  final ValueChanged<int> onSelectAmount;
  final ValueChanged<String> onAmountChanged;
  final String? validationError;
  final VoidCallback onCancel;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    void adjustAmount(int delta) {
      final int current = int.tryParse(amountController.text.trim()) ?? 0;
      final int next = math.max(0, current + delta);
      amountController.text = next.toString();
      amountController.selection = TextSelection.collapsed(
        offset: amountController.text.length,
      );
      onAmountChanged(amountController.text);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double scale, Widget? child) {
        return Opacity(
          opacity: ((scale - 0.96) / 0.04).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GinoPopupFrame(
        titleTag: 'Montant du pari',
        isPremium: true,
        padding: const EdgeInsets.fromLTRB(18, 30, 18, 16),
        width: math.min(MediaQuery.of(context).size.width * 0.86, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CenteredRichText(
              fontSize: 17,
              spans: <TextSpan>[
                const TextSpan(text: 'Propose un pari à '),
                TextSpan(
                  text: opponentName,
                  style: GinoPopupStyle.baseText(
                    color: GinoPopupStyle.casinoGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: presetAmounts
                  .map(
                    (int amount) => GinoAmountCard(
                      amount: amount,
                      selected: selectedAmount == amount,
                      onTap: () => onSelectAmount(amount),
                      isPremium: true,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: GinoPopupStyle.casinoGold.withOpacity(0.28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF1F1504).withOpacity(0.92),
                    const Color(0xFF06170F).withOpacity(0.88),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: GinoPopupStyle.casinoGold.withOpacity(0.18),
                    blurRadius: 24,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  _GinoStakeAdjustButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => adjustAmount(-50),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GinoPopupStyle.baseText(
                        fontSize: 16,
                        color: GinoPopupStyle.casinoGold,
                        fontWeight: GinoPopupStyle.titleWeight,
                      ),
                      onChanged: onAmountChanged,
                      decoration: InputDecoration(
                        hintText: 'Montant du pari',
                        hintStyle: GinoPopupStyle.baseText(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                        prefixIcon: Icon(
                          Icons.monetization_on_rounded,
                          color: GinoPopupStyle.casinoGold.withOpacity(0.92),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.26),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: GinoPopupStyle.casinoGold.withOpacity(0.42),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: GinoPopupStyle.casinoGold.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GinoStakeAdjustButton(
                    icon: Icons.add_rounded,
                    onPressed: () => adjustAmount(50),
                  ),
                ],
              ),
            ),
            if (validationError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                validationError!,
                style: GinoPopupStyle.baseText(
                  fontSize: 12,
                  color: const Color(0xFFFFC9C9),
                  fontWeight: GinoPopupStyle.titleWeight,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: GinoPopupButton(
                    label: 'Annuler',
                    onPressed: onCancel,
                    isPrimary: false,
                    isPremium: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GinoPopupButton(
                    label: 'Valider',
                    onPressed: onValidate,
                    isPremium: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GinoStakeAdjustButton extends StatefulWidget {
  const _GinoStakeAdjustButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_GinoStakeAdjustButton> createState() => _GinoStakeAdjustButtonState();
}

class _GinoStakeAdjustButtonState extends State<_GinoStakeAdjustButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.92 : (_hovered ? 1.06 : 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  GinoPopupStyle.casinoGold.withOpacity(0.96),
                  const Color(0xFFFF7A24),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GinoPopupStyle.casinoGold.withOpacity(
                    _hovered ? 0.42 : 0.25,
                  ),
                  blurRadius: _hovered ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              onPressed: widget.onPressed,
              constraints: const BoxConstraints.tightFor(width: 42, height: 42),
              padding: EdgeInsets.zero,
              icon: Icon(widget.icon, color: const Color(0xFF231300), size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class GinoIncomingBetPopup extends StatelessWidget {
  const GinoIncomingBetPopup({
    super.key,
    required this.proposerName,
    required this.amount,
    required this.onAccept,
    required this.onRefuse,
    this.acceptEnabled = true,
  });

  final String proposerName;
  final int amount;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final bool acceptEnabled;

  @override
  Widget build(BuildContext context) {
    return PremiumBetProposalPopup(
      proposerName: proposerName,
      amount: amount,
      onAccept: onAccept,
      onReject: onRefuse,
      acceptEnabled: acceptEnabled,
    );
  }
}

class PremiumBetProposalPopup extends StatefulWidget {
  const PremiumBetProposalPopup({
    super.key,
    required this.proposerName,
    required this.amount,
    required this.onAccept,
    required this.onReject,
    this.acceptEnabled = true,
  });

  final String proposerName;
  final int amount;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool acceptEnabled;

  @override
  State<PremiumBetProposalPopup> createState() =>
      _PremiumBetProposalPopupState();
}

class _PremiumBetProposalPopupState extends State<PremiumBetProposalPopup>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..repeat(reverse: true);
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double popupWidth = math.min(screenSize.width * 0.86, 420);
    final double horizontalPadding = screenSize.width < 360 ? 14 : 18;
    final double glowSize = math.min(popupWidth * 0.64, 250);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withOpacity(0.58)),
        ),
        Center(
          child: FadeTransition(
            opacity: _entrance,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(_entrance),
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (BuildContext context, Widget? child) {
                  final double pulse = Curves.easeInOut.transform(
                    _glowController.value,
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      Container(
                        width: popupWidth,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          34,
                          horizontalPadding,
                          18,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              GinoPopupStyle.premiumDeepGreen.withOpacity(0.84),
                              GinoPopupStyle.popupGreen.withOpacity(0.78),
                              const Color(0xFF00160F).withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                              0.72 + (pulse * 0.16),
                            ),
                            width: 1.25,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.64),
                              blurRadius: 42,
                              spreadRadius: 2,
                              offset: const Offset(0, 25),
                            ),
                            BoxShadow(
                              color: GinoPopupStyle.premiumNeonGreen
                                  .withOpacity(0.18 + (pulse * 0.1)),
                              blurRadius: 38,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Container(
                                      width: glowSize * (0.86 + pulse * 0.08),
                                      height: glowSize * (0.86 + pulse * 0.08),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: <Color>[
                                            GinoPopupStyle.casinoGold
                                                .withOpacity(
                                                  0.38 + pulse * 0.12,
                                                ),
                                            GinoPopupStyle.casinoGold
                                                .withOpacity(0.12),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: glowSize * 0.18,
                                      right: popupWidth * 0.28,
                                      child: _PremiumGlowDot(
                                        size: 5,
                                        opacity: 0.35 + pulse * 0.3,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: glowSize * 0.18,
                                      left: popupWidth * 0.3,
                                      child: _PremiumGlowDot(
                                        size: 4,
                                        opacity: 0.28 + pulse * 0.26,
                                      ),
                                    ),
                                    _PremiumAmountCard(amount: widget.amount),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.proposerName,
                                  textAlign: TextAlign.center,
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: GinoPopupStyle.textWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'propose une mise de',
                                  textAlign: TextAlign.center,
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 17,
                                    fontWeight: GinoPopupStyle.textWeight,
                                    color: GinoPopupStyle.textWhite.withOpacity(
                                      0.88,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.amount}',
                                  textAlign: TextAlign.center,
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 17,
                                    fontWeight: GinoPopupStyle.titleWeight,
                                    color: GinoPopupStyle.casinoGold,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _PremiumBetActionButton(
                                        label: 'REFUSER',
                                        onPressed: widget.onReject,
                                        isAccept: false,
                                        pulse: pulse,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PremiumBetActionButton(
                                        label: 'ACCEPTER',
                                        onPressed: widget.acceptEnabled
                                            ? widget.onAccept
                                            : null,
                                        isAccept: true,
                                        pulse: pulse,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Vous acceptez de parier ${widget.amount} jetons',
                                  textAlign: TextAlign.center,
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 17,
                                    fontWeight: GinoPopupStyle.textWeight,
                                    color: GinoPopupStyle.textWhite.withOpacity(
                                      0.56,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -17,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: GinoPopupStyle.premiumDeepGreen.withOpacity(
                              0.96,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: GinoPopupStyle.casinoGold.withOpacity(
                                0.88,
                              ),
                              width: 1,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: GinoPopupStyle.premiumNeonGreen
                                    .withOpacity(0.24),
                                blurRadius: 18,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.34),
                                blurRadius: 12,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            'Proposition',
                            style: GinoPopupStyle.baseText(
                              fontSize: 17,
                              fontWeight: GinoPopupStyle.titleWeight,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumAmountCard extends StatelessWidget {
  const _PremiumAmountCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      height: 136,
      decoration: BoxDecoration(
        color: GinoPopupStyle.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GinoPopupStyle.casinoGold.withOpacity(0.72),
          width: 1.15,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GinoPopupStyle.casinoGold.withOpacity(0.28),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.monetization_on_rounded,
            color: GinoPopupStyle.casinoGold.withOpacity(0.95),
            size: 22,
          ),
          const SizedBox(height: 7),
          Text(
            '$amount',
            style: GinoPopupStyle.baseText(
              color: GinoPopupStyle.casinoGold,
              fontSize: 25,
              fontWeight: GinoPopupStyle.titleWeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBetActionButton extends StatelessWidget {
  const _PremiumBetActionButton({
    required this.label,
    required this.onPressed,
    required this.isAccept,
    required this.pulse,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isAccept;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color fillColor = isAccept
        ? GinoPopupStyle.premiumNeonGreen.withOpacity(
            disabled ? 0.34 : 0.82 + pulse * 0.08,
          )
        : const Color(0xFF021D14).withOpacity(0.9);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius),
            boxShadow: isAccept && !disabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                        0.26 + pulse * 0.18,
                      ),
                      blurRadius: 18 + pulse * 8,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: fillColor,
              side: BorderSide(
                color: isAccept
                    ? GinoPopupStyle.casinoGold.withOpacity(0.58)
                    : GinoPopupStyle.casinoGold.withOpacity(0.48),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  GinoPopupStyle.buttonRadius,
                ),
              ),
              foregroundColor: GinoPopupStyle.textWhite,
            ),
            child: Text(
              label,
              style: GinoPopupStyle.baseText(
                fontSize: 15,
                fontWeight: GinoPopupStyle.buttonWeight,
              ),
            ),
          ),
        ),
        if (isAccept)
          Positioned(
            top: -13,
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GinoPopupStyle.premiumDeepGreen.withOpacity(0.96),
                border: Border.all(
                  color: GinoPopupStyle.casinoGold.withOpacity(0.78),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: GinoPopupStyle.premiumNeonGreen.withOpacity(
                      disabled ? 0.1 : 0.25 + pulse * 0.12,
                    ),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: disabled
                    ? GinoPopupStyle.textWhite.withOpacity(0.46)
                    : GinoPopupStyle.casinoGold.withOpacity(0.96),
                size: 15,
              ),
            ),
          ),
      ],
    );
  }
}

class _PremiumGlowDot extends StatelessWidget {
  const _PremiumGlowDot({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GinoPopupStyle.casinoGold.withOpacity(opacity),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GinoPopupStyle.casinoGold.withOpacity(opacity),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class GinoDrawPenaltyPopup extends StatelessWidget {
  const GinoDrawPenaltyPopup({
    super.key,
    required this.cardsToDraw,
    required this.rank,
    required this.suit,
    this.title = 'Piochez',
    this.showButton = false,
    this.buttonLabel = 'Piocher',
    this.onDrawPressed,
  });

  final int cardsToDraw;
  final String rank;
  final String suit;
  final String title;
  final bool showButton;
  final String buttonLabel;
  final VoidCallback? onDrawPressed;

  @override
  Widget build(BuildContext context) {
    final String bottomLabel = cardsToDraw == 1
        ? '1 carte'
        : '$cardsToDraw cartes';

    return GinoPopupFrame(
      width: math.min(MediaQuery.of(context).size.width * 0.78, 320),
      isPremium: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      showTitleTag: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: GinoPopupStyle.baseText(
              fontSize: 18,
              fontWeight: GinoPopupStyle.titleWeight,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          GinoStackedDrawCards(rank: rank, suit: suit, count: cardsToDraw),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GinoPopupStyle.accentGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bottomLabel,
              style: GinoPopupStyle.baseText(
                fontSize: 16,
                fontWeight: GinoPopupStyle.titleWeight,
              ),
            ),
          ),
          if (showButton) ...<Widget>[
            const SizedBox(height: 14),
            GinoPopupButton(
              label: buttonLabel,
              onPressed: onDrawPressed,
              isPremium: true,
            ),
          ],
        ],
      ),
    );
  }
}

class PremiumJockzrDrawPopup extends StatefulWidget {
  const PremiumJockzrDrawPopup({
    super.key,
    required this.opponentName,
    required this.onDraw,
    this.cardsToDraw = 8,
    this.autoDrawSeconds,
    this.showTimer = true,
  });

  final String opponentName;
  final VoidCallback onDraw;
  final int cardsToDraw;
  final int? autoDrawSeconds;
  final bool showTimer;

  @override
  State<PremiumJockzrDrawPopup> createState() => _PremiumJockzrDrawPopupState();
}

class _PremiumJockzrDrawPopupState extends State<PremiumJockzrDrawPopup>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double popupWidth = math.min(screenSize.width * 0.88, 430);
    final double compactFactor = screenSize.height < 720 ? 0.88 : 1.0;
    final String normalizedName = widget.opponentName.trim().isEmpty
        ? 'Adversaire'
        : widget.opponentName.trim();
    final int displayedCardsToDraw = widget.cardsToDraw;
    final int timerSeconds = widget.autoDrawSeconds ?? 10;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withOpacity(0.62)),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ambientController,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: _PremiumDrawTwoParticlePainter(
                  _ambientController.value,
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _introController,
                _ambientController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final double glowPulse =
                    0.75 + (_ambientController.value * 0.25);
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: popupWidth,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  78 * compactFactor,
                                  20,
                                  22 * compactFactor,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      const Color(0xFF053E2A).withOpacity(0.90),
                                      const Color(0xFF007C4F).withOpacity(0.80),
                                      const Color(0xFF012618).withOpacity(0.96),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF69FFB0,
                                    ).withOpacity(0.78),
                                    width: 1.4,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.66),
                                      blurRadius: 36,
                                      offset: const Offset(0, 26),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF15FF8A,
                                      ).withOpacity(0.34 * glowPulse),
                                      blurRadius: 48,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        normalizedName,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: GinoPopupStyle.baseText(
                                          fontSize: 18,
                                          fontWeight:
                                              GinoPopupStyle.titleWeight,
                                          color: GinoPopupStyle.textWhite,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'JOCKeR JOUÉ !',
                                      textAlign: TextAlign.center,
                                      style: GinoPopupStyle.baseText(
                                        fontSize: 18,
                                        fontWeight: GinoPopupStyle.titleWeight,
                                        color: const Color(0xFF8CFFB5),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(height: 14 * compactFactor),
                                    _PremiumJockzrCardShowcase(
                                      cardsToDraw: displayedCardsToDraw,
                                      glowValue: _ambientController.value,
                                    ),
                                    SizedBox(height: 12 * compactFactor),
                                    Text(
                                      'Vous devez piocher',
                                      textAlign: TextAlign.center,
                                      style: GinoPopupStyle.baseText(
                                        fontSize: 18,
                                        fontWeight: GinoPopupStyle.titleWeight,
                                        color: GinoPopupStyle.textWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _PremiumDividerText(
                                      child: Text(
                                        '$displayedCardsToDraw CARTES',
                                        textAlign: TextAlign.center,
                                        style: GinoPopupStyle.baseText(
                                          fontSize: 16,
                                          fontWeight:
                                              GinoPopupStyle.titleWeight,
                                          color: const Color(0xFF61FF66),
                                          height: 1.05,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 18 * compactFactor),
                                    _PremiumDrawTwoButton(
                                      label:
                                          'PIOCHER $displayedCardsToDraw CARTES',
                                      onPressed: widget.onDraw,
                                    ),
                                    if (widget.showTimer) ...<Widget>[
                                      SizedBox(height: 14 * compactFactor),
                                      _PremiumDrawTwoTimer(
                                        seconds: timerSeconds,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(top: -36, child: _PremiumJockzrBadge()),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumJockzrBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF8FFF3), Color(0xFFB8FFD6)],
        ),
        border: Border.all(
          color: const Color(0xFF1BFF8E).withOpacity(0.78),
          width: 3,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF13C76B).withOpacity(0.45),
            blurRadius: 24,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.36),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        '🃏',
        style: GinoPopupStyle.baseText(
          fontSize: 28,
          fontWeight: GinoPopupStyle.titleWeight,
          color: GinoPopupStyle.suitBlack,
          height: 1,
        ),
      ),
    );
  }
}

class _PremiumJockzrCardShowcase extends StatelessWidget {
  const _PremiumJockzrCardShowcase({
    required this.cardsToDraw,
    required this.glowValue,
  });

  final int cardsToDraw;
  final double glowValue;

  @override
  Widget build(BuildContext context) {
    final double glow = 0.62 + (glowValue * 0.38);
    return SizedBox(
      width: 230,
      height: 235,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2CFF91).withOpacity(0.18),
                width: 5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF1EFF95).withOpacity(0.34 * glow),
                  blurRadius: 36 + (12 * glowValue),
                  spreadRadius: 7,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: -0.18,
            child: Container(
              width: 126,
              height: 178,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFFFFFF4), Color(0xFFE7FFF0)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE5E8D8), width: 1),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF74FFAE).withOpacity(0.20 * glow),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 14,
                    left: 12,
                    child: Text(
                      'J',
                      style: GinoPopupStyle.baseText(
                        color: GinoPopupStyle.amountGreen,
                        fontSize: 50,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 0.9,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '🃏',
                          style: GinoPopupStyle.baseText(
                            color: GinoPopupStyle.amountGreen,
                            fontSize: 50,
                            fontWeight: GinoPopupStyle.titleWeight,
                            height: 1,
                          ),
                        ),
                        Text(
                          'JOCKeR',
                          style: GinoPopupStyle.baseText(
                            color: GinoPopupStyle.amountGreen,
                            fontSize: 16,
                            fontWeight: GinoPopupStyle.titleWeight,
                            height: 1,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Text(
                        'J',
                        style: GinoPopupStyle.baseText(
                          color: GinoPopupStyle.amountGreen,
                          fontSize: 42,
                          fontWeight: GinoPopupStyle.titleWeight,
                          height: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 72,
            child: _PremiumDrawTwoBadge(cardsToDraw: cardsToDraw),
          ),
        ],
      ),
    );
  }
}

class PremiumDrawTwoPopup extends StatefulWidget {
  const PremiumDrawTwoPopup({
    super.key,
    required this.opponentName,
    required this.onDraw,
    this.cardsToDraw = 2,
    this.autoDrawSeconds,
    this.showTimer = false,
  });

  final String opponentName;
  final VoidCallback onDraw;
  final int cardsToDraw;
  final int? autoDrawSeconds;
  final bool showTimer;

  @override
  State<PremiumDrawTwoPopup> createState() => _PremiumDrawTwoPopupState();
}

class _PremiumDrawTwoPopupState extends State<PremiumDrawTwoPopup>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _shakeAnimation =
        TweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 0, end: -7),
            weight: 1,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -7, end: 6),
            weight: 1,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 6, end: -4),
            weight: 1,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -4, end: 0),
            weight: 1,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
          ),
        );
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double popupWidth = math.min(screenSize.width * 0.88, 430);
    final double compactFactor = screenSize.height < 720 ? 0.88 : 1.0;
    final String normalizedName = widget.opponentName.trim().isEmpty
        ? 'Adversaire'
        : widget.opponentName.trim();

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Container(color: Colors.black.withOpacity(0.56)),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ambientController,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: _PremiumDrawTwoParticlePainter(
                  _ambientController.value,
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _introController,
                _ambientController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final double glowPulse =
                    0.75 + (_ambientController.value * 0.25);
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: popupWidth,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                76 * compactFactor,
                                20,
                                22 * compactFactor,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFF044B30).withOpacity(0.92),
                                    GinoPopupStyle.popupGreen.withOpacity(0.94),
                                    const Color(0xFF012A19).withOpacity(0.96),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: const Color(
                                    0xFF69FFB0,
                                  ).withOpacity(0.72),
                                  width: 1.4,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.62),
                                    blurRadius: 34,
                                    offset: const Offset(0, 24),
                                  ),
                                  BoxShadow(
                                    color: GinoPopupStyle.accentGreen
                                        .withOpacity(0.30 * glowPulse),
                                    blurRadius: 42,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _PremiumDrawTwoAttackTitle(
                                    opponentName: normalizedName,
                                  ),
                                  SizedBox(height: 16 * compactFactor),
                                  _PremiumDrawTwoCardShowcase(
                                    cardsToDraw: widget.cardsToDraw,
                                    glowValue: _ambientController.value,
                                  ),
                                  SizedBox(height: 14 * compactFactor),
                                  Text(
                                    'Vous devez piocher',
                                    textAlign: TextAlign.center,
                                    style: GinoPopupStyle.baseText(
                                      fontSize: 18,
                                      fontWeight: GinoPopupStyle.titleWeight,
                                      color: GinoPopupStyle.textWhite,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _PremiumDividerText(
                                    child: Text(
                                      '${widget.cardsToDraw} CARTES',
                                      textAlign: TextAlign.center,
                                      style: GinoPopupStyle.baseText(
                                        fontSize: 16,
                                        fontWeight: GinoPopupStyle.titleWeight,
                                        color: const Color(0xFF61FF66),
                                        height: 1.05,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 18 * compactFactor),
                                  _PremiumDrawTwoButton(
                                    label:
                                        'PIOCHER ${widget.cardsToDraw} CARTES',
                                    onPressed: widget.onDraw,
                                  ),
                                  if (widget.showTimer &&
                                      widget.autoDrawSeconds !=
                                          null) ...<Widget>[
                                    SizedBox(height: 14 * compactFactor),
                                    _PremiumDrawTwoTimer(
                                      seconds: widget.autoDrawSeconds!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Positioned(
                              top: -36,
                              child: _PremiumDrawTwoOpponentAvatar(
                                name: normalizedName,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumDrawTwoAttackTitle extends StatelessWidget {
  const _PremiumDrawTwoAttackTitle({required this.opponentName});

  final String opponentName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$opponentName vous attaque !',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: GinoPopupStyle.baseText(
              fontSize: 18,
              fontWeight: GinoPopupStyle.titleWeight,
              color: GinoPopupStyle.textWhite,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumDrawTwoCardShowcase extends StatelessWidget {
  const _PremiumDrawTwoCardShowcase({
    required this.cardsToDraw,
    required this.glowValue,
  });

  final int cardsToDraw;
  final double glowValue;

  @override
  Widget build(BuildContext context) {
    final double glow = 0.62 + (glowValue * 0.38);
    return SizedBox(
      width: 230,
      height: 235,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 174,
            height: 174,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2CFF91).withOpacity(0.18),
                width: 5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF1EFF95).withOpacity(0.30 * glow),
                  blurRadius: 34 + (12 * glowValue),
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: -0.25,
            child: Container(
              width: 122,
              height: 174,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDEB),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE5E8D8), width: 1),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF74FFAE).withOpacity(0.18 * glow),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 18,
                    left: 16,
                    child: Text(
                      '2',
                      style: GinoPopupStyle.baseText(
                        color: GinoPopupStyle.amountGreen,
                        fontSize: 50,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 0.9,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '♣',
                      style: GinoPopupStyle.baseText(
                        color: GinoPopupStyle.amountGreen,
                        fontSize: 84,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Text(
                        '2',
                        style: GinoPopupStyle.baseText(
                          color: GinoPopupStyle.amountGreen,
                          fontSize: 42,
                          fontWeight: GinoPopupStyle.titleWeight,
                          height: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 72,
            child: _PremiumDrawTwoBadge(cardsToDraw: cardsToDraw),
          ),
        ],
      ),
    );
  }
}

class _PremiumDrawTwoBadge extends StatelessWidget {
  const _PremiumDrawTwoBadge({required this.cardsToDraw});

  final int cardsToDraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF4545), Color(0xFFD90016)],
        ),
        border: Border.all(color: const Color(0xFFFF8989), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: const Color(0xFFFF1E2D).withOpacity(0.32),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        '+$cardsToDraw',
        style: GinoPopupStyle.baseText(
          fontSize: 34,
          fontWeight: GinoPopupStyle.titleWeight,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _PremiumDividerText extends StatelessWidget {
  const _PremiumDividerText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _PremiumDividerLine(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: child,
        ),
        const _PremiumDividerLine(),
      ],
    );
  }
}

class _PremiumDividerLine extends StatelessWidget {
  const _PremiumDividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            GinoPopupStyle.accentGreen.withOpacity(0.68),
          ],
        ),
      ),
    );
  }
}

class _PremiumDrawTwoButton extends StatelessWidget {
  const _PremiumDrawTwoButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: math.min(MediaQuery.of(context).size.width * 0.68, 300),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF22E999), Color(0xFF08A95F)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFA9FFD1).withOpacity(0.62),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF13C76B).withOpacity(0.34),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GinoPopupStyle.baseText(
                fontSize: 15,
                fontWeight: GinoPopupStyle.buttonWeight,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumDrawTwoTimer extends StatelessWidget {
  const _PremiumDrawTwoTimer({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3DFF83).withOpacity(0.85),
              width: 2,
            ),
            color: const Color(0xFF043C25).withOpacity(0.76),
          ),
          child: Text(
            '$seconds',
            style: GinoPopupStyle.baseText(
              fontSize: 12,
              fontWeight: GinoPopupStyle.textWeight,
              color: const Color(0xFF63FF78),
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Auto-pioche dans ${seconds}s',
          style: GinoPopupStyle.baseText(
            fontSize: 13,
            fontWeight: GinoPopupStyle.textWeight,
            color: GinoPopupStyle.textWhite.withOpacity(0.72),
          ),
        ),
      ],
    );
  }
}

class _PremiumDrawTwoOpponentAvatar extends StatelessWidget {
  const _PremiumDrawTwoOpponentAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GinoPopupStyle.cardWhite,
        border: Border.all(
          color: const Color(0xFF1BFF8E).withOpacity(0.74),
          width: 3,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF13C76B).withOpacity(0.42),
            blurRadius: 22,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        initial,
        style: GinoPopupStyle.baseText(
          fontSize: 28,
          fontWeight: GinoPopupStyle.titleWeight,
          color: GinoPopupStyle.suitBlack,
          height: 1,
        ),
      ),
    );
  }
}

class _PremiumDrawTwoParticlePainter extends CustomPainter {
  const _PremiumDrawTwoParticlePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint sparkPaint = Paint()..style = PaintingStyle.fill;
    final Paint cardPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final List<Offset> sparks = <Offset>[
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.34),
      Offset(size.width * 0.25, size.height * 0.72),
      Offset(size.width * 0.72, size.height * 0.78),
      Offset(size.width * 0.50, size.height * 0.21),
    ];
    for (int i = 0; i < sparks.length; i++) {
      final double pulse = (math.sin((progress * math.pi * 2) + i) + 1) / 2;
      sparkPaint.color = const Color(
        0xFF59FF9C,
      ).withOpacity(0.10 + (pulse * 0.16));
      canvas.drawCircle(sparks[i], 1.4 + (pulse * 2.2), sparkPaint);
    }

    final List<Offset> cards = <Offset>[
      Offset(size.width * 0.20, size.height * 0.40),
      Offset(size.width * 0.80, size.height * 0.47),
      Offset(size.width * 0.30, size.height * 0.62),
    ];
    for (int i = 0; i < cards.length; i++) {
      final double drift = math.sin((progress * math.pi * 2) + i) * 5;
      final Rect rect = Rect.fromCenter(
        center: cards[i] + Offset(drift, -drift * 0.4),
        width: 30,
        height: 42,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(-0.35 + (i * 0.28));
      cardPaint.color = const Color(0xFF98FFC8).withOpacity(0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          const Radius.circular(4),
        ),
        cardPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumDrawTwoParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class GinoVictoryPopup extends StatelessWidget {
  const GinoVictoryPopup({
    super.key,
    required this.title,
    required this.message,
    this.wonAmount,
    this.canRequestRematch = false,
    this.onReplay,
    this.onRematch,
    this.onBackToMenu,
  });

  final String title;
  final String message;
  final int? wonAmount;
  final bool canRequestRematch;
  final VoidCallback? onReplay;
  final VoidCallback? onRematch;
  final VoidCallback? onBackToMenu;

  @override
  Widget build(BuildContext context) {
    return GinoPopupFrame(
      titleTag: title,
      isPremium: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: GinoPopupStyle.baseText(
              fontSize: 18,
              fontWeight: GinoPopupStyle.titleWeight,
            ),
          ),
          if (wonAmount != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: GinoPopupStyle.accentGreen,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Gain : $wonAmount',
                style: GinoPopupStyle.baseText(
                  fontSize: 18,
                  fontWeight: GinoPopupStyle.titleWeight,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (canRequestRematch && onRematch != null) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: GinoPopupButton(
                label: 'Revanche',
                onPressed: onRematch,
                isPremium: true,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (onReplay != null) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: GinoPopupButton(
                label: 'Rejouer',
                onPressed: onReplay,
                isPremium: true,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (onBackToMenu != null)
            SizedBox(
              width: double.infinity,
              child: GinoPopupButton(
                label: 'Retour menu',
                onPressed: onBackToMenu,
                isPrimary: false,
                isPremium: true,
              ),
            ),
        ],
      ),
    );
  }
}

class ConnectionPopup extends StatelessWidget {
  const ConnectionPopup({
    super.key,
    required this.onGooglePressed,
    required this.onContinueWithoutAccount,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onContinueWithoutAccount;

  @override
  Widget build(BuildContext context) {
    return GoogleConnectionPopup(
      eyebrow: 'Profil GINO',
      title: 'Connexion Google',
      message:
          'Sauvegarde ton profil, tes crédits et tes statistiques sur tous tes appareils.',
      primaryLabel: 'Connexion Google',
      secondaryLabel: 'Jouer en invité',
      secondaryIcon: Icons.person_outline_rounded,
      guestHint: 'Le solo reste disponible sans compte.',
      onGooglePressed: onGooglePressed,
      onSecondaryPressed: onContinueWithoutAccount,
    );
  }
}

class GoogleConnectionPopup extends StatelessWidget {
  const GoogleConnectionPopup({
    super.key,
    required this.onGooglePressed,
    required this.onSecondaryPressed,
    this.eyebrow = 'Connexion sécurisée',
    this.title = 'Connexion Google',
    this.message =
        'Connecte-toi avec Google pour continuer et synchroniser ton profil.',
    this.primaryLabel = 'Continuer avec Google',
    this.secondaryLabel = 'Annuler',
    this.secondaryIcon = Icons.close_rounded,
    this.guestHint,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onSecondaryPressed;
  final String eyebrow;
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final String? guestHint;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double popupWidth = math.min(screenSize.width * 0.92, 440);
    final double horizontalPadding = popupWidth < 350 ? 18 : 24;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
        child: Center(
          child: SingleChildScrollView(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: popupWidth,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        48,
                        horizontalPadding,
                        20,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: GinoPopupStyle.casinoGold.withValues(
                            alpha: 0.58,
                          ),
                          width: 1.1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            GinoPopupStyle.premiumDeepGreen.withValues(
                              alpha: 0.98,
                            ),
                            GinoPopupStyle.popupGreen.withValues(alpha: 0.94),
                            const Color(0xFF001D13).withValues(alpha: 0.98),
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 34,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color: GinoPopupStyle.premiumNeonGreen.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 30,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const _ConnectionOrnamentSuits(),
                          const SizedBox(height: 14),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: GinoPopupStyle.casinoGold.withValues(
                                  alpha: 0.46,
                                ),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: GinoPopupStyle.premiumNeonGreen
                                      .withValues(alpha: 0.18),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const _ConnectionGoogleIcon(size: 42),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GinoPopupStyle.baseText(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: GinoPopupStyle.baseText(
                              fontSize: 15,
                              color: GinoPopupStyle.textWhite.withValues(
                                alpha: 0.88,
                              ),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _ConnectionFeatureRow(
                            icon: Icons.account_circle_outlined,
                            title: 'Profil sauvegardé',
                            detail: 'Pseudo, avatar et progression retrouvés.',
                          ),
                          const SizedBox(height: 10),
                          const _ConnectionFeatureRow(
                            icon: Icons.savings_outlined,
                            title: 'Crédits protégés',
                            detail: 'Solde synchronisé après chaque partie.',
                          ),
                          const SizedBox(height: 10),
                          const _ConnectionFeatureRow(
                            icon: Icons.emoji_events_outlined,
                            title: 'Duel et classement',
                            detail: 'Accès aux modes en ligne et aux scores.',
                          ),
                          if (guestHint != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              guestHint!,
                              textAlign: TextAlign.center,
                              style: GinoPopupStyle.baseText(
                                fontSize: 12,
                                color: GinoPopupStyle.textWhite.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _ConnectionActionButton(
                            label: primaryLabel,
                            icon: const _ConnectionGoogleIcon(),
                            isPrimary: true,
                            onPressed: onGooglePressed,
                          ),
                          const SizedBox(height: 10),
                          _ConnectionActionButton(
                            label: secondaryLabel,
                            icon: Icon(
                              secondaryIcon,
                              color: GinoPopupStyle.textWhite.withValues(
                                alpha: 0.86,
                              ),
                              size: 21,
                            ),
                            isPrimary: false,
                            onPressed: onSecondaryPressed,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -20,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: popupWidth - 32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: GinoPopupStyle.premiumDeepGreen.withValues(
                          alpha: 0.96,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: GinoPopupStyle.casinoGold.withValues(
                            alpha: 0.88,
                          ),
                          width: 1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: GinoPopupStyle.premiumNeonGreen.withValues(
                              alpha: 0.20,
                            ),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.shield_outlined,
                            color: GinoPopupStyle.casinoGold,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                eyebrow,
                                maxLines: 1,
                                style: GinoPopupStyle.baseText(
                                  color: GinoPopupStyle.casinoGold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionFeatureRow extends StatelessWidget {
  const _ConnectionFeatureRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: GinoPopupStyle.premiumNeonGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: GinoPopupStyle.premiumNeonGreen.withValues(alpha: 0.28),
            ),
          ),
          child: Icon(
            icon,
            color: GinoPopupStyle.premiumNeonGreen.withValues(alpha: 0.92),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GinoPopupStyle.baseText(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GinoPopupStyle.baseText(
                  fontSize: 11.5,
                  color: GinoPopupStyle.textWhite.withValues(alpha: 0.70),
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionActionButton extends StatelessWidget {
  const _ConnectionActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? GinoPopupStyle.casinoGold.withValues(alpha: 0.58)
                  : GinoPopupStyle.borderGreen.withValues(alpha: 0.95),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPrimary
                  ? <Color>[
                      GinoPopupStyle.premiumNeonGreen.withValues(alpha: 0.90),
                      GinoPopupStyle.accentGreen.withValues(alpha: 0.78),
                    ]
                  : <Color>[
                      const Color(0xFF021D14).withValues(alpha: 0.92),
                      const Color(0xFF063322).withValues(alpha: 0.74),
                    ],
            ),
            boxShadow: isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: GinoPopupStyle.premiumNeonGreen.withValues(
                        alpha: 0.26,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : <BoxShadow>[],
          ),
          child: Row(
            children: <Widget>[
              SizedBox(width: 34, height: 34, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinoPopupStyle.baseText(
                    fontSize: isPrimary ? 15.5 : 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: GinoPopupStyle.textWhite.withValues(alpha: 0.82),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionGoogleIcon extends StatelessWidget {
  const _ConnectionGoogleIcon({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(
          color: const Color(0xFF4285F4),
          fontSize: size * 0.60,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConnectionOrnamentSuits extends StatelessWidget {
  const _ConnectionOrnamentSuits();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const <Widget>[
        _ConnectionSuit(symbol: '♦', color: GinoPopupStyle.suitRed),
        SizedBox(width: 13),
        _ConnectionSuit(symbol: '♣', color: GinoPopupStyle.premiumNeonGreen),
        SizedBox(width: 13),
        _ConnectionSuit(symbol: '♠', color: GinoPopupStyle.textWhite),
        SizedBox(width: 13),
        _ConnectionSuit(symbol: '♥', color: GinoPopupStyle.suitRed),
      ],
    );
  }
}

class _ConnectionSuit extends StatelessWidget {
  const _ConnectionSuit({required this.symbol, required this.color});

  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      symbol,
      style: GinoPopupStyle.baseText(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: color.withValues(alpha: 0.82),
        height: 1,
      ),
    );
  }
}

class GinoDecisionPopup extends StatelessWidget {
  const GinoDecisionPopup({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return GinoPopupFrame(
      titleTag: title,
      isPremium: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: GinoPopupStyle.baseText(fontSize: 17),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: GinoPopupButton(
                  label: secondaryLabel,
                  onPressed: onSecondary,
                  isPrimary: false,
                  isPremium: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GinoPopupButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
                  isPremium: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _normalizeSuitSymbol(String suit) {
  switch (suit.toLowerCase()) {
    case 'hearts':
    case 'heart':
    case 'coeur':
    case 'cœur':
    case '♥':
      return '♥';
    case 'spades':
    case 'spade':
    case 'pique':
    case '♠':
      return '♠';
    case 'clubs':
    case 'club':
    case 'trefle':
    case 'trèfle':
    case '♣':
      return '♣';
    case 'diamonds':
    case 'diamond':
    case 'carreau':
    case '♦':
      return '♦';
    default:
      return suit;
  }
}

Color _suitColor(String symbol) {
  if (symbol == '♥' || symbol == '♦') {
    return GinoPopupStyle.suitRed;
  }
  return GinoPopupStyle.suitBlack;
}

class GinoOpponentCommandPopup extends StatelessWidget {
  const GinoOpponentCommandPopup({
    super.key,
    required this.playerName,
    required this.suit,
    this.onClose,
  });

  final String playerName;
  final String suit;
  final VoidCallback? onClose;

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final String symbol = _normalizeSuitSymbol(suit);
    final Color suitColor = _opponentCommandSuitColor(symbol);
    final String suitName = _opponentCommandSuitName(symbol);
    final double panelWidth = math.min(screenSize.width * 0.92, 520);
    final double maxPanelHeight = screenSize.height * 0.86;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxPanelHeight,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: <Widget>[
                  Container(
                    width: panelWidth,
                    margin: const EdgeInsets.only(top: 26),
                    padding: const EdgeInsets.fromLTRB(22, 44, 22, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xE6072017),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xCC68E49A),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: GinoPopupStyle.accentGreen.withOpacity(0.20),
                          blurRadius: 42,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.48),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          const Color(0xF00A3523),
                          const Color(0xE6041D14),
                          const Color(0xF0082A1C),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topRight,
                          child: _OpponentCommandCloseButton(
                            onPressed: () => _close(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          playerName,
                          textAlign: TextAlign.center,
                          style: GinoPopupStyle.baseText(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'commande',
                          textAlign: TextAlign.center,
                          style: GinoPopupStyle.baseText(
                            fontWeight: GinoPopupStyle.textWeight,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _OpponentCommandCard(
                          symbol: symbol,
                          suitColor: suitColor,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Il joue une carte 8 et choisit la couleur.',
                          textAlign: TextAlign.center,
                          style: GinoPopupStyle.baseText(
                            color: const Color(0xFFE7F2EA),
                            fontSize: 15,
                            fontWeight: GinoPopupStyle.textWeight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'La couleur demandée est :',
                          textAlign: TextAlign.center,
                          style: GinoPopupStyle.baseText(
                            color: const Color(0xFFD5E2D9),
                            fontSize: 15,
                            fontWeight: GinoPopupStyle.textWeight,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _OpponentCommandSuitPill(
                          symbol: symbol,
                          suitName: suitName,
                          suitColor: suitColor,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => _close(context),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: GinoPopupStyle.accentGreen,
                              foregroundColor: GinoPopupStyle.textWhite,
                              side: BorderSide(
                                color: GinoPopupStyle.accentGreen.withOpacity(
                                  0.95,
                                ),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'OK, j’ai compris',
                              textAlign: TextAlign.center,
                              style: GinoPopupStyle.baseText(
                                color: GinoPopupStyle.textWhite,
                                fontSize: 15,
                                fontWeight: GinoPopupStyle.buttonWeight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(top: 0, child: _OpponentCommandBadge()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpponentCommandBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xF006291B),
        border: Border.all(color: const Color(0xFF72E99F), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GinoPopupStyle.accentGreen.withOpacity(0.45),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        '8',
        style: GinoPopupStyle.baseText(
          fontSize: 18,
          fontWeight: GinoPopupStyle.titleWeight,
          height: 1,
        ),
      ),
    );
  }
}

class _OpponentCommandCloseButton extends StatelessWidget {
  const _OpponentCommandCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GinoPopupStyle.accentGreen.withOpacity(0.08),
        border: Border.all(
          color: GinoPopupStyle.accentGreen.withOpacity(0.56),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        icon: Icon(
          Icons.close,
          color: GinoPopupStyle.textWhite.withOpacity(0.92),
          size: 18,
        ),
        tooltip: 'Fermer',
      ),
    );
  }
}

class _OpponentCommandCard extends StatelessWidget {
  const _OpponentCommandCard({required this.symbol, required this.suitColor});

  final String symbol;
  final Color suitColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 152,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: suitColor.withOpacity(0.20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: suitColor.withOpacity(0.35),
                  blurRadius: 38,
                  spreadRadius: 7,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 88,
              height: 126,
              decoration: BoxDecoration(
                color: GinoPopupStyle.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE8DD), width: 1),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Text(
                      '8',
                      style: GinoPopupStyle.baseText(
                        color: suitColor,
                        fontSize: 18,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 1,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      symbol,
                      style: GinoPopupStyle.baseText(
                        color: suitColor,
                        fontSize: 58,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Text(
                      symbol,
                      style: GinoPopupStyle.baseText(
                        color: suitColor,
                        fontSize: 18,
                        fontWeight: GinoPopupStyle.titleWeight,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentCommandSuitPill extends StatelessWidget {
  const _OpponentCommandSuitPill({
    required this.symbol,
    required this.suitName,
    required this.suitColor,
  });

  final String symbol;
  final String suitName;
  final Color suitColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC031912),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: suitColor.withOpacity(0.78), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: suitColor.withOpacity(0.16),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        '$symbol $suitName',
        textAlign: TextAlign.center,
        style: GinoPopupStyle.baseText(
          color: suitColor,
          fontSize: 16,
          fontWeight: GinoPopupStyle.textWeight,
        ),
      ),
    );
  }
}

String _opponentCommandSuitName(String symbol) {
  switch (symbol) {
    case '♥':
      return 'cœur';
    case '♦':
      return 'carreau';
    case '♣':
      return 'trèfle';
    case '♠':
      return 'pique';
    default:
      return symbol;
  }
}

Color _opponentCommandSuitColor(String symbol) {
  switch (symbol) {
    case '♥':
    case '♦':
      return const Color(0xFFFF4B43);
    case '♣':
      return const Color(0xFF7DFFAD);
    case '♠':
      return const Color(0xFFE5EAE4);
    default:
      return GinoPopupStyle.textWhite;
  }
}

class GinoChooseSuitPopup extends StatefulWidget {
  const GinoChooseSuitPopup({
    super.key,
    required this.onSuitSelected,
    this.suits = const <String>['♥', '♠', '♣', '♦'],
  });

  final ValueChanged<String> onSuitSelected;
  final List<String> suits;

  @override
  State<GinoChooseSuitPopup> createState() => _GinoChooseSuitPopupState();
}

class _GinoChooseSuitPopupState extends State<GinoChooseSuitPopup> {
  late String _selectedSuit;

  @override
  void initState() {
    super.initState();
    _selectedSuit = _resolvedSuits.first;
  }

  List<String> get _resolvedSuits {
    return widget.suits.length >= 4
        ? widget.suits.take(4).map(_normalizeSuitSymbol).toList(growable: false)
        : const <String>['♥', '♠', '♣', '♦'];
  }

  void _closeDialog() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double popupWidth = math.min(screenSize.width - 32, 520.0);
    final List<String> resolvedSuits = _resolvedSuits;

    if (!resolvedSuits.contains(_selectedSuit)) {
      _selectedSuit = resolvedSuits.first;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: popupWidth),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: GinoPopupStyle.accentGreen.withOpacity(0.18),
                  blurRadius: 42,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.48),
                  blurRadius: 34,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: popupWidth,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xE6082418),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: GinoPopupStyle.accentGreen.withOpacity(0.34),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topRight,
                            child: InkWell(
                              onTap: _closeDialog,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: GinoPopupStyle.accentGreen
                                        .withOpacity(0.28),
                                  ),
                                ),
                                child: Text(
                                  '×',
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 16,
                                    fontWeight: GinoPopupStyle.titleWeight,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      GinoPopupStyle.accentGreen.withOpacity(
                                        0.96,
                                      ),
                                      GinoPopupStyle.screenGreen.withOpacity(
                                        0.84,
                                      ),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: GinoPopupStyle.accentGreen
                                          .withOpacity(0.34),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '8',
                                  style: GinoPopupStyle.baseText(
                                    fontSize: 16,
                                    fontWeight: GinoPopupStyle.titleWeight,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Jouer la carte 8',
                                textAlign: TextAlign.center,
                                style: GinoPopupStyle.baseText(
                                  fontSize: 16,
                                  fontWeight: GinoPopupStyle.titleWeight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choisissez la couleur (sorte) de votre carte 8',
                        textAlign: TextAlign.center,
                        style: GinoPopupStyle.baseText(
                          fontSize: 16,
                          fontWeight: GinoPopupStyle.textWeight,
                          color: GinoPopupStyle.textWhite.withOpacity(0.86),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          for (final String suit in resolvedSuits)
                            _GinoSuitChoiceTile(
                              suit: suit,
                              selected: suit == _selectedSuit,
                              onTap: () => setState(() => _selectedSuit = suit),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GinoPopupStyle.baseText(
                            fontSize: 16,
                            fontWeight: GinoPopupStyle.textWeight,
                            color: GinoPopupStyle.textWhite.withOpacity(0.86),
                          ),
                          children: <TextSpan>[
                            const TextSpan(text: 'Vous jouerez : 8 '),
                            TextSpan(
                              text: _suitNameForChoice(_selectedSuit),
                              style: GinoPopupStyle.baseText(
                                fontSize: 16,
                                fontWeight: GinoPopupStyle.textWeight,
                                color: GinoPopupStyle.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _GinoSuitDialogButton(
                              label: 'Annuler',
                              isPrimary: false,
                              onTap: _closeDialog,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _GinoSuitDialogButton(
                              label: 'Jouer la carte',
                              onTap: () => widget.onSuitSelected(_selectedSuit),
                            ),
                          ),
                        ],
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

class _GinoSuitChoiceTile extends StatelessWidget {
  const _GinoSuitChoiceTile({
    required this.suit,
    required this.selected,
    required this.onTap,
  });

  final String suit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _choiceSuitColor(suit);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 108,
        height: 124,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? GinoPopupStyle.accentGreen.withOpacity(0.22)
              : GinoPopupStyle.popupGreen.withOpacity(0.66),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? GinoPopupStyle.accentGreen
                : accentColor.withOpacity(0.34),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (selected)
              BoxShadow(
                color: GinoPopupStyle.accentGreen.withOpacity(0.34),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              suit,
              style: GinoPopupStyle.baseText(
                color: accentColor,
                fontSize: 42,
                fontWeight: GinoPopupStyle.titleWeight,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _suitNameForChoice(suit),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GinoPopupStyle.baseText(
                fontSize: 16,
                fontWeight: GinoPopupStyle.textWeight,
                color: GinoPopupStyle.textWhite.withOpacity(0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GinoSuitDialogButton extends StatelessWidget {
  const _GinoSuitDialogButton({
    required this.label,
    required this.onTap,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? GinoPopupStyle.accentGreen.withOpacity(0.86)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius),
            border: Border.all(
              color: GinoPopupStyle.accentGreen.withOpacity(
                isPrimary ? 0.88 : 0.72,
              ),
              width: 1,
            ),
            boxShadow: isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: GinoPopupStyle.accentGreen.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GinoPopupStyle.baseText(
                fontSize: 15,
                fontWeight: GinoPopupStyle.buttonWeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _suitNameForChoice(String suit) {
  switch (_normalizeSuitSymbol(suit)) {
    case '♥':
      return 'cœur';
    case '♠':
      return 'pique';
    case '♣':
      return 'trèfle';
    case '♦':
      return 'carreau';
    default:
      return suit;
  }
}

Color _choiceSuitColor(String suit) {
  switch (_normalizeSuitSymbol(suit)) {
    case '♥':
    case '♦':
      return const Color(0xFFFF5B55);
    case '♣':
      return const Color(0xFF75F0A2);
    case '♠':
      return const Color(0xFFE4ECE7);
    default:
      return GinoPopupStyle.textWhite;
  }
}

class _CenteredRichText extends StatelessWidget {
  const _CenteredRichText({required this.spans, required this.fontSize});

  final List<TextSpan> spans;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GinoPopupStyle.baseText(
          fontSize: fontSize,
          fontWeight: GinoPopupStyle.textWeight,
        ),
        children: spans,
      ),
    );
  }
}
