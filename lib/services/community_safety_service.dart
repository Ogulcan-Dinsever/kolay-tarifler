import 'package:cloud_firestore/cloud_firestore.dart';

class CommunitySafetyService {
  CommunitySafetyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const currentTermsVersion = '2026-07-13';
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
