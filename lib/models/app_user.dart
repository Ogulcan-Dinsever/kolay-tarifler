import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppUser(
      id: doc.id,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'displayName': displayName,
        'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
