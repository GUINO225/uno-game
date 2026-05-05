import 'package:supabase_flutter/supabase_flutter.dart';

class StatsService {
  StatsService._();

  static final StatsService instance = StatsService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> recordDuelResult({
    required String gameId,
    required int round,
    required String winnerId,
    required String loserId,
    int winnerCreditsDelta = 0,
    int loserCreditsDelta = 0,
    bool preventNegativeCredits = true,
    String mode = 'duel',
    int stakeCredits = 0,
  }) async {
    final String resultId = '${gameId}_$round';

    final bool rpcApplied = await _tryRecordDuelResultRpc(
      resultId: resultId,
      gameId: gameId,
      round: round,
      winnerId: winnerId,
      loserId: loserId,
      winnerCreditsDelta: winnerCreditsDelta,
      loserCreditsDelta: loserCreditsDelta,
      preventNegativeCredits: preventNegativeCredits,
      mode: mode,
      stakeCredits: stakeCredits,
    );

    if (rpcApplied) {
      return;
    }

    await _recordDuelResultFallback(
      resultId: resultId,
      gameId: gameId,
      winnerId: winnerId,
      loserId: loserId,
      winnerCreditsDelta: winnerCreditsDelta,
      loserCreditsDelta: loserCreditsDelta,
      preventNegativeCredits: preventNegativeCredits,
      mode: mode,
      stakeCredits: stakeCredits,
    );
  }

  Future<bool> _tryRecordDuelResultRpc({
    required String resultId,
    required String gameId,
    required int round,
    required String winnerId,
    required String loserId,
    required int winnerCreditsDelta,
    required int loserCreditsDelta,
    required bool preventNegativeCredits,
    required String mode,
    required int stakeCredits,
  }) async {
    try {
      await _client.rpc(
        'record_duel_result',
        params: <String, dynamic>{
          'p_result_id': resultId,
          'p_game_id': gameId,
          'p_round': round,
          'p_winner_id': winnerId,
          'p_loser_id': loserId,
          'p_winner_credits_delta': winnerCreditsDelta,
          'p_loser_credits_delta': loserCreditsDelta,
          'p_prevent_negative_credits': preventNegativeCredits,
          'p_mode': mode,
          'p_stake_credits': stakeCredits,
        },
      );
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '42883') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _recordDuelResultFallback({
    required String resultId,
    required String gameId,
    required String winnerId,
    required String loserId,
    required int winnerCreditsDelta,
    required int loserCreditsDelta,
    required bool preventNegativeCredits,
    required String mode,
    required int stakeCredits,
  }) async {
    final List<Map<String, dynamic>> existing = await _client
        .from('game_history')
        .select('id')
        .eq('id', resultId)
        .limit(1);

    if (existing.isNotEmpty) {
      return;
    }

    final List<Map<String, dynamic>> winnerRows = await _client
        .from('profiles')
        .select('id, credits, wins, losses, games_played')
        .eq('id', winnerId)
        .limit(1);

    final List<Map<String, dynamic>> loserRows = await _client
        .from('profiles')
        .select('id, credits, wins, losses, games_played')
        .eq('id', loserId)
        .limit(1);

    final Map<String, dynamic> winner =
        winnerRows.isEmpty ? <String, dynamic>{} : winnerRows.first;
    final Map<String, dynamic> loser =
        loserRows.isEmpty ? <String, dynamic>{} : loserRows.first;

    final int winnerCreditsCurrent = (winner['credits'] as num?)?.toInt() ?? 1000;
    final int loserCreditsCurrent = (loser['credits'] as num?)?.toInt() ?? 1000;

    int winnerCreditsNext = winnerCreditsCurrent + winnerCreditsDelta;
    int loserCreditsNext = loserCreditsCurrent + loserCreditsDelta;

    if (preventNegativeCredits) {
      if (winnerCreditsNext < 0) {
        winnerCreditsNext = 0;
      }
      if (loserCreditsNext < 0) {
        loserCreditsNext = 0;
      }
    }

    await _client.from('game_history').insert(<String, dynamic>{
      'id': resultId,
      'game_id': gameId,
      'player_id': winnerId,
      'opponent_id': loserId,
      'result': 'win',
      'stake': stakeCredits,
      'metadata': <String, dynamic>{
        'mode': mode,
        'winner_credits_delta': winnerCreditsDelta,
        'loser_credits_delta': loserCreditsDelta,
      },
    });

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': winnerId,
      'credits': winnerCreditsNext,
      'wins': ((winner['wins'] as num?)?.toInt() ?? 0) + 1,
      'games_played': ((winner['games_played'] as num?)?.toInt() ?? 0) + 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': loserId,
      'credits': loserCreditsNext,
      'losses': ((loser['losses'] as num?)?.toInt() ?? 0) + 1,
      'games_played': ((loser['games_played'] as num?)?.toInt() ?? 0) + 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
