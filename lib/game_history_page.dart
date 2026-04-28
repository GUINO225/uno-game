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

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<_PlayerMatchResult>> _loadHistory() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const <_PlayerMatchResult>[];

    final QuerySnapshot<Map<String, dynamic>> snap = await FirebaseFirestore.instance
        .collection('match_results')
        .where('playerIds', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snap.docs.map((d) => _PlayerMatchResult.fromDoc(d.data(), user.uid)).toList();
  }

  void _refresh() => setState(() => _historyFuture = _loadHistory());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique de jeux')),
      body: FutureBuilder<List<_PlayerMatchResult>>(
        future: _historyFuture,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final List<_PlayerMatchResult> items = s.data ?? const <_PlayerMatchResult>[];
          if (items.isEmpty) return const Center(child: Text('Aucune partie enregistrée.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = items[i];
              final Color accent = r.isWin ? PremiumColors.accentGreen : const Color(0xFFE86D6D);
              return PremiumPanel(
                child: Row(
                  children: <Widget>[
                    GameCardAvatar(
                      data: GameCardAvatarPalette.fromSeed(r.myUid),
                      size: 44,
                      showShadow: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        Text('${r.myPseudo} vs ${r.opponentPseudo}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        Text(r.isWin ? 'Victoire' : 'Défaite', style: GoogleFonts.poppins(color: accent, fontWeight: FontWeight.w700)),
                        Text('Mode: ${r.modeLabel}${r.stakeCredits > 0 ? ' • Mise: ${r.stakeCredits}' : ''}'),
                        Text('Crédits: ${r.creditDelta >= 0 ? '+' : ''}${r.creditDelta}'),
                        Text(r.dateLabel, style: GoogleFonts.poppins(fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayerMatchResult {
  const _PlayerMatchResult({required this.myUid, required this.myPseudo, required this.opponentPseudo, required this.isWin, required this.modeLabel, required this.stakeCredits, required this.creditDelta, required this.dateLabel});
  final String myUid;
  final String myPseudo;
  final String opponentPseudo;
  final bool isWin;
  final String modeLabel;
  final int stakeCredits;
  final int creditDelta;
  final String dateLabel;

  static _PlayerMatchResult fromDoc(Map<String, dynamic> data, String uid) {
    final Map<String, dynamic> a = (data['playerA'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final Map<String, dynamic> b = (data['playerB'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final bool mineIsA = (a['uid'] as String? ?? '') == uid;
    final Map<String, dynamic> mine = mineIsA ? a : b;
    final Map<String, dynamic> other = mineIsA ? b : a;
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final DateTime dt = ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
    final String mode = (data['mode'] as String? ?? 'duel').toLowerCase();
    return _PlayerMatchResult(
      myUid: uid,
      myPseudo: (mine['pseudo'] as String? ?? 'Joueur').trim(),
      opponentPseudo: (other['pseudo'] as String? ?? 'Adversaire').trim(),
      isWin: (mine['result'] as String? ?? '') == 'win',
      modeLabel: mode == 'credits' ? 'Duel Pari' : (mode == 'solo' ? 'Solo' : 'Duel'),
      stakeCredits: (data['stakeCredits'] as num?)?.toInt() ?? 0,
      creditDelta: (mine['creditDelta'] as num?)?.toInt() ?? 0,
      dateLabel: '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
    );
  }
}
