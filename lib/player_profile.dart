import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.avatarUrl,
    this.credits = 1000,
    this.wins = 0,
    this.losses = 0,
    this.totalGamesValue,
    this.rankScore = 0,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
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
    return PlayerProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Joueur',
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      avatarUrl: map['avatarUrl'] as String? ?? map['photoUrl'] as String?,
      credits: (((map['credits'] as num?)?.toInt() ?? 1000) < 0)
          ? 0
          : ((map['credits'] as num?)?.toInt() ?? 1000),
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      totalGamesValue:
          (map['totalGames'] as num?)?.toInt() ??
          (map['gamesPlayed'] as num?)?.toInt(),
      rankScore:
          (map['rankScore'] as num?)?.toInt() ??
          (map['score'] as num?)?.toInt() ??
          (((map['wins'] as num?)?.toInt() ?? 0) * 3) -
              ((map['losses'] as num?)?.toInt() ?? 0),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}
