import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String recipeId;
  final String userId;
  final String userDisplayName;
  final String? userAvatarUrl;
  final String text;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Comment(
      id: doc.id,
      recipeId: data['recipeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? 'Kullanıcı',
      userAvatarUrl: data['userAvatarUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'recipeId': recipeId,
        'userId': userId,
        'userDisplayName': userDisplayName,
        if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
