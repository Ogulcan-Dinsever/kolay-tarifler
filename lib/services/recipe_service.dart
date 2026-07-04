import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/comment.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../models/recipe_step.dart';
import 'recipe_cache_service.dart';


class RecipeService {
  final _db = FirebaseFirestore.instance;

  // ─── SEED ───────────────────────────────────────────────────────────────────

  Future<void> seedIfEmpty() async {
    final meta = await _db.collection('_meta').doc('seed').get();
    if (meta.exists && meta.data()?['version'] == 'json_v1') return;

    // Eski mock data varsa temizle
    final oldSnap = await _db.collection('recipes').get();
    final deleteBatch = _db.batch();
    for (final doc in oldSnap.docs) {
      deleteBatch.delete(doc.reference);
    }
    if (oldSnap.docs.isNotEmpty) await deleteBatch.commit();

    await _seedRecipesFromJson();
    await _db
        .collection('_meta')
        .doc('seed')
        .set({'version': 'json_v1', 'seededAt': FieldValue.serverTimestamp()});
  }

  Future<void> _seedRecipesFromJson() async {
    final jsonStr =
        await rootBundle.loadString('assets/data/turk_yemekleri_100.json');
    final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;

    // Malzeme adı → ID haritası (ingredientId eşleştirme için)
    final ingSnap = await _db.collection('ingredients').get();
    final nameToId = <String, String>{};
    for (final doc in ingSnap.docs) {
      final name = (doc.data()['name'] as String? ?? '').toLowerCase().trim();
      nameToId[name] = doc.id;
    }

    final batch = _db.batch();
    for (var i = 0; i < data.length; i++) {
      final raw = data[i] as Map<String, dynamic>;

      final createdAt = raw['createdAt'] is String
          ? DateTime.tryParse(raw['createdAt'] as String) ?? DateTime.now()
          : DateTime.now();

      final ingredients = (raw['ingredients'] as List<dynamic>? ?? [])
          .map((e) {
            final ing = e as Map<String, dynamic>;
            final nameKey =
                (ing['name'] as String? ?? '').toLowerCase().trim();
            return RecipeIngredient(
              ingredientId: nameToId[nameKey] ??
                  (ing['ingredientId'] as String? ?? 'ing_unknown'),
              name: ing['name'] as String? ?? '',
              amount: ing['amount'] as String? ?? '',
              emoji: ing['emoji'] as String?,
            );
          })
          .toList();

      final steps = (raw['steps'] as List<dynamic>? ?? [])
          .map((e) {
            final s = e as Map<String, dynamic>;
            return RecipeStep(
              order: (s['order'] as num?)?.toInt() ?? 0,
              text: s['text'] as String? ?? '',
              imageUrl: s['imageUrl'] as String?,
            );
          })
          .toList();

      final type = _mapRecipeType(raw['type'] as String? ?? 'Ana Yemek');
      final docId = raw['id'] as String? ?? 'recipe_${i + 1}';

      final recipe = Recipe(
        id: docId,
        name: raw['name'] as String? ?? '',
        description: raw['description'] as String? ?? '',
        cuisine: raw['cuisine'] as String? ?? 'Türk',
        type: type,
        duration: raw['duration'] as String? ?? '30 dk',
        emoji: _safeEmoji(raw['emoji'] as String?),
        imageUrls: List<String>.from(raw['imageUrls'] ?? []),
        ingredients: ingredients,
        steps: steps,
        tags: List<String>.from(raw['tags'] ?? []),
        officialLikeCount: (raw['officialLikeCount'] as num?)?.toInt() ?? 0,
        communityLikeCount: (raw['communityLikeCount'] as num?)?.toInt() ?? 0,
        likeCount: (raw['likeCount'] as num?)?.toInt() ?? 0,
        authorId: raw['authorId'] as String? ?? 'system',
        authorName: raw['authorName'] as String? ?? '',
        isOfficial: raw['isOfficial'] as bool? ?? true,
        parentRecipeId: raw['parentRecipeId'] as String?,
        commentCount: (raw['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: createdAt,
        modifiedAt: createdAt,
      );

      batch.set(_db.collection('recipes').doc(docId), recipe.toFirestore());
    }
    await batch.commit();
  }

  // ─── INGREDIENTS ────────────────────────────────────────────────────────────

  Future<void> seedIngredientsIfEmpty() async {
    final meta = await _db.collection('_meta').doc('seed_ingredients').get();
    if (meta.exists && meta.data()?['version'] == 'json_v1') return;

    // Eski mock data varsa temizle
    final oldSnap = await _db.collection('ingredients').get();
    final deleteBatch = _db.batch();
    for (final doc in oldSnap.docs) {
      deleteBatch.delete(doc.reference);
    }
    if (oldSnap.docs.isNotEmpty) await deleteBatch.commit();

    await _seedIngredientsFromJson();
    await _db.collection('_meta').doc('seed_ingredients').set(
        {'version': 'json_v1', 'seededAt': FieldValue.serverTimestamp()});
  }

  Future<void> _seedIngredientsFromJson() async {
    final jsonStr =
        await rootBundle.loadString('assets/data/turk_malzemeleri.json');
    final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;

    final batch = _db.batch();
    for (var i = 0; i < data.length; i++) {
      final raw = data[i] as Map<String, dynamic>;
      final docId = 'ing_${i + 1}';
      final ingredient = Ingredient(
        id: docId,
        name: raw['name'] as String? ?? '',
        emoji: _safeEmoji(raw['emoji'] as String?),
        imageUrl: raw['imageUrl'] as String? ?? '',
        category: _mapIngredientCategory(raw['category'] as String? ?? ''),
      );
      batch.set(
          _db.collection('ingredients').doc(docId), ingredient.toFirestore());
    }
    await batch.commit();
  }

  // ─── YARDIMCI METODLAR ───────────────────────────────────────────────────────

  static IngredientCategory _mapIngredientCategory(String raw) {
    final key = raw.trim().toLowerCase();
    const map = <String, IngredientCategory>{
      'sebze': IngredientCategory.vegetable,
      'meyve': IngredientCategory.fruit,
      'et': IngredientCategory.meat,
      'tavuk': IngredientCategory.meat,
      'et & tavuk': IngredientCategory.meat,
      'et/tavuk': IngredientCategory.meat,
      'et ve tavuk': IngredientCategory.meat,
      'kırmızı et': IngredientCategory.meat,
      'kirmizi et': IngredientCategory.meat,
      'deniz': IngredientCategory.seafood,
      'deniz ürünleri': IngredientCategory.seafood,
      'deniz urunleri': IngredientCategory.seafood,
      'balık': IngredientCategory.seafood,
      'balik': IngredientCategory.seafood,
      'süt': IngredientCategory.dairy,
      'sut': IngredientCategory.dairy,
      'süt ürünleri': IngredientCategory.dairy,
      'sut urunleri': IngredientCategory.dairy,
      'peynir': IngredientCategory.dairy,
      'tahıl': IngredientCategory.grain,
      'tahil': IngredientCategory.grain,
      'tahıl & bakliyat': IngredientCategory.grain,
      'tahil & bakliyat': IngredientCategory.grain,
      'bakliyat': IngredientCategory.grain,
      'baklagil': IngredientCategory.grain,
      'un': IngredientCategory.grain,
      'ekmek': IngredientCategory.grain,
      'yufka': IngredientCategory.grain,
      'baharat': IngredientCategory.spice,
      'yeşillik': IngredientCategory.spice,
      'yesillik': IngredientCategory.spice,
      'ot': IngredientCategory.spice,
      'taze ot': IngredientCategory.spice,
      'yağ': IngredientCategory.oil,
      'yag': IngredientCategory.oil,
      'sos': IngredientCategory.oil,
      'yağ & sos': IngredientCategory.oil,
      'yag & sos': IngredientCategory.oil,
      'kuruyemiş': IngredientCategory.nut,
      'kuruyemis': IngredientCategory.nut,
      'kuru yemiş': IngredientCategory.nut,
      'kuru yemis': IngredientCategory.nut,
      'yumurta': IngredientCategory.egg,
    };
    return map[key] ?? IngredientCategory.other;
  }

  static String _mapRecipeType(String raw) {
    const map = <String, String>{
      'kahvaltılık': 'Kahvaltılık',
      'kahvaltilik': 'Kahvaltılık',
      'kahvaltı': 'Kahvaltı',
      'kahvalti': 'Kahvaltı',
      'atıştırmalık': 'Atıştırmalık',
      'atistirmalik': 'Atıştırmalık',
      'yan yemek': 'Yan Yemek',
      'meze': 'Meze',
      'çorba': 'Çorba',
      'corba': 'Çorba',
      'ana yemek': 'Ana Yemek',
      'salata': 'Salata',
      'tatlı': 'Tatlı',
      'tatli': 'Tatlı',
      'hamur i̇şi': 'Hamur İşi',
      'hamur isi': 'Hamur İşi',
      'burger': 'Burger',
      'pide & pizza': 'Pide & Pizza',
    };
    return map[raw.toLowerCase().trim()] ?? raw;
  }

  static String _safeEmoji(String? raw) {
    if (raw == null || raw.isEmpty) return '🍽️';
    final cp = raw.runes.first;
    // Geçerli emoji aralığı: Miscellaneous Symbols ve üzeri
    if (cp >= 0x2600) return raw;
    return '🍽️';
  }

  Stream<List<Ingredient>> ingredientsStream() async* {
    final cache = RecipeCacheService();
    final cached = cache.loadIngredients();
    if (cached.isNotEmpty) yield cached;

    await for (final snap in _db
        .collection('ingredients')
        .orderBy('name')
        .snapshots()) {
      final list = snap.docs
          .map((d) => Ingredient.fromFirestore(d.data(), d.id))
          .toList();
      unawaited(cache.saveIngredients(list));
      yield list;
    }
  }

  // ─── RECIPES ────────────────────────────────────────────────────────────────

  Stream<Recipe?> featuredRecipeStream() {
    return _db
        .collection('recipes')
        .orderBy('officialLikeCount', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : Recipe.fromFirestore(snap.docs.first));
  }

  Stream<List<Recipe>> recipesStream(String cuisine) async* {
    final cache = RecipeCacheService();
    final cached = cache.loadRecipes()
        .where((r) => r.cuisine == cuisine)
        .toList()
      ..sort((a, b) => b.officialLikeCount.compareTo(a.officialLikeCount));
    if (cached.isNotEmpty) yield cached;

    await for (final snap in _db
        .collection('recipes')
        .where('cuisine', isEqualTo: cuisine)
        .snapshots()) {
      final list = snap.docs.map(Recipe.fromFirestore).toList()
        ..sort((a, b) => b.officialLikeCount.compareTo(a.officialLikeCount));
      unawaited(cache.saveRecipes(list));
      yield list;
    }
  }

  Stream<List<Recipe>> allRecipesStream() async* {
    final cache = RecipeCacheService();
    final cached = cache.loadRecipes();
    if (cached.isNotEmpty) yield cached;

    await for (final snap in _db.collection('recipes').snapshots()) {
      final list = snap.docs.map(Recipe.fromFirestore).toList()
        ..sort((a, b) => b.officialLikeCount.compareTo(a.officialLikeCount));
      unawaited(cache.saveRecipes(list));
      yield list;
    }
  }

  /// Tüm tarifleri tek seferlik çeker — splash pre-warm için kullanılır.
  Future<List<Recipe>> fetchAllRecipesOnce() async {
    final snap = await _db.collection('recipes').get();
    return snap.docs.map(Recipe.fromFirestore).toList()
      ..sort((a, b) => b.officialLikeCount.compareTo(a.officialLikeCount));
  }

  /// Cache-first tarif stream'i.
  /// 1) Önbellekten anında göster (offline çalışır)
  /// 2) Firebase snapshot'ı dinle
  ///    - modifiedAt eşleşiyorsa: sadece likeCount/commentCount değişince yield et
  ///    - modifiedAt farklıysa: yeni içeriği önbelleğe kaydet, yield et
  Stream<Recipe?> cachedRecipeStream(String id) async* {
    final cache = RecipeCacheService();
    final docRef = _db.collection('recipes').doc(id);

    Recipe? current = cache.loadRecipeById(id);
    if (current != null) yield current;

    await for (final snap in docRef.snapshots()) {
      if (!snap.exists) {
        if (current == null) yield null;
        return;
      }

      final fresh = Recipe.fromFirestore(snap);
      final bool contentSame = current != null &&
          current.modifiedAt != null &&
          fresh.modifiedAt != null &&
          current.modifiedAt == fresh.modifiedAt;

      if (contentSame) {
        // İçerik değişmedi — sadece canlı sayacları güncelle
        if (current.likeCount != fresh.likeCount ||
            current.commentCount != fresh.commentCount) {
          current = fresh;
          yield fresh;
        }
      } else {
        // Yeni versiyon veya ilk yükleme — kaydet ve göster
        current = fresh;
        unawaited(cache.saveRecipeById(fresh));
        yield fresh;
      }
    }
  }

  Future<Recipe?> fetchById(String id) async {
    final doc = await _db.collection('recipes').doc(id).get();
    if (!doc.exists) return null;
    return Recipe.fromFirestore(doc);
  }

  Stream<Recipe?> recipeStream(String id) {
    return _db.collection('recipes').doc(id).snapshots().map(
          (doc) => doc.exists ? Recipe.fromFirestore(doc) : null,
        );
  }

  // ─── LIKES ──────────────────────────────────────────────────────────────────

  /// Kullanıcının beğendiği tüm tarif ID'lerini TEK bir collectionGroup
  /// sorgusuyla getirir — her kart için ayrı listener açmak yerine.
  Stream<Set<String>> userLikedIdsStream(String userId) {
    return _db
        .collectionGroup('likes')
        .where(FieldPath.documentId, isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.reference.parent.parent?.id)
            .whereType<String>()
            .toSet());
  }

  Stream<bool> isLikedStream(String recipeId, String userId) {
    return _db
        .collection('recipes')
        .doc(recipeId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike(String recipeId, String userId) async {
    final likeRef = _db
        .collection('recipes')
        .doc(recipeId)
        .collection('likes')
        .doc(userId);
    final recipeRef = _db.collection('recipes').doc(recipeId);

    await _db.runTransaction((tx) async {
      final likeDoc = await tx.get(likeRef);
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(recipeRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(recipeRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) return [];
    final lower = query.toLowerCase();
    // Önce yerel cache'den ara — Firestore'dan tüm koleksiyonu indirmekten kaçın
    final cached = RecipeCacheService().loadRecipes();
    final source = cached.isNotEmpty
        ? cached
        : (await _db.collection('recipes').get())
            .docs
            .map(Recipe.fromFirestore)
            .toList();
    return source
        .where((r) =>
            r.name.toLowerCase().contains(lower) ||
            r.description.toLowerCase().contains(lower))
        .toList();
  }

  Future<List<Recipe>> recipesByIngredients(List<String> ingredientIds) async {
    if (ingredientIds.isEmpty) return [];
    // Önce yerel cache'den filtrele — Firestore'dan tüm koleksiyonu indirmekten kaçın
    final cached = RecipeCacheService().loadRecipes();
    final source = cached.isNotEmpty
        ? cached
        : (await _db.collection('recipes').get())
            .docs
            .map(Recipe.fromFirestore)
            .toList();
    final idSet = ingredientIds.toSet();
    return source
        .where((recipe) {
          final ids = recipe.ingredients.map((i) => i.ingredientId).toSet();
          return ids.intersection(idSet).isNotEmpty;
        })
        .toList()
      ..sort((a, b) {
        final aMatch = a.ingredients
            .where((i) => idSet.contains(i.ingredientId))
            .length;
        final bMatch = b.ingredients
            .where((i) => idSet.contains(i.ingredientId))
            .length;
        return bMatch.compareTo(aMatch);
      });
  }

  // ─── COMMUNITY RECIPES ──────────────────────────────────────────────────────

  Stream<List<Recipe>> communityRecipesStream(String parentRecipeId) {
    return _db
        .collection('recipes')
        .where('parentRecipeId', isEqualTo: parentRecipeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Recipe.fromFirestore).toList();
      // Beğeni + yorum toplamına göre sırala
      list.sort((a, b) =>
          (b.likeCount + b.commentCount)
              .compareTo(a.likeCount + a.commentCount));
      return list;
    });
  }

  Future<String> createSubRecipe({
    required String parentRecipeId,
    required String authorId,
    required String authorName,
    required String name,
    required String description,
    required String emoji,
    required String duration,
    required String cuisine,
    required List<RecipeIngredient> ingredients,
    required List<RecipeStep> steps,
    List<String> imageUrls = const [],
  }) async {
    final docRef = _db.collection('recipes').doc();
    final recipe = Recipe(
      id: docRef.id,
      name: name,
      description: description,
      cuisine: cuisine,
      type: 'Topluluk',
      duration: duration,
      emoji: emoji,
      imageUrls: imageUrls,
      ingredients: ingredients,
      steps: steps,
      authorId: authorId,
      authorName: authorName,
      isOfficial: false,
      parentRecipeId: parentRecipeId,
      createdAt: DateTime.now(),
    );
    await docRef.set(recipe.toFirestore());
    return docRef.id;
  }

  // ─── ADMIN: GÜNCELLEME ──────────────────────────────────────────────────────

  Future<void> updateRecipe({
    required String id,
    required String name,
    required String description,
    required String emoji,
    required String duration,
    required String cuisine,
    required String type,
    required List<RecipeIngredient> ingredients,
    required List<RecipeStep> steps,
    required List<String> imageUrls,
    required List<String> tags,
  }) async {
    await _db.collection('recipes').doc(id).update({
      'name': name,
      'description': description,
      'emoji': emoji,
      'duration': duration,
      'cuisine': cuisine,
      'type': type,
      'ingredients': ingredients.map((e) => e.toMap()).toList(),
      'steps': steps.map((e) => e.toMap()).toList(),
      'imageUrls': imageUrls,
      'tags': tags,
      'modifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadRecipeImage(String recipeId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final ref = FirebaseStorage.instance
        .ref('recipes/$recipeId/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    return await ref.getDownloadURL();
  }

  // ─── COMMENTS ───────────────────────────────────────────────────────────────

  Future<void> addComment(Comment comment) async {
    final batch = _db.batch();
    final commentRef = _db
        .collection('recipes')
        .doc(comment.recipeId)
        .collection('comments')
        .doc();
    batch.set(commentRef, comment.toFirestore());
    batch.update(
      _db.collection('recipes').doc(comment.recipeId),
      {'commentCount': FieldValue.increment(1)},
    );
    await batch.commit();
  }

  Stream<List<Comment>> commentsStream(String recipeId) {
    return _db
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Comment.fromFirestore).toList());
  }
}
