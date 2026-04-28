import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (user == null || user.isAnonymous) {
      return const <_PlayerMatchResult>[];
    }

    final CollectionReference<Map<String, dynamic>> resultsRef =
        FirebaseFirestore.instance.collection('match_results');

    final QuerySnapshot<Map<String, dynamic>> winsSnap =
        await resultsRef.where('winnerId', isEqualTo: user.uid).get();
    final QuerySnapshot<Map<String, dynamic>> lossesSnap =
        await resultsRef.where('loserId', isEqualTo: user.uid).get();

    final Map<String, _PlayerMatchResult> byResultId = <String, _PlayerMatchResult>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ...winsSnap.docs,
      ...lossesSnap.docs,
    ]) {
      final Map<String, dynamic> data = doc.data();
      final String winnerId = (data['winnerId'] as String? ?? '').trim();
      final String loserId = (data['loserId'] as String? ?? '').trim();
      final bool isWin = winnerId == user.uid;
      final String opponentId = isWin ? loserId : winnerId;
      byResultId[doc.id] = _PlayerMatchResult(
        resultId: doc.id,
        gameId: (data['gameId'] as String? ?? '-').trim(),
        round: (data['round'] as num?)?.toInt() ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        isWin: isWin,
        opponentId: opponentId.isEmpty ? 'Inconnu' : opponentId,
      );
    }

    final List<_PlayerMatchResult> results = byResultId.values.toList();
    results.sort((_PlayerMatchResult a, _PlayerMatchResult b) {
      final DateTime aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return results;
  }

  void _refresh() {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PremiumColors.panel,
        foregroundColor: PremiumColors.textDark,
        title: Text(
          'Historique de jeux',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: PremiumColors.textDark,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: FutureBuilder<List<_PlayerMatchResult>>(
        future: _historyFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<_PlayerMatchResult>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Impossible de charger l\'historique pour le moment.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: PremiumColors.textDark,
                        ),
                ),
              ),
            );
          }

          final List<_PlayerMatchResult> results =
              snapshot.data ?? const <_PlayerMatchResult>[];

          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Aucune partie enregistrée pour ce compte.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: PremiumColors.textDark,
                        ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final _PlayerMatchResult result = results[index];
                final Color accent = result.isWin
                    ? PremiumColors.accentGreen
                    : const Color(0xFFE86D6D);
                final DateTime? date = result.createdAt;
                final String dateLabel = date == null
                    ? 'Date inconnue'
                    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                return PremiumPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            result.isWin
                                ? Icons.emoji_events_rounded
                                : Icons.cancel_rounded,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            result.isWin ? 'Victoire' : 'Défaite',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Partie: ${result.gameId} • Manche ${result.round}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: PremiumColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adversaire: ${result.opponentId}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: PremiumColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: PremiumColors.textDark.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlayerMatchResult {
  const _PlayerMatchResult({
    required this.resultId,
    required this.gameId,
    required this.round,
    required this.createdAt,
    required this.isWin,
    required this.opponentId,
  });

  final String resultId;
  final String gameId;
  final int round;
  final DateTime? createdAt;
  final bool isWin;
  final String opponentId;
}
