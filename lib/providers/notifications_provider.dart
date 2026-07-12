import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import 'auth_provider.dart';

/// Oturum açan kullanıcının bildirimleri — en yeni önce, son 50.
/// Misafirde boş liste döner (zil rozeti görünmez).
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null || user.isAnonymous) {
    return Stream.value(const <AppNotification>[]);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
});

/// Zil rozetinin kaynağı — okunmamış bildirim sayısı.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull;
  if (list == null) return 0;
  return list.where((n) => !n.read).length;
});

/// Okundu işaretleme / silme işlemleri.
class NotificationActions {
  final String uid;
  NotificationActions(this.uid);

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(List<AppNotification> items) async {
    final unread = items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_col.doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

final notificationActionsProvider = Provider<NotificationActions?>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null || user.isAnonymous) return null;
  return NotificationActions(user.uid);
});
