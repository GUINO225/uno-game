import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  StatsService._();

  static final StatsService instance = StatsService._();

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');
  CollectionReference<Map<String, dynamic>> get _results =>
      FirebaseFirestore.instance.collection('match_results');

  Future<void> recordDuelResult({
    required String gameId,
    required int round,
    required String winnerId,
    required String loserId,
  }) async {
    final String resultId = '${gameId}_$round';
    final DocumentReference<Map<String, dynamic>> resultRef = _results.doc(resultId);
    final DocumentReference<Map<String, dynamic>> winnerRef = _profiles.doc(winnerId);
    final DocumentReference<Map<String, dynamic>> loserRef = _profiles.doc(loserId);

    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> resultDoc = await tx.get(resultRef);
      if (resultDoc.exists) {
        return;
      }

      tx.set(resultRef, <String, dynamic>{
        'resultId': resultId,
        'gameId': gameId,
        'round': round,
        'winnerId': winnerId,
        'loserId': loserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(winnerRef, <String, dynamic>{
        'uid': winnerId,
        'wins': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
        'score': FieldValue.increment(3),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(loserRef, <String, dynamic>{
        'uid': loserId,
        'losses': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
        'score': FieldValue.increment(-1),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
