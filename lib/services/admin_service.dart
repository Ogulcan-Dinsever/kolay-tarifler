import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'recipe_service.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  static const String initialAdminEmail = 'ogulcandnsvr@gmail.com';

  Future<DocumentReference<Map<String, dynamic>>> _recipeReferenceForId(
    String id,
  ) async {
    final mainRef = _db.collection('recipes').doc(id);
    if ((await mainRef.get()).exists) return mainRef;
    return _db.collection(RecipeService.variationsCollection).doc(id);
  }

  // ── Admin kontrol ───────────────────────────────────────────────────────────

  Stream<bool> isAdminStream(String email) {
    return _db
        .collection('admins')
        .doc(email.toLowerCase())
        .snapshots()
        .map((s) => s.exists);
  }

  Stream<List<Map<String, dynamic>>> adminsStream() {
    return _db
        .collection('admins')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'email': d.id, ...d.data()}).toList(),
        );
  }

  // ── İlk admin tohumu ────────────────────────────────────────────────────────

  Future<void> seedInitialAdmin() async {
    final doc = await _db.collection('admins').doc(initialAdminEmail).get();
    if (!doc.exists) {
      await _db.collection('admins').doc(initialAdminEmail).set({
        'email': initialAdminEmail,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'system',
      });
    }
  }

  // ── Admin yönetimi ──────────────────────────────────────────────────────────

  Future<void> addAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    final currentEmail = _auth.currentUser?.email ?? 'admin';
    await _db.collection('admins').doc(normalized).set({
      'email': normalized,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': currentEmail,
    });
  }

  Future<void> removeAdmin(String email) async {
    final normalized = email.toLowerCase();
    if (normalized == initialAdminEmail) {
      throw Exception('Süper admin kaldırılamaz');
    }
    await _db.collection('admins').doc(normalized).delete();
  }

  // ── Topluluk moderasyonu ──────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> openReportsStream() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          reports.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });
          return reports;
        });
  }

  Future<void> resolveReport(String reportId, {bool contentRemoved = false}) {
    return _db.collection('reports').doc(reportId).update({
      'status': 'resolved',
      'contentRemoved': contentRemoved,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _auth.currentUser?.email ?? 'admin',
    });
  }

  Future<void> removeReportedContent(Map<String, dynamic> report) async {
    final type = report['targetType'] as String?;
    final targetId = report['targetId'] as String?;
    if (targetId == null) throw Exception('Hedef içerik bulunamadı');

    if (type == 'comment') {
      final recipeId = report['recipeId'] as String?;
      if (recipeId == null) throw Exception('Tarif bilgisi bulunamadı');
      final recipeRef = await _recipeReferenceForId(recipeId);
      final commentRef = recipeRef.collection('comments').doc(targetId);
      await commentRef.delete();
    } else if (type == 'recipe') {
      final recipeRef = await _recipeReferenceForId(targetId);
      await recipeRef.delete();
    } else {
      throw Exception('Bu rapor türünde silinecek tekil içerik yok');
    }

    await resolveReport(report['id'] as String, contentRemoved: true);
  }

  Future<void> suspendReportedUser(
    Map<String, dynamic> report, {
    bool removeContent = false,
  }) async {
    final reportId = report['id'] as String?;
    final targetUserId = report['targetUserId'] as String?;
    if (reportId == null || targetUserId == null || targetUserId.isEmpty) {
      throw Exception('Hedef kullanıcı bulunamadı');
    }

    if (removeContent) {
      await removeReportedContent(report);
    } else {
      await resolveReport(reportId);
    }

    await _db.collection('moderation_bans').doc(targetUserId).set({
      'userId': targetUserId,
      'reason': report['reason'] ?? 'Topluluk kuralları ihlali',
      'sourceReportId': reportId,
      'bannedAt': FieldValue.serverTimestamp(),
      'bannedBy': _auth.currentUser?.email ?? 'admin',
      'active': true,
    });
    await _db.collection('reports').doc(reportId).set({
      'userSuspended': true,
    }, SetOptions(merge: true));
  }

  // ── Resim yükleme ───────────────────────────────────────────────────────────

  Future<String> uploadImage({
    required Uint8List bytes,
    required String folder,
    required String filename,
  }) async {
    final ref = _storage.ref('$folder/$filename');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  // ── Malzeme ekleme ──────────────────────────────────────────────────────────

  Future<void> addIngredient({
    required String name,
    required String category,
    String imageUrl = '',
  }) async {
    await _db.collection('ingredients').add({
      'name': name,
      'emoji': '',
      'category': category,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Tarif ekleme ────────────────────────────────────────────────────────────

  Future<void> addRecipe({
    required String name,
    required String description,
    required String duration,
    required String cuisine,
    required String type,
    required String emoji,
    required List<String> imageUrls,
    required List<Map<String, String>> ingredients,
    required List<String> steps,
    List<String> tags = const [],
  }) async {
    final currentUser = _auth.currentUser;
    await _db.collection('recipes').add({
      'name': name,
      'description': description,
      'duration': duration,
      'cuisine': cuisine,
      'type': type,
      'emoji': emoji,
      'imageUrls': imageUrls,
      'ingredients': ingredients
          .map(
            (e) => {
              'ingredientId': e['ingredientId'] ?? '',
              'name': e['name'] ?? '',
              'amount': e['amount'] ?? '',
            },
          )
          .toList(),
      'steps': steps
          .asMap()
          .entries
          .map((e) => {'order': e.key + 1, 'text': e.value})
          .toList(),
      'tags': tags,
      'isOfficial': true,
      'recipeKind': 'main',
      'authorId': currentUser?.uid ?? 'admin',
      'authorName': currentUser?.displayName ?? 'Admin',
      'officialLikeCount': 0,
      'communityLikeCount': 0,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'modifiedAt': FieldValue.serverTimestamp(),
    });
  }
}
