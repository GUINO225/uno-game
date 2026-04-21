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
    String _readString(String key, {String fallback = ''}) {
      final Object? value = map[key];
      if (value == null) {
        return fallback;
      }
      if (value is String) {
        return value;
      }
      return '$value';
    }

    int _readInt(String key, {int fallback = 0}) {
      final Object? value = map[key];
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    DateTime? _readDateTime(String key) {
      final Object? value = map[key];
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

    final String displayName = _readString('displayName', fallback: 'Joueur');
    final String pseudo = _readString('pseudo', fallback: displayName);
    final int wins = _readInt('wins');
    final int losses = _readInt('losses');

    return PlayerProfile(
      uid: _readString('uid'),
      pseudo: pseudo,
      displayName: displayName,
      email: _readString('email').isEmpty ? null : _readString('email'),
      photoUrl: _readString('photoUrl').isEmpty ? null : _readString('photoUrl'),
      avatarUrl: _readString('avatarUrl').isEmpty
          ? (_readString('photoUrl').isEmpty ? null : _readString('photoUrl'))
          : _readString('avatarUrl'),
      credits: _readInt('credits'),
      wins: wins,
      losses: losses,
      totalGamesValue: map['totalGames'] == null ? null : _readInt('totalGames'),
      rankScore: map['rankScore'] != null
          ? _readInt('rankScore')
          : (map['score'] != null ? _readInt('score') : (wins * 3) - losses),
      createdAt: _readDateTime('createdAt'),
      lastLoginAt: _readDateTime('lastLoginAt'),
    );
  }
}
