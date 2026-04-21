import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'player_profile.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();
  static const int defaultCredits = 1000;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');

  String suggestedNameFromUser(User user) {
    final String displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final String emailName = (user.email ?? '').split('@').first.trim();
    if (emailName.isNotEmpty) {
      return emailName;
    }
    return 'Joueur';
  }

  Future<PlayerProfile> createOrUpdateFromGoogleUser(User user) async {
    final PlayerProfile profile = await createUserProfileIfNeeded(
      uid: user.uid,
      email: user.email,
      pseudo: suggestedNameFromUser(user),
      avatarUrl: user.photoURL,
      photoUrl: user.photoURL,
    );
    await _profiles.doc(user.uid).set(<String, dynamic>{
      'email': user.email,
      'photoUrl': user.photoURL,
      'avatarUrl': user.photoURL,
      'isRegistered': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return (await getUserProfile(user.uid)) ?? profile;
  }

  Future<PlayerProfile> createUserProfileIfNeeded({
    required String uid,
    String? email,
    String? pseudo,
    String? avatarUrl,
    String? photoUrl,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final String safePseudo = (pseudo ?? '').trim().isEmpty
        ? (email ?? '').split('@').first.trim().isEmpty
              ? 'Joueur'
              : (email ?? '').split('@').first.trim()
        : pseudo!.trim();
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(uid);
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        tx.set(ref, <String, dynamic>{
          'uid': uid,
          'email': email,
          'displayName': safePseudo,
          'pseudo': safePseudo,
          'photoUrl': photoUrl,
          'avatarUrl': avatarUrl ?? photoUrl,
          'credits': defaultCredits,
          'wins': 0,
          'losses': 0,
          'totalGames': 0,
          'gamesPlayed': 0,
          'score': 0,
          'rankScore': 0,
          'isRegistered': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
      final String existingDisplayName = (data['displayName'] as String?)?.trim() ?? '';
      final int existingCredits = (data['credits'] as num?)?.toInt() ?? defaultCredits;
      tx.set(ref, <String, dynamic>{
        'uid': uid,
        if ((email ?? '').trim().isNotEmpty) 'email': email,
        if (existingDisplayName.isEmpty) 'displayName': safePseudo,
        if ((data['pseudo'] as String?) == null) 'pseudo': safePseudo,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'credits': existingCredits < 0 ? 0 : existingCredits,
        'wins': (data['wins'] as num?)?.toInt() ?? 0,
        'losses': (data['losses'] as num?)?.toInt() ?? 0,
        'totalGames':
            (data['totalGames'] as num?)?.toInt() ??
            (data['gamesPlayed'] as num?)?.toInt() ??
            0,
        'gamesPlayed':
            (data['gamesPlayed'] as num?)?.toInt() ??
            (data['totalGames'] as num?)?.toInt() ??
            0,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isRegistered': true,
      }, SetOptions(merge: true));
    });
    return (await getUserProfile(uid)) ??
        PlayerProfile(
          uid: uid,
          displayName: safePseudo,
          email: email,
          photoUrl: photoUrl,
          avatarUrl: avatarUrl ?? photoUrl,
          credits: defaultCredits,
          wins: 0,
          losses: 0,
          totalGamesValue: 0,
          rankScore: 0,
          createdAt: now,
          lastLoginAt: now,
        );
  }

  Future<PlayerProfile?> getUserProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _profiles.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return PlayerProfile.fromMap(doc.data() ?? <String, dynamic>{});
  }

  Future<int> updateCredits({
    required String uid,
    required int delta,
    bool preventNegative = true,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(uid);
    int updatedCredits = defaultCredits;
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final int currentCredits = (data['credits'] as num?)?.toInt() ?? defaultCredits;
      int nextCredits = currentCredits + delta;
      if (preventNegative && nextCredits < 0) {
        nextCredits = 0;
      }
      updatedCredits = nextCredits;
      tx.set(ref, <String, dynamic>{
        'uid': uid,
        'credits': nextCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return updatedCredits;
  }

  Future<void> applyMatchResult({
    required String winnerId,
    required String loserId,
    int winnerCreditDelta = 0,
    int loserCreditDelta = 0,
    bool preventNegativeCredits = true,
  }) async {
    final DocumentReference<Map<String, dynamic>> winnerRef = _profiles.doc(winnerId);
    final DocumentReference<Map<String, dynamic>> loserRef = _profiles.doc(loserId);
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> winnerDoc = await tx.get(winnerRef);
      final DocumentSnapshot<Map<String, dynamic>> loserDoc = await tx.get(loserRef);
      final Map<String, dynamic> winnerData = winnerDoc.data() ?? <String, dynamic>{};
      final Map<String, dynamic> loserData = loserDoc.data() ?? <String, dynamic>{};
      final int winnerCredits = (winnerData['credits'] as num?)?.toInt() ?? defaultCredits;
      final int loserCredits = (loserData['credits'] as num?)?.toInt() ?? defaultCredits;
      int nextWinnerCredits = winnerCredits + winnerCreditDelta;
      int nextLoserCredits = loserCredits + loserCreditDelta;
      if (preventNegativeCredits) {
        nextWinnerCredits = nextWinnerCredits < 0 ? 0 : nextWinnerCredits;
        nextLoserCredits = nextLoserCredits < 0 ? 0 : nextLoserCredits;
      }
      tx.set(winnerRef, <String, dynamic>{
        'uid': winnerId,
        'credits': nextWinnerCredits,
        'wins': ((winnerData['wins'] as num?)?.toInt() ?? 0) + 1,
        'totalGames':
            ((winnerData['totalGames'] as num?)?.toInt() ??
                (winnerData['gamesPlayed'] as num?)?.toInt() ??
                0) +
            1,
        'gamesPlayed':
            ((winnerData['gamesPlayed'] as num?)?.toInt() ??
                (winnerData['totalGames'] as num?)?.toInt() ??
                0) +
            1,
        'score': ((winnerData['score'] as num?)?.toInt() ?? 0) + 3,
        'rankScore': ((winnerData['rankScore'] as num?)?.toInt() ?? 0) + 3,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(loserRef, <String, dynamic>{
        'uid': loserId,
        'credits': nextLoserCredits,
        'losses': ((loserData['losses'] as num?)?.toInt() ?? 0) + 1,
        'totalGames':
            ((loserData['totalGames'] as num?)?.toInt() ??
                (loserData['gamesPlayed'] as num?)?.toInt() ??
                0) +
            1,
        'gamesPlayed':
            ((loserData['gamesPlayed'] as num?)?.toInt() ??
                (loserData['totalGames'] as num?)?.toInt() ??
                0) +
            1,
        'score': ((loserData['score'] as num?)?.toInt() ?? 0) - 1,
        'rankScore': ((loserData['rankScore'] as num?)?.toInt() ?? 0) - 1,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    await _profiles.doc(uid).set(
      <String, dynamic>{
        'uid': uid,
        'displayName': displayName,
        'pseudo': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<PlayerProfile?> getProfile(String uid) => getUserProfile(uid);
}
