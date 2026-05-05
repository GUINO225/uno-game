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
    String mode = 'duel',
    int stakeCredits = 0,
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
      final Map<String, dynamic> winnerData = winnerDoc.data() ?? <String, dynamic>{};
      final Map<String, dynamic> loserData = loserDoc.data() ?? <String, dynamic>{};
      int winnerNextCredits = winnerCurrentCredits + winnerCreditsDelta;
      int loserNextCredits = loserCurrentCredits + loserCreditsDelta;
      if (preventNegativeCredits) {
        winnerNextCredits = winnerNextCredits < 0 ? 0 : winnerNextCredits;
        loserNextCredits = loserNextCredits < 0 ? 0 : loserNextCredits;
      }

      final String winnerPseudo =
          (winnerData['displayName'] as String? ?? '').trim().isEmpty
              ? 'Joueur'
              : (winnerData['displayName'] as String).trim();
      final String loserPseudo =
          (loserData['displayName'] as String? ?? '').trim().isEmpty
              ? 'Joueur'
              : (loserData['displayName'] as String).trim();

      tx.set(resultRef, <String, dynamic>{
        'resultId': resultId,
        'gameId': gameId,
        'round': round,
        'winnerId': winnerId,
        'loserId': loserId,
        'playerIds': <String>[winnerId, loserId],
        'participantUids': <String>[winnerId, loserId],
        'mode': mode,
        'stakeCredits': stakeCredits,
        'creditDeltaByPlayer': <String, int>{
          winnerId: winnerCreditsDelta,
          loserId: loserCreditsDelta,
        },
        'playerA': <String, dynamic>{
          'uid': winnerId,
          'pseudo': winnerPseudo,
          'avatarCard': winnerData['cardAvatar'] ?? winnerData['avatarUrl'],
          'result': 'win',
          'creditDelta': winnerCreditsDelta,
        },
        'playerB': <String, dynamic>{
          'uid': loserId,
          'pseudo': loserPseudo,
          'avatarCard': loserData['cardAvatar'] ?? loserData['avatarUrl'],
          'result': 'loss',
          'creditDelta': loserCreditsDelta,
        },
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
