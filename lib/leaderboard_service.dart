import 'package:cloud_firestore/cloud_firestore.dart';

import 'player_profile.dart';

class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  Future<List<PlayerProfile>> fetchTopPlayers({int limit = 20}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .orderBy('score', descending: true)
            .limit(limit)
            .get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return PlayerProfile.fromMap(doc.data());
        })
        .where((PlayerProfile profile) => profile.uid.isNotEmpty)
        .toList(growable: false);
  }
}
