import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game_card_avatar.dart';
import 'premium_ui.dart';

class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  Future<List<_PlayerMatchResult>>? _historyFuture;

  static const Color _creamText = Color(0xFFF4F1E6);
  static const Color _mutedText = Color(0xBFD8E7D9);
  static const Color _softGrey = Color(0xFFC9D4CE);
  static const Color _lossColor = Color(0xFFFF8A65);

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<_PlayerMatchResult>> _loadHistory() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const <_PlayerMatchResult>[];

    final CollectionReference<Map<String, dynamic>> collection =
        FirebaseFirestore.instance.collection('match_results');

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await collection
          .where('participantUids', arrayContains: user.uid)
          .limit(150)
          .get();
    } on FirebaseException {
      try {
        snap = await collection.where('playerIds', arrayContains: user.uid).limit(150).get();
      } on FirebaseException {
        return const <_PlayerMatchResult>[];
      }
    }

    final List<_PlayerMatchResult> results = snap.docs
        .map((d) => _PlayerMatchResult.fromDoc(d.data(), user.uid))
        .whereType<_PlayerMatchResult>()
        .toList();
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  void _refresh() => setState(() => _historyFuture = _loadHistory());

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = (Theme.of(context).appBarTheme.titleTextStyle ??
            Theme.of(context).textTheme.titleLarge ??
            GoogleFonts.poppins(fontSize: 20))
        .copyWith(
      color: _creamText,
      fontWeight: FontWeight.normal,
    );

    return Scaffold(
      backgroundColor: PremiumColors.tableGreenDark,
      body: _HistoryBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: <Widget>[
                    const BackButton(color: _creamText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Historique de jeux',
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<_PlayerMatchResult>>(
                  future: _historyFuture,
                  builder: (context, s) {
                    if (s.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: PremiumColors.accentGreen,
                        ),
                      );
                    }
                    if (s.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _HistoryInfoCard(
                            child: Text(
                              "Impossible de charger l'historique pour le moment.",
                              style: GoogleFonts.poppins(
                                color: _creamText,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }
                    final List<_PlayerMatchResult> items = s.data ?? const <_PlayerMatchResult>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _HistoryInfoCard(
                            child: Text(
                              'Aucune partie enregistrée',
                              style: GoogleFonts.poppins(
                                color: _creamText,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final double horizontalPadding = constraints.maxWidth > 720 ? 32 : 16;
                        final double maxWidth = constraints.maxWidth > 760 ? 720 : constraints.maxWidth;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: maxWidth,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 18),
                              itemCount: items.length + 1,
                              itemBuilder: (_, i) {
                                if (i == items.length) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                    child: Text(
                                      "L’historique est mis à jour en temps réel.",
                                      style: GoogleFonts.poppins(
                                        color: PremiumColors.accentGreen.withOpacity(0.58),
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryCard(result: items[i]),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryBackground extends StatelessWidget {
  const _HistoryBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF062819),
            Color(0xFF0A3A2A),
            Color(0xFF031910),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(top: 72, left: -18, child: _CardSuit('♠', size: 118)),
          const Positioned(top: 132, right: 24, child: _CardSuit('♣', size: 88)),
          const Positioned(bottom: 126, left: 28, child: _CardSuit('♦', size: 82)),
          const Positioned(bottom: 44, right: -8, child: _CardSuit('♥', size: 114)),
          Positioned(
            top: -90,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PremiumColors.accentGreen.withOpacity(0.06),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CardSuit extends StatelessWidget {
  const _CardSuit(this.symbol, {required this.size});

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      symbol,
      style: TextStyle(
        color: Colors.white.withOpacity(0.035),
        fontSize: size,
        height: 1,
      ),
    );
  }
}

class _HistoryInfoCard extends StatelessWidget {
  const _HistoryInfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xCC082C1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.result});

  final _PlayerMatchResult result;

  Color get _accent {
    if (result.isDraw) return _GameHistoryPageState._softGrey;
    return result.isWin
        ? PremiumColors.accentGreen
        : _GameHistoryPageState._lossColor;
  }

  String get _statusLabel {
    if (result.isDraw) return 'Égalité';
    return result.isWin ? 'Victoire' : 'Défaite';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent;
    final String credits = '${result.creditDelta >= 0 ? '+' : ''}${result.creditDelta} Crédits';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xD9092D1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.42), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: GameCardAvatar(
              data: GameCardAvatarPalette.fromSeed(result.myUid),
              size: 44,
              showShadow: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.myPseudo} vs ${result.opponentPseudo}',
                  style: GoogleFonts.poppins(
                    color: _GameHistoryPageState._creamText,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.24), width: 0.7),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.poppins(
                      color: accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mode: ${result.modeLabel}${result.stakeCredits > 0 ? ' • Mise: ${result.stakeCredits}' : ''}',
                  style: GoogleFonts.poppins(
                    color: _GameHistoryPageState._mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Crédits: ${result.creditDelta >= 0 ? '+' : ''}${result.creditDelta}',
                  style: GoogleFonts.poppins(
                    color: _GameHistoryPageState._mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  result.dateLabel,
                  style: GoogleFonts.poppins(
                    color: _GameHistoryPageState._mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              credits,
              style: GoogleFonts.poppins(
                color: result.creditDelta == 0
                    ? _GameHistoryPageState._softGrey
                    : (result.creditDelta > 0
                        ? PremiumColors.accentGreen
                        : _GameHistoryPageState._lossColor),
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerMatchResult {
  const _PlayerMatchResult({
    required this.myUid,
    required this.myPseudo,
    required this.opponentPseudo,
    required this.isWin,
    required this.isDraw,
    required this.modeLabel,
    required this.stakeCredits,
    required this.creditDelta,
    required this.dateLabel,
    required this.createdAt,
  });
  final String myUid;
  final String myPseudo;
  final String opponentPseudo;
  final bool isWin;
  final bool isDraw;
  final String modeLabel;
  final int stakeCredits;
  final int creditDelta;
  final String dateLabel;
  final DateTime createdAt;

  static _PlayerMatchResult? fromDoc(Map<String, dynamic> data, String uid) {
    final Map<String, dynamic> a = (data['playerA'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final Map<String, dynamic> b = (data['playerB'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final String aUid = (a['uid'] as String? ?? '').trim();
    final String bUid = (b['uid'] as String? ?? '').trim();
    final bool mineIsA = aUid == uid;
    final bool mineIsB = bUid == uid;
    if (!mineIsA && !mineIsB) {
      return null;
    }
    final Map<String, dynamic> mine = mineIsA ? a : b;
    final Map<String, dynamic> other = mineIsA ? b : a;
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final DateTime dt = ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
    final String mode = (data['mode'] as String? ?? 'partie').toLowerCase();
    final String result = (mine['result'] as String? ?? '').toLowerCase();
    return _PlayerMatchResult(
      myUid: uid,
      myPseudo: (mine['pseudo'] as String? ?? 'Joueur').trim(),
      opponentPseudo: ((other['pseudo'] as String?)?.trim().isNotEmpty ?? false)
          ? (other['pseudo'] as String).trim()
          : 'Joueur',
      isWin: result == 'win',
      isDraw: result == 'draw' || result == 'tie' || result == 'egalite' || result == 'égalité',
      modeLabel: mode == 'credits' || mode == 'duel_pari'
          ? 'Duel Pari'
          : (mode == 'solo' ? 'Solo' : (mode == 'duel' ? 'Duel' : 'Partie')),
      stakeCredits: (data['stakeCredits'] as num?)?.toInt() ??
          (data['wagerAmount'] as num?)?.toInt() ??
          0,
      creditDelta: (mine['creditDelta'] as num?)?.toInt() ?? 0,
      dateLabel: '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      createdAt: dt,
    );
  }
}
