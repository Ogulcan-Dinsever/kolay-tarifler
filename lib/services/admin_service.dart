import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  static const String initialAdminEmail = 'ogulcandnsvr@gmail.com';

  // ── Admin kontrol ───────────────────────────────────────────────────────────

  Stream<bool> isAdminStream(String email) {
    return _db
        .collection('admins')
        .doc(email.toLowerCase())
        .snapshots()
        .map((s) => s.exists);
  }

  Stream<List<Map<String, dynamic>>> adminsStream() {
    return _db.collection('admins').snapshots().map(
          (snap) => snap.docs
              .map((d) => {'email': d.id, ...d.data()})
              .toList(),
        );
  }

  // ── İlk admin tohumu ────────────────────────────────────────────────────────

  Future<void> seedInitialAdmin() async {
    final doc = await _db
        .collection('admins')
        .doc(initialAdminEmail)
        .get();
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
          .map((e) => {
                'ingredientId': e['ingredientId'] ?? '',
                'name': e['name'] ?? '',
                'amount': e['amount'] ?? '',
              })
          .toList(),
      'steps': steps
          .asMap()
          .entries
          .map((e) => {
                'order': e.key + 1,
                'text': e.value,
              })
          .toList(),
      'tags': tags,
      'isOfficial': true,
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
