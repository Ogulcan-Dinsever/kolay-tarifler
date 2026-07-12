import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{uid}/notifications altındaki tek bir uygulama içi bildirim.
/// Belgeleri yalnızca Cloud Functions oluşturur (bkz. functions/index.js).
class AppNotification {
  final String id;
  final String title;
  final String body;

  /// 'recipe_liked' | 'comment' | 'pending_recipe' — yönlendirme için.
  final String? type;

  /// Tarif id'si ya da başvuru id'si (type'a göre).
  final String? targetId;

  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.targetId,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data['type']?.toString(),
      targetId: data['targetId']?.toString(),
      read: data['read'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Bildirime tıklanınca gidilecek rota; bilinmeyen type için null.
  String? get route => switch (type) {
        'recipe_liked' || 'comment' when targetId != null => '/recipe/$targetId',
        'pending_recipe' => '/my-submissions',
        _ => null,
      };
}
