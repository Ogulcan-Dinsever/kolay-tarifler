import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/pending_recipe.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../models/recipe_step.dart';

class PendingRecipeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  // ── Fotoğraf yükleme ───────────────────────────────────────────────────────

  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Fotoğraf yüklemek için giriş yapmalısınız');
    }
    final ref = _storage.ref('pending_recipes/${user.uid}/$filename');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Yüklenen ama tarife bağlanmayan fotoğrafları siler (hata durumunda orphan temizliği).
  Future<void> deleteImages(List<String> urls) async {
    for (final url in urls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {}
    }
  }

  // ── Tarif gönderme ─────────────────────────────────────────────────────────

  Future<void> submitRecipe({
    required String name,
    required String description,
    required String cuisine,
    required String type,
    required String duration,
    required String emoji,
    required List<String> imageUrls,
    required List<RecipeIngredient> ingredients,
    required List<RecipeStep> steps,
    List<String> tags = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Tarif göndermek için giriş yapmalısınız');
    }
    final docRef = _db.collection('pending_recipes').doc();
    final recipe = PendingRecipe(
      id: docRef.id,
      name: name,
      description: description,
      cuisine: cuisine,
      type: type,
      duration: duration,
      emoji: emoji,
      imageUrls: imageUrls,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
      authorId: user.uid,
      authorName: user.displayName ?? user.email ?? 'Kullanıcı',
      status: PendingStatus.pending,
      createdAt: DateTime.now(),
    );
    await docRef.set(recipe.toFirestore());
  }

  // ── Kullanıcının kendi başvuruları ─────────────────────────────────────────

  Stream<List<PendingRecipe>> userSubmissionsStream(String userId) {
    return _db
        .collection('pending_recipes')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PendingRecipe.fromFirestore).toList());
  }

  // ── Admin: bekleyen başvurular ─────────────────────────────────────────────

  Stream<List<PendingRecipe>> pendingRecipesStream() {
    return _db
        .collection('pending_recipes')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(PendingRecipe.fromFirestore).toList());
  }

  // ── Admin: onayla ──────────────────────────────────────────────────────────

  Future<void> approveRecipe(PendingRecipe pending) async {
    final batch = _db.batch();

    // pending_recipes koleksiyonunda status güncelle
    final pendingRef = _db.collection('pending_recipes').doc(pending.id);
    batch.update(pendingRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    // recipes koleksiyonuna ekle
    final recipeRef = _db.collection('recipes').doc();
    final now = DateTime.now();
    final recipe = Recipe(
      id: recipeRef.id,
      name: pending.name,
      description: pending.description,
      cuisine: pending.cuisine,
      type: pending.type,
      duration: pending.duration,
      emoji: pending.emoji,
      imageUrls: pending.imageUrls,
      ingredients: pending.ingredients,
      steps: pending.steps,
      tags: pending.tags,
      authorId: pending.authorId,
      authorName: pending.authorName,
      isOfficial: false,
      likeCount: 0,
      officialLikeCount: 0,
      communityLikeCount: 0,
      commentCount: 0,
      createdAt: now,
      modifiedAt: now,
    );
    batch.set(recipeRef, recipe.toFirestore());

    await batch.commit();
  }

  // ── Admin: reddet ──────────────────────────────────────────────────────────

  Future<void> rejectRecipe(
    String pendingId,
    String comment, {
    List<String> imageUrls = const [],
  }) async {
    await _db.collection('pending_recipes').doc(pendingId).update({
      'status': 'rejected',
      'rejectionComment': comment.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    // Reddedilen başvurunun fotoğrafları Storage'da sonsuza dek birikmesin.
    // Firestore güncellemesi başarılı olduktan sonra sil; silme hatası
    // (deleteImages içinde yutulur) red işlemini geri almaz.
    if (imageUrls.isNotEmpty) {
      await deleteImages(imageUrls);
    }
  }
}
