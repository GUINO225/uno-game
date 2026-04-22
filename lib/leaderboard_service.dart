import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'player_profile.dart';

class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  Future<List<PlayerProfile>> fetchTopPlayers({int limit = 20}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .where('isRegistered', isEqualTo: true)
            .orderBy('score', descending: true)
            .limit(limit * 3)
            .get();
    final List<PlayerProfile> players = <PlayerProfile>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (data['isRegistered'] != true) {
        continue;
      }
      final PlayerProfile profile = PlayerProfile.fromMap(data);
      if (profile.uid.isNotEmpty) {
        players.add(profile);
      }
    }
    players.sort((PlayerProfile a, PlayerProfile b) {
      final int scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      return b.wins.compareTo(a.wins);
    });
    return players
        .take(limit)
        .toList(growable: false);
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
      final AggregateQuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('user_profiles')
          .where('isRegistered', isEqualTo: true)
          .count()
          .get();
      return snapshot.count;
    } catch (e, stackTrace) {
      debugPrint('[LeaderboardService] fetchRegisteredUsersCount failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
