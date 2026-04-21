import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.pseudo,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.avatarUrl,
    this.credits = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalGamesValue,
    this.rankScore = 0,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String pseudo;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? avatarUrl;
  final int credits;
  final int wins;
  final int losses;
  final int? totalGamesValue;
  final int rankScore;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  int get totalGames => totalGamesValue ?? (wins + losses);
  double get winRatio => totalGames == 0 ? 0 : wins / totalGames;
  String get id => uid;
  int get score => rankScore;
  String? get resolvedAvatarUrl => avatarUrl ?? photoUrl;
  String get effectivePseudo => pseudo.trim().isEmpty ? displayName : pseudo;
  String get safeDisplayName {
    final String value = effectivePseudo.trim();
    return value.isEmpty ? 'Joueur' : value;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'pseudo': pseudo,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'avatarUrl': avatarUrl,
      'credits': credits,
      'wins': wins,
      'losses': losses,
      'totalGames': totalGames,
      'score': score,
      'rankScore': rankScore,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!.toUtc()),
      'lastLoginAt': lastLoginAt == null ? null : Timestamp.fromDate(lastLoginAt!.toUtc()),
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    Object? _readRaw(List<String> keys) {
      for (final String key in keys) {
        final Object? value = map[key];
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    String _readString(List<String> keys, {String fallback = ''}) {
      final Object? value = _readRaw(keys);
      if (value == null) {
        return fallback;
      }
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? fallback : trimmed;
      }
      return '$value';
    }

    int _readInt(List<String> keys, {int fallback = 0}) {
      final Object? value = _readRaw(keys);
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    DateTime? _readDateTime(List<String> keys) {
      final Object? value = _readRaw(keys);
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final String uid = _readString(<String>['uid', 'id', 'userId']);
    final String displayName = _readString(
      <String>['displayName', 'name', 'username'],
      fallback: 'Joueur',
    );
    final String pseudo = _readString(<String>['pseudo', 'nickname'], fallback: displayName);
    final int wins = _readInt(<String>['wins', 'victories']);
    final int losses = _readInt(<String>['losses', 'defeats']);
    final int gamesFromTotal = _readInt(<String>['totalGames', 'matchesPlayed'], fallback: -1);
    final int gamesFromPlayed = _readInt(<String>['played'], fallback: -1);
    final int totalGamesValue =
        gamesFromTotal >= 0 ? gamesFromTotal : (gamesFromPlayed >= 0 ? gamesFromPlayed : wins + losses);

    return PlayerProfile(
      uid: uid,
      pseudo: pseudo,
      displayName: displayName,
      email: _readString(<String>['email']).isEmpty ? null : _readString(<String>['email']),
      photoUrl: _readString(<String>['photoUrl', 'photoURL']).isEmpty
          ? null
          : _readString(<String>['photoUrl', 'photoURL']),
      avatarUrl: _readString(<String>['avatarUrl', 'avatar']).isEmpty
          ? (_readString(<String>['photoUrl', 'photoURL']).isEmpty
              ? null
              : _readString(<String>['photoUrl', 'photoURL']))
          : _readString(<String>['avatarUrl', 'avatar']),
      credits: _readInt(<String>['credits', 'coins']),
      wins: wins,
      losses: losses,
      totalGamesValue: totalGamesValue,
      rankScore: _readRaw(<String>['rankScore']) != null
          ? _readInt(<String>['rankScore'])
          : (_readRaw(<String>['score', 'points']) != null
              ? _readInt(<String>['score', 'points'])
              : (wins * 3) - losses),
      createdAt: _readDateTime(<String>['createdAt']),
      lastLoginAt: _readDateTime(<String>['lastLoginAt', 'updatedAt']),
    );
  }

  factory PlayerProfile.fromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    if ((data['uid'] as String?)?.trim().isEmpty ?? true) {
      data['uid'] = doc.id;
    }
    return PlayerProfile.fromMap(data);
  }
}
