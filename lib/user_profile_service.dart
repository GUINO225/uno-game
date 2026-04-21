import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'player_profile.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

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
    final String suggestedDisplayName = suggestedNameFromUser(user);
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> ref = _profiles.doc(user.uid);
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        tx.set(ref, <String, dynamic>{
          'uid': user.uid,
          'displayName': suggestedDisplayName,
          'avatarUrl': user.photoURL,
          'wins': 0,
          'losses': 0,
          'totalGames': 0,
          'score': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final String existingDisplayName =
          (snapshot.data()?['displayName'] as String?)?.trim() ?? '';
      tx.update(ref, <String, dynamic>{
        if (existingDisplayName.isEmpty) 'displayName': suggestedDisplayName,
        'avatarUrl': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    });

    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return PlayerProfile.fromMap(<String, dynamic>{
      'uid': user.uid,
      'displayName': data['displayName'] ?? suggestedDisplayName,
      'avatarUrl': data['avatarUrl'] ?? user.photoURL,
      'wins': data['wins'] ?? 0,
      'losses': data['losses'] ?? 0,
      'createdAt': data['createdAt'] ?? Timestamp.fromDate(now),
      'lastLoginAt': data['lastLoginAt'] ?? Timestamp.fromDate(now),
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
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<PlayerProfile?> getProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _profiles.doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return PlayerProfile.fromMap(doc.data() ?? <String, dynamic>{});
  }
}
