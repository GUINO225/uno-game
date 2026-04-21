import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.wins = 0,
    this.losses = 0,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final int wins;
  final int losses;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  int get totalGames => wins + losses;
  double get winRatio => totalGames == 0 ? 0 : wins / totalGames;
  int get score => (wins * 3) - losses;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'wins': wins,
      'losses': losses,
      'totalGames': totalGames,
      'score': score,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!.toUtc()),
      'lastLoginAt': lastLoginAt == null ? null : Timestamp.fromDate(lastLoginAt!.toUtc()),
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Joueur',
      avatarUrl: map['avatarUrl'] as String?,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}
