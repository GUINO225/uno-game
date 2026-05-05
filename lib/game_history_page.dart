import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game_card_avatar.dart';
import 'premium_ui.dart';
import 'supabase_date_parser.dart';

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
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return const <_PlayerMatchResult>[];

    final SupabaseClient client = Supabase.instance.client;
    final List<Map<String, dynamic>> rows = await client
        .from('game_history')
        .select('id, player_id, opponent_id, result, stake, metadata, created_at')
        .or('player_id.eq.${user.id},opponent_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(150);

    final Set<String> profileIds = <String>{user.id};
    for (final Map<String, dynamic> row in rows) {
      final String playerId = (row['player_id'] as String? ?? '').trim();
      final String opponentId = (row['opponent_id'] as String? ?? '').trim();
      if (playerId.isNotEmpty) profileIds.add(playerId);
      if (opponentId.isNotEmpty) profileIds.add(opponentId);
    }

    final List<Map<String, dynamic>> profiles = profileIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', profileIds.toList());

    final Map<String, String> pseudoById = <String, String>{
      for (final Map<String, dynamic> p in profiles)
        (p['id'] as String? ?? '').trim(): (p['display_name'] as String? ?? 'Joueur').trim(),
    };

    final List<_PlayerMatchResult> results = rows
        .map((d) => _PlayerMatchResult.fromDoc(d, user.id, pseudoById))
        .whereType<_PlayerMatchResult>()
        .toList();
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
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
          if (s.hasError) {
            return Center(
              child: Text(
                "Impossible de charger l'historique pour le moment.",
                style: GoogleFonts.poppins(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            );
          }
          final List<_PlayerMatchResult> items = s.data ?? const <_PlayerMatchResult>[];
          if (items.isEmpty) return const Center(child: Text('Aucune partie jouée pour le moment.'));
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
                        Text('${r.myPseudo} vs ${r.opponentPseudo}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                        Text(r.isWin ? 'Victoire' : 'Défaite', style: GoogleFonts.poppins(color: accent, fontWeight: FontWeight.w500, fontSize: 13)),
                        Text('Mode: ${r.modeLabel}${r.stakeCredits > 0 ? ' • Mise: ${r.stakeCredits}' : ''}', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w400)),
                        Text('Crédits: ${r.creditDelta >= 0 ? '+' : ''}${r.creditDelta}', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w400)),
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
  const _PlayerMatchResult({required this.myUid, required this.myPseudo, required this.opponentPseudo, required this.isWin, required this.modeLabel, required this.stakeCredits, required this.creditDelta, required this.dateLabel, required this.createdAt});
  final String myUid;
  final String myPseudo;
  final String opponentPseudo;
  final bool isWin;
  final String modeLabel;
  final int stakeCredits;
  final int creditDelta;
  final String dateLabel;
  final DateTime createdAt;

  static _PlayerMatchResult? fromDoc(
    Map<String, dynamic> data,
    String uid,
    Map<String, String> pseudoById,
  ) {
    final String playerId = (data['player_id'] as String? ?? '').trim();
    final String opponentId = (data['opponent_id'] as String? ?? '').trim();
    final bool mineIsPlayer = playerId == uid;
    final bool mineIsOpponent = opponentId == uid;
    if (!mineIsPlayer && !mineIsOpponent) {
      return null;
    }
    final Map<String, dynamic> metadata =
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final DateTime dt = parseSupabaseDate(data['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final String mode =
        ((metadata['mode'] as String?) ?? (data['mode'] as String?) ?? 'partie').toLowerCase();

    final String myId = mineIsPlayer ? playerId : opponentId;
    final String otherId = mineIsPlayer ? opponentId : playerId;
    final String myPseudo = (pseudoById[myId] ?? 'Joueur').trim();
    final String otherPseudo = (pseudoById[otherId] ?? 'Joueur').trim();

    final String rawResult = (data['result'] as String? ?? '').toLowerCase();
    final bool isWin = mineIsPlayer
        ? rawResult == 'win'
        : (rawResult == 'loss' ? true : false);

    final int winnerDelta = (metadata['winner_credits_delta'] as num?)?.toInt() ?? 0;
    final int loserDelta = (metadata['loser_credits_delta'] as num?)?.toInt() ?? 0;

    return _PlayerMatchResult(
      myUid: uid,
      myPseudo: myPseudo.isEmpty ? 'Joueur' : myPseudo,
      opponentPseudo: otherPseudo.isEmpty ? 'Joueur' : otherPseudo,
      isWin: isWin,
      modeLabel: mode == 'credits' || mode == 'duel_pari'
          ? 'Duel Pari'
          : (mode == 'solo' ? 'Solo' : (mode == 'duel' ? 'Duel' : 'Partie')),
      stakeCredits: (data['stake'] as num?)?.toInt() ??
          (data['stakeCredits'] as num?)?.toInt() ??
          (data['wagerAmount'] as num?)?.toInt() ??
          0,
      creditDelta: mineIsPlayer ? winnerDelta : loserDelta,
      dateLabel: '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      createdAt: dt,
    );
  }
}
