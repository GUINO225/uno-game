import 'dart:math' as math;

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
  });

  final Widget child;
  final String? titleTag;
  final double? width;
  final EdgeInsets padding;
  final bool showTitleTag;

  @override
  Widget build(BuildContext context) {
    final double resolvedWidth = width ?? math.min(MediaQuery.of(context).size.width * 0.8, 330);
    final bool shouldShowTitle = showTitleTag && titleTag != null && titleTag!.trim().isNotEmpty;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            width: resolvedWidth,
            padding: padding,
            decoration: BoxDecoration(
              color: GinoPopupStyle.popupGreen,
              borderRadius: BorderRadius.circular(GinoPopupStyle.popupRadius),
              border: Border.all(color: GinoPopupStyle.borderGreen, width: 1),
            ),
            child: child,
          ),
          if (shouldShowTitle)
            Positioned(
              top: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: GinoPopupStyle.accentGreen,
                  borderRadius: BorderRadius.circular(8),
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isPrimary
              ? GinoPopupStyle.screenGreen.withOpacity(0.70)
              : GinoPopupStyle.screenGreen.withOpacity(0.45),
          side: const BorderSide(color: GinoPopupStyle.borderGreen, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GinoPopupStyle.buttonRadius)),
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
  const GinoDisabledPopupButton({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: GinoPopupButton(
        label: label,
        onPressed: null,
      ),
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
  });

  final int amount;
  final bool selected;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Widget card = SizedBox(
      width: width + 10,
      height: height + 10,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: -0.05,
            child: Transform.translate(
              offset: const Offset(-4, 4),
              child: _BaseCardFace(width: width, height: height, opacity: 0.86),
            ),
          ),
          Transform.rotate(
            angle: 0.04,
            child: Transform.translate(
              offset: const Offset(4, 3),
              child: _BaseCardFace(width: width, height: height, opacity: 0.91),
            ),
          ),
          Transform.rotate(
            angle: selected ? -0.02 : 0.01,
            child: _BaseCardFace(
              width: width,
              height: height,
              selected: selected,
              child: Text(
                '$amount',
                style: GinoPopupStyle.baseText(
                  color: GinoPopupStyle.amountGreen,
                  fontSize: width >= 72 ? 25 : 19,
                  fontWeight: GinoPopupStyle.titleWeight,
                ),
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
        scale: selected ? 1.05 : 1,
        child: card,
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
    this.child,
  });

  final double width;
  final double height;
  final double opacity;
  final bool selected;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GinoPopupStyle.cardWhite.withOpacity(opacity),
        borderRadius: BorderRadius.circular(7),
        border: selected ? Border.all(color: GinoPopupStyle.accentGreen, width: 2) : null,
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
        border: selected ? Border.all(color: GinoPopupStyle.accentGreen, width: 2) : null,
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
                child: GinoSuitCard(
                  suit: symbol,
                  width: 64,
                  height: 92,
                ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
    return GinoPopupFrame(
      titleTag: 'Montant du pari',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CenteredRichText(
            fontSize: 17,
            spans: <TextSpan>[
              const TextSpan(text: 'Propose un pari à '),
              TextSpan(
                text: opponentName,
                style: GinoPopupStyle.baseText(fontWeight: FontWeight.w700),
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
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: GinoPopupStyle.baseText(fontSize: 16),
            onChanged: onAmountChanged,
            decoration: InputDecoration(
              hintText: 'Montant du pari',
              hintStyle: GinoPopupStyle.baseText(fontSize: 15, color: Colors.white70),
              filled: true,
              fillColor: GinoPopupStyle.screenGreen.withOpacity(0.35),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: GinoPopupStyle.borderGreen),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: GinoPopupStyle.accentGreen),
              ),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GinoPopupButton(
                  label: 'Valider',
                  onPressed: onValidate,
                ),
              ),
            ],
          ),
        ],
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
    return GinoPopupFrame(
      titleTag: 'Proposition',
      width: math.min(MediaQuery.of(context).size.width * 0.82, 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GinoAmountCard(
            amount: amount,
            width: 74,
            height: 116,
          ),
          const SizedBox(height: 16),
          _CenteredRichText(
            fontSize: 17,
            spans: <TextSpan>[
              TextSpan(
                text: proposerName,
                style: GinoPopupStyle.baseText(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: ' propose une mise de '),
              TextSpan(
                text: '$amount',
                style: GinoPopupStyle.baseText(fontWeight: GinoPopupStyle.titleWeight),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: GinoPopupButton(
                  label: 'Accepter',
                  onPressed: acceptEnabled ? onAccept : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GinoPopupButton(
                  label: 'Refuser',
                  onPressed: onRefuse,
                  isPrimary: false,
                ),
              ),
            ],
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
    final String bottomLabel = cardsToDraw == 1 ? '1 carte' : '$cardsToDraw cartes';

    return GinoPopupFrame(
      width: math.min(MediaQuery.of(context).size.width * 0.78, 320),
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
          GinoStackedDrawCards(
            rank: rank,
            suit: suit,
            count: cardsToDraw,
          ),
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
            GinoPopupButton(label: buttonLabel, onPressed: onDrawPressed),
          ],
        ],
      ),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: GinoPopupStyle.baseText(fontSize: 18, fontWeight: GinoPopupStyle.titleWeight),
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
              child: GinoPopupButton(label: 'Revanche', onPressed: onRematch),
            ),
            const SizedBox(height: 10),
          ],
          if (onReplay != null) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: GinoPopupButton(label: 'Rejouer', onPressed: onReplay),
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
              ),
            ),
        ],
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GinoPopupButton(
                  label: primaryLabel,
                  onPressed: onPrimary,
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
  });

  final String playerName;
  final String suit;

  @override
  Widget build(BuildContext context) {
    return GinoPopupFrame(
      width: math.min(MediaQuery.of(context).size.width * 0.78, 320),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      showTitleTag: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CenteredRichText(
            fontSize: 18,
            spans: <TextSpan>[
              TextSpan(
                text: playerName,
                style: GinoPopupStyle.baseText(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              TextSpan(
                text: ' commande',
                style: GinoPopupStyle.baseText(fontWeight: GinoPopupStyle.textWeight, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Transform.rotate(
            angle: -0.08,
            child: GinoSuitCard(
              suit: suit,
              width: 72,
              height: 104,
            ),
          ),
        ],
      ),
    );
  }
}

class GinoChooseSuitPopup extends StatelessWidget {
  const GinoChooseSuitPopup({
    super.key,
    required this.onSuitSelected,
    this.suits = const <String>['♥', '♠', '♣', '♦'],
  });

  final ValueChanged<String> onSuitSelected;
  final List<String> suits;

  @override
  Widget build(BuildContext context) {
    final List<String> resolvedSuits = suits.length >= 4
        ? suits.take(4).toList(growable: false)
        : const <String>['♥', '♠', '♣', '♦'];
    return GinoPopupFrame(
      width: math.min(MediaQuery.of(context).size.width * 0.74, 308),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      showTitleTag: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CenteredRichText(
            fontSize: 16,
            spans: <TextSpan>[
              TextSpan(
                text: 'Choisissez ',
                style: GinoPopupStyle.baseText(
                  fontSize: 16,
                  fontWeight: GinoPopupStyle.titleWeight,
                ),
              ),
              TextSpan(
                text: 'une couleur',
                style: GinoPopupStyle.baseText(fontSize: 16, fontWeight: GinoPopupStyle.textWeight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 52 / 74,
            children: <Widget>[
              GinoSuitCard(
                suit: resolvedSuits[0],
                width: 52,
                height: 74,
                onTap: () => onSuitSelected(resolvedSuits[0]),
              ),
              GinoSuitCard(
                suit: resolvedSuits[1],
                width: 52,
                height: 74,
                onTap: () => onSuitSelected(resolvedSuits[1]),
              ),
              GinoSuitCard(
                suit: resolvedSuits[2],
                width: 52,
                height: 74,
                onTap: () => onSuitSelected(resolvedSuits[2]),
              ),
              GinoSuitCard(
                suit: resolvedSuits[3],
                width: 52,
                height: 74,
                onTap: () => onSuitSelected(resolvedSuits[3]),
              ),
            ],
          ),
        ],
      ),
    );
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
        style: GinoPopupStyle.baseText(fontSize: fontSize, fontWeight: GinoPopupStyle.textWeight),
        children: spans,
      ),
    );
  }
}
