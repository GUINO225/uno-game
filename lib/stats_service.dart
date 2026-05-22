import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Statistiques cumulées entre deux joueurs (head-to-head).
@immutable
class HeadToHeadStats {
  const HeadToHeadStats({
    required this.games,
    required this.wins,
    required this.losses,
  });

  /// Nombre total de parties jouées avec l'adversaire.
  final int games;

  /// Nombre de parties gagnées par le joueur local.
  final int wins;

  /// Nombre de parties perdues par le joueur local.
  final int losses;

  static const HeadToHeadStats empty = HeadToHeadStats(
    games: 0,
    wins: 0,
    losses: 0,
  );

  HeadToHeadStats add({required bool didIWin}) {
    return HeadToHeadStats(
      games: games + 1,
      wins: wins + (didIWin ? 1 : 0),
      losses: losses + (didIWin ? 0 : 1),
    );
  }
}

class StatsService {
  StatsService._();

  static final StatsService instance = StatsService._();

  /// Cache mémoire des stats head-to-head. La clé est `"$myUid|$opponentUid"`.
  /// Évite de relire `match_results` à chaque rebuild et permet d'incrémenter
  /// localement après une fin de partie sans refetch immédiat.
  final Map<String, HeadToHeadStats> _h2hCache = <String, HeadToHeadStats>{};

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');
  CollectionReference<Map<String, dynamic>> get _results =>
      FirebaseFirestore.instance.collection('match_results');

  String _h2hKey(String myUid, String opponentUid) => '$myUid|$opponentUid';

  /// Lit les stats cachées si présentes (sans déclencher de fetch).
  HeadToHeadStats? cachedHeadToHead({
    required String myUid,
    required String opponentUid,
  }) {
    if (myUid.isEmpty || opponentUid.isEmpty) {
      return HeadToHeadStats.empty;
    }
    return _h2hCache[_h2hKey(myUid, opponentUid)];
  }

  /// Calcule les stats H2H depuis `match_results` en filtrant côté client
  /// (Firestore n'autorise pas deux `arrayContains` dans la même requête).
  /// Résultat mis en cache mémoire.
  Future<HeadToHeadStats> fetchHeadToHead({
    required String myUid,
    required String opponentUid,
    bool forceRefresh = false,
  }) async {
    if (myUid.isEmpty || opponentUid.isEmpty) {
      return HeadToHeadStats.empty;
    }
    final String key = _h2hKey(myUid, opponentUid);
    if (!forceRefresh && _h2hCache.containsKey(key)) {
      return _h2hCache[key]!;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _results
          .where('participantUids', arrayContains: myUid)
          .get();
      int games = 0;
      int wins = 0;
      int losses = 0;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final Map<String, dynamic> data = doc.data();
        final List<dynamic>? uids = data['participantUids'] as List<dynamic>?;
        if (uids == null || !uids.contains(opponentUid)) {
          continue;
        }
        games += 1;
        final String? winnerId = data['winnerId'] as String?;
        final String? loserId = data['loserId'] as String?;
        if (winnerId == myUid) {
          wins += 1;
        } else if (loserId == myUid) {
          losses += 1;
        }
      }
      final HeadToHeadStats stats = HeadToHeadStats(
        games: games,
        wins: wins,
        losses: losses,
      );
      _h2hCache[key] = stats;
      return stats;
    } catch (error) {
      debugPrint('[StatsService] head-to-head fetch failed: $error');
      // On renvoie l'éventuel cache existant, sinon vide, pour ne pas casser l'UI.
      return _h2hCache[key] ?? HeadToHeadStats.empty;
    }
  }

  /// Incrémente localement les stats H2H sans relire Firestore. À appeler
  /// après chaque manche terminée (recordDuelResult vient juste d'écrire la
  /// nouvelle entrée). Idempotent au niveau de l'écriture grâce à la dédup
  /// déjà gérée côté caller (clé `gameId_round`).
  void bumpHeadToHeadCache({
    required String myUid,
    required String opponentUid,
    required bool didIWin,
  }) {
    if (myUid.isEmpty || opponentUid.isEmpty) {
      return;
    }
    final String key = _h2hKey(myUid, opponentUid);
    final HeadToHeadStats current = _h2hCache[key] ?? HeadToHeadStats.empty;
    _h2hCache[key] = current.add(didIWin: didIWin);
  }

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
