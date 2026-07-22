import 'package:cloud_firestore/cloud_firestore.dart';

class CommunitySafetyService {
  CommunitySafetyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const currentTermsVersion = '2026-07-22';
  final FirebaseFirestore _db;

  Future<bool> hasAcceptedTerms(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['communityTermsVersion'] == currentTermsVersion;
  }

  Future<void> acceptTerms(String userId) {
    return _db.collection('users').doc(userId).set({
      'communityTermsVersion': currentTermsVersion,
      'communityTermsAcceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Set<String>> blockedUserIdsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> blockUser({
    required String userId,
    required String blockedUserId,
  }) {
    if (userId == blockedUserId) {
      throw ArgumentError('Kullanıcı kendisini engelleyemez.');
    }
    return _db
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .doc(blockedUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  /// Blocks the user locally and simultaneously creates a developer-visible
  /// moderation report. The caller's feed removes the user's content as soon
  /// as the blocked-user snapshot updates.
  Future<void> blockAndReportUser({
    required String userId,
    required String blockedUserId,
    required String targetType,
    required String targetId,
    String? recipeId,
  }) async {
    if (userId == blockedUserId) {
      throw ArgumentError('Kullanıcı kendisini engelleyemez.');
    }

    final blockRef = _db
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .doc(blockedUserId);
    final reportRef = _db.collection('reports').doc();
    final batch = _db.batch();
    batch.set(blockRef, {'blockedAt': FieldValue.serverTimestamp()});
    batch.set(reportRef, {
      'reporterId': userId,
      'targetType': targetType,
      'targetId': targetId,
      'targetUserId': blockedUserId,
      'reason': 'Kullanıcı engellendi — otomatik güvenlik bildirimi',
      'recipeId': ?recipeId,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> unblockUser({
    required String userId,
    required String blockedUserId,
  }) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .doc(blockedUserId)
        .delete();
  }

  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String targetUserId,
    required String reason,
    String? recipeId,
  }) {
    final data = <String, dynamic>{
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'targetUserId': targetUserId,
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (recipeId != null) data['recipeId'] = recipeId;
    return _db.collection('reports').add(data);
  }
}
