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
    int winnerCreditsDelta = 0,
    int loserCreditsDelta = 0,
    bool preventNegativeCredits = true,
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
      final DocumentSnapshot<Map<String, dynamic>> winnerDoc = await tx.get(winnerRef);
      final DocumentSnapshot<Map<String, dynamic>> loserDoc = await tx.get(loserRef);
      final int winnerCurrentCredits =
          (winnerDoc.data()?['credits'] as num?)?.toInt() ?? 1000;
      final int loserCurrentCredits = (loserDoc.data()?['credits'] as num?)?.toInt() ?? 1000;
      int winnerNextCredits = winnerCurrentCredits + winnerCreditsDelta;
      int loserNextCredits = loserCurrentCredits + loserCreditsDelta;
      if (preventNegativeCredits) {
        winnerNextCredits = winnerNextCredits < 0 ? 0 : winnerNextCredits;
        loserNextCredits = loserNextCredits < 0 ? 0 : loserNextCredits;
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
        'credits': winnerNextCredits,
        'wins': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
        'gamesPlayed': FieldValue.increment(1),
        'score': FieldValue.increment(3),
        'rankScore': FieldValue.increment(3),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(loserRef, <String, dynamic>{
        'uid': loserId,
        'credits': loserNextCredits,
        'losses': FieldValue.increment(1),
        'totalGames': FieldValue.increment(1),
        'gamesPlayed': FieldValue.increment(1),
        'score': FieldValue.increment(-1),
        'rankScore': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    });
  }
}
