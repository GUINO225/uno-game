import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'player_profile.dart';

class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  Future<List<PlayerProfile>> fetchTopPlayers({int limit = 20}) async {
    debugPrint('[LeaderboardService] fetchTopPlayers started (limit=$limit)');
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fetchLeaderboardSnapshot(limit);
    final Map<String, PlayerProfile> playersByUid = <String, PlayerProfile>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      try {
        final Map<String, dynamic> data = doc.data();
        if (data['isRegistered'] == false) {
          continue;
        }
        final PlayerProfile profile = PlayerProfile.fromFirestoreDoc(doc);
        if (profile.uid.isNotEmpty) {
          final PlayerProfile? existing = playersByUid[profile.uid];
          if (existing == null || _isBetterCandidate(profile, existing)) {
            playersByUid[profile.uid] = profile;
          }
        }
      } catch (error, stackTrace) {
        debugPrint(
          '[RANKING] erreur parsing doc ${doc.id}: $error\n$stackTrace',
        );
      }
    }
    final List<PlayerProfile> players = playersByUid.values.toList(growable: false);
    players.sort((PlayerProfile a, PlayerProfile b) {
      final int scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) {
        return scoreOrder;
      }
      final int winsOrder = b.wins.compareTo(a.wins);
      if (winsOrder != 0) {
        return winsOrder;
      }
      final int totalGamesOrder = b.totalGames.compareTo(a.totalGames);
      if (totalGamesOrder != 0) {
        return totalGamesOrder;
      }
      return a.safeDisplayName.toLowerCase().compareTo(b.safeDisplayName.toLowerCase());
    });
    debugPrint('[LeaderboardService] leaderboard received (${players.length} players)');
    return players
        .take(limit)
        .toList(growable: false);
  }

  bool _isBetterCandidate(PlayerProfile candidate, PlayerProfile existing) {
    if (candidate.lastLoginAt == null && existing.lastLoginAt == null) {
      return candidate.score >= existing.score;
    }
    if (candidate.lastLoginAt == null) {
      return false;
    }
    if (existing.lastLoginAt == null) {
      return true;
    }
    return candidate.lastLoginAt!.isAfter(existing.lastLoginAt!);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchLeaderboardSnapshot(
    int limit,
  ) async {
    final CollectionReference<Map<String, dynamic>> profiles =
        FirebaseFirestore.instance.collection('user_profiles');
    final int queryLimit = limit * 4;

    try {
      return await profiles
          .orderBy('rankScore', descending: true)
          .limit(queryLimit)
          .get();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[LeaderboardService] rankScore query failed: ${error.code} - ${error.message}\n$stackTrace',
      );
      try {
        return await profiles
            .orderBy('score', descending: true)
            .limit(queryLimit)
            .get();
      } on FirebaseException catch (fallbackError, fallbackStackTrace) {
        debugPrint(
          '[LeaderboardService] score query failed: ${fallbackError.code} - ${fallbackError.message}\n$fallbackStackTrace',
        );
        return profiles.limit(queryLimit).get();
      }
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
}
