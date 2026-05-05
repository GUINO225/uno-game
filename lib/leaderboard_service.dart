import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'player_profile.dart';

class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  Future<List<PlayerProfile>> fetchTopPlayers({int limit = 20}) async {
    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, display_name, email, photo_url, credits, wins, losses, games_played',
          )
          .order('wins', ascending: false)
          .limit(limit);

      final List<PlayerProfile> players = <PlayerProfile>[];
      for (final dynamic row in rows) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final PlayerProfile profile = PlayerProfile.fromMap(<String, dynamic>{
          'uid': row['id'],
          'displayName': row['display_name'],
          'email': row['email'],
          'photoUrl': row['photo_url'],
          'credits': row['credits'],
          'wins': row['wins'],
          'losses': row['losses'],
          'totalGames': row['games_played'],
        });
        if (profile.uid.isNotEmpty) {
          players.add(profile);
        }
      }
      return players;
    } catch (e, stackTrace) {
      debugPrint('[LeaderboardService] fetchTopPlayers failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return <PlayerProfile>[];
    }
  }

  Future<int?> fetchPlayerRank(String uid, {int scanLimit = 250}) async {
    final List<PlayerProfile> players = await fetchTopPlayers(limit: scanLimit);
    final int index = players.indexWhere((PlayerProfile p) => p.uid == uid);
    if (index < 0) {
      return null;
    }
    return index + 1;
  }

  Future<int?> fetchRegisteredUsersCount() async {
    try {
      final int count = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);
      return count;
    } catch (e, stackTrace) {
      debugPrint('[LeaderboardService] fetchRegisteredUsersCount failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
