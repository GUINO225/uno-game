import 'dart:async';

import 'package:flutter/material.dart';

import 'app_sfx_service.dart';
import 'player_profile.dart';
import 'premium_ui.dart';
import 'user_profile_service.dart';
import 'widgets/gino_popups.dart';

enum GameRulesSection { base, cards, modes, credits }

Future<void> showGameRulesManual(
  BuildContext context, {
  GameRulesSection initialSection = GameRulesSection.base,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.66),
    builder: (_) => _GameRulesDialog(initialSection: initialSection),
  );
}

Future<void> showFirstLoginRulesIfNeeded(
  BuildContext context, {
  required UserProfileService profileService,
  required PlayerProfile profile,
}) async {
  if (profile.rulesManualSeenAt != null || profile.uid.trim().isEmpty) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  await showGameRulesManual(context);
  if (!context.mounted) {
    return;
  }
  try {
    await profileService.markRulesManualSeen(uid: profile.uid);
  } catch (e, stackTrace) {
    debugPrint('[RulesManual] unable to mark rules as seen: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class GameRulesButton extends StatelessWidget {
  const GameRulesButton({
    super.key,
    this.initialSection = GameRulesSection.base,
    this.compact = false,
    this.golden = true,
  });

  final GameRulesSection initialSection;
  final bool compact;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 42 : 48;
    return PremiumIconButtonShell(
      golden: golden,
      child: IconButton(
        constraints: BoxConstraints.tightFor(width: size, height: size),
        padding: EdgeInsets.zero,
        iconSize: compact ? 21 : 24,
        tooltip: 'Règles du jeu',
        onPressed: () {
          unawaited(AppSfxService.instance.playClick());
          unawaited(
            showGameRulesManual(context, initialSection: initialSection),
          );
        },
        icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
      ),
    );
  }
}

class _GameRulesDialog extends StatelessWidget {
  const _GameRulesDialog({required this.initialSection});

  final GameRulesSection initialSection;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final int initialIndex = GameRulesSection.values.indexOf(initialSection);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: DefaultTabController(
        length: GameRulesSection.values.length,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: screen.height * 0.86,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: GinoPopupStyle.casinoGold.withValues(alpha: 0.72),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  GinoPopupStyle.premiumDeepGreen.withValues(alpha: 0.98),
                  GinoPopupStyle.popupGreen.withValues(alpha: 0.95),
                  const Color(0xFF001D13).withValues(alpha: 0.98),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 36,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: GinoPopupStyle.premiumNeonGreen.withValues(
                    alpha: 0.16,
                  ),
                  blurRadius: 28,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                    child: Row(
                      children: <Widget>[
                        const _RulesSuitStrip(),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Règles du jeu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    indicatorColor: GinoPopupStyle.casinoGold,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.62),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: const <Widget>[
                      Tab(text: 'Base', icon: Icon(Icons.flag_rounded)),
                      Tab(text: 'Cartes', icon: Icon(Icons.style_rounded)),
                      Tab(text: 'Modes', icon: Icon(Icons.groups_rounded)),
                      Tab(text: 'Crédits', icon: Icon(Icons.toll_rounded)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _RulesScrollView(children: _baseRules()),
                        _RulesScrollView(children: _cardRules()),
                        _RulesScrollView(children: _modeRules()),
                        _RulesScrollView(children: _creditRules()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _baseRules() {
    return const <Widget>[
      _RuleGroup(
        title: 'But du jeu',
        lines: <String>[
          'Le premier joueur qui pose toutes ses cartes gagne la manche.',
          'Une carte 10 ou Valet ne peut pas être jouée comme toute dernière carte.',
          'Si vous ne pouvez pas jouer, vous piochez. En solo, une pioche volontaire passe ensuite le tour.',
        ],
      ),
      _RuleGroup(
        title: 'Mise en place',
        lines: <String>[
          'Chaque joueur reçoit 7 cartes.',
          'La pioche reste au centre et une carte est retournée pour démarrer la défausse.',
          'La première carte évite les effets trop forts au lancement, surtout le 8 et le Joker.',
        ],
      ),
      _RuleGroup(
        title: 'Jouer une carte',
        lines: <String>[
          'Vous pouvez poser une carte de même couleur/signe, de même valeur, un 8, ou un Joker compatible.',
          'Après un 8, la couleur demandée devient obligatoire jusqu’à ce qu’elle soit respectée.',
          'Après un Joker, la couleur rouge/noire du Joker devient importante.',
        ],
      ),
      _RuleGroup(
        title: 'Fin de manche',
        lines: <String>[
          'Quand votre main est vide, la manche se termine immédiatement.',
          'Les scores visibles augmentent pour le gagnant.',
          'Les crédits et bonus dépendent du mode choisi.',
        ],
      ),
    ];
  }

  List<Widget> _cardRules() {
    return const <Widget>[
      _RuleGroup(
        title: 'Carte 2',
        lines: <String>[
          'Le joueur adverse doit piocher 2 cartes.',
          'Il ne peut pas contrer pendant cette pénalité dans cette version.',
          'Quand la pioche forcée est terminée, le joueur qui a posé le 2 reprend le tour.',
        ],
      ),
      _RuleGroup(
        title: 'As',
        lines: <String>[
          'L’As force l’adversaire à répondre avec un autre As.',
          'S’il n’a pas d’As ou choisit de piocher, il pioche 1 carte et le tour passe.',
          'Un As joué en réponse annule l’obligation et la partie continue.',
        ],
      ),
      _RuleGroup(
        title: '8',
        lines: <String>[
          'Le 8 est toujours jouable.',
          'Après avoir posé un 8, vous choisissez la couleur demandée : cœur, carreau, pique ou trèfle.',
          'Un autre 8 peut répondre à un 8.',
        ],
      ),
      _RuleGroup(
        title: '10 et Valet',
        lines: <String>[
          'Un 10 ou un Valet fait sauter l’adversaire : vous rejouez.',
          'Ces cartes ne peuvent pas servir de dernière carte pour terminer une manche.',
        ],
      ),
      _RuleGroup(
        title: 'Joker',
        lines: <String>[
          'Le Joker force l’adversaire à piocher 8 cartes.',
          'Un Joker rouge suit les cartes rouges, un Joker noir suit les cartes noires.',
          'Comme pour le 2, la pénalité doit être piochée avant de rejouer.',
        ],
      ),
    ];
  }

  List<Widget> _modeRules() {
    return const <Widget>[
      _RuleGroup(
        title: 'Solo',
        lines: <String>[
          'Vous jouez contre l’ordi.',
          'L’ordi choisit ses cartes selon la main, les effets et les couleurs disponibles.',
          'Quitter une manche solo en cours applique une pénalité de crédits.',
        ],
      ),
      _RuleGroup(
        title: 'Duel',
        lines: <String>[
          'Un joueur crée un salon, l’autre rejoint avec le code.',
          'La partie démarre quand les deux joueurs sont présents.',
          'Le chat, le score de manche et les demandes de revanche sont intégrés au duel.',
        ],
      ),
      _RuleGroup(
        title: 'Pari',
        lines: <String>[
          'Le mode Pari utilise les crédits des profils connectés.',
          'Les joueurs valident une mise avant de lancer ou continuer la manche.',
          'À la fin, la mise et les bonus de carte sont réglés sur les crédits.',
        ],
      ),
    ];
  }

  List<Widget> _creditRules() {
    return const <Widget>[
      _RuleGroup(
        title: 'Base',
        lines: <String>[
          'Une victoire vaut +100 crédits.',
          'Une défaite vaut -100 crédits.',
          'En mode Pari, la mise acceptée s’ajoute au règlement de fin de manche.',
        ],
      ),
      _RuleGroup(
        title: 'Bonus de dernière carte',
        lines: <String>[
          'Terminer avec un 8 ajoute +100 crédits au gagnant et -100 à l’adversaire.',
          'Terminer avec un As ajoute +150 crédits au gagnant et -150 à l’adversaire.',
          'Terminer avec un 2 ajoute +200 crédits au gagnant et -200 à l’adversaire.',
          'Terminer avec un Joker ajoute +300 crédits au gagnant et -300 à l’adversaire.',
        ],
      ),
      _RuleGroup(
        title: 'Connexion',
        lines: <String>[
          'Les crédits, le classement et l’historique utilisent le compte connecté.',
          'Le duel et le pari demandent une connexion Google.',
          'Si le solde est insuffisant, le mode Pari bloque l’entrée.',
        ],
      ),
    ];
  }
}

class _RulesScrollView extends StatelessWidget {
  const _RulesScrollView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        children: children,
      ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: PremiumGameDecorations.glassPanel(
        radius: 16,
        opacity: 0.44,
        borderColor: Colors.white.withValues(alpha: 0.16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: GinoPopupStyle.casinoGold,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: GinoPopupStyle.premiumNeonGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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

class _RulesSuitStrip extends StatelessWidget {
  const _RulesSuitStrip();

  @override
  Widget build(BuildContext context) {
    const List<({String symbol, Color color})> suits =
        <({String symbol, Color color})>[
          (symbol: '♦', color: Color(0xFFFF4B55)),
          (symbol: '♣', color: Color(0xFF47E487)),
          (symbol: '♠', color: Colors.white),
          (symbol: '♥', color: Color(0xFFFF4B55)),
        ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: suits
          .map(
            (({Color color, String symbol}) suit) => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                suit.symbol,
                style: TextStyle(
                  color: suit.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
