import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'recipe_ingredient.dart';
import 'recipe_step.dart';

part 'recipe.g.dart';

@HiveType(typeId: 4)
class Recipe {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final String cuisine;
  @HiveField(4)
  final String type;
  @HiveField(5)
  final String duration;
  @HiveField(6)
  final String emoji;
  @HiveField(7)
  final List<String> imageUrls;
  @HiveField(8)
  final List<RecipeIngredient> ingredients;
  @HiveField(9)
  final List<RecipeStep> steps;
  @HiveField(10)
  final List<String> tags;
  @HiveField(11)
  final int officialLikeCount;
  @HiveField(12)
  final int communityLikeCount;
  @HiveField(13)
  final int likeCount;
  @HiveField(14)
  final String authorId;
  @HiveField(15)
  final String authorName;
  @HiveField(16)
  final bool isOfficial;
  @HiveField(17)
  final String? parentRecipeId;
  @HiveField(18)
  final int commentCount;
  @HiveField(19)
  final DateTime createdAt;
  @HiveField(20)
  final DateTime? modifiedAt;
  @HiveField(21, defaultValue: '')
  final String servings;
  @HiveField(22, defaultValue: [])
  final List<Map<String, dynamic>> imageSources;

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.type,
    required this.duration,
    required this.emoji,
    this.imageUrls = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    this.officialLikeCount = 0,
    this.communityLikeCount = 0,
    this.likeCount = 0,
    required this.authorId,
    this.authorName = '',
    this.isOfficial = true,
    this.parentRecipeId,
    this.commentCount = 0,
    required this.createdAt,
    this.modifiedAt,
    this.servings = '',
    this.imageSources = const [],
  });

  bool get communityLeads =>
      !isOfficial &&
      officialLikeCount > 0 &&
      communityLikeCount / officialLikeCount >= 1.5;

  int get totalLikes => officialLikeCount + communityLikeCount;

  // ─── JSON (legacy — artık kullanılmıyor, Hive doğrudan binary saklar) ────────

  factory Recipe.fromJson(Map<String, dynamic> data) {
    return Recipe(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      cuisine: data['cuisine'] as String,
      type: data['type'] as String,
      duration: data['duration'] as String,
      servings: data['servings'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '🍽️',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imageSources: _imageSourcesFrom(data['imageSources']),
      ingredients: (data['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      steps: (data['steps'] as List<dynamic>? ?? [])
          .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
          .toList(),
      tags: List<String>.from(data['tags'] ?? []),
      officialLikeCount: data['officialLikeCount'] as int? ?? 0,
      communityLikeCount: data['communityLikeCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String? ?? '',
      isOfficial: data['isOfficial'] as bool? ?? true,
      parentRecipeId: data['parentRecipeId'] as String?,
      commentCount: data['commentCount'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      modifiedAt: data['modifiedAt'] != null
          ? DateTime.tryParse(data['modifiedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'cuisine': cuisine,
    'type': type,
    'duration': duration,
    'servings': servings,
    'emoji': emoji,
    'imageUrls': imageUrls,
    'imageSources': imageSources,
    'ingredients': ingredients.map((e) => e.toMap()).toList(),
    'steps': steps.map((e) => e.toMap()).toList(),
    'tags': tags,
    'officialLikeCount': officialLikeCount,
    'communityLikeCount': communityLikeCount,
    'likeCount': likeCount,
    'authorId': authorId,
    'authorName': authorName,
    'isOfficial': isOfficial,
    if (parentRecipeId != null) 'parentRecipeId': parentRecipeId,
    'commentCount': commentCount,
    'createdAt': createdAt.toIso8601String(),
    if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
  };

  // ─── Firestore ───────────────────────────────────────────────────────────────

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    // Alan tipleri Firestore'da garanti değil (script/admin düzenlemeleri sayı
    // yazmış olabilir) — String alanları toString ile oku ki tek bozuk belge
    // tüm stream'i düşürmesin.
    return Recipe(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      cuisine: data['cuisine']?.toString() ?? 'Türk',
      type: data['type']?.toString() ?? 'Ana Yemek',
      duration: data['duration']?.toString() ?? '',
      servings: data['servings']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '🍽️',
      imageUrls: ((data['imageUrls'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      imageSources: _imageSourcesFrom(data['imageSources']),
      ingredients: (data['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      steps: (data['steps'] as List<dynamic>? ?? [])
          .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
          .toList(),
      tags: ((data['tags'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      officialLikeCount: (data['officialLikeCount'] as num?)?.toInt() ?? 0,
      communityLikeCount: (data['communityLikeCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? '',
      isOfficial: data['isOfficial'] as bool? ?? true,
      parentRecipeId: data['parentRecipeId']?.toString(),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                DateTime.now(),
      modifiedAt: data['modifiedAt'] is Timestamp
          ? (data['modifiedAt'] as Timestamp).toDate()
          : data['modifiedAt'] != null
          ? DateTime.tryParse(data['modifiedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'cuisine': cuisine,
    'type': type,
    'duration': duration,
    'servings': servings,
    'emoji': emoji,
    'imageUrls': imageUrls,
    'imageSources': imageSources,
    'ingredients': ingredients.map((e) => e.toMap()).toList(),
    'steps': steps.map((e) => e.toMap()).toList(),
    'tags': tags,
    'officialLikeCount': officialLikeCount,
    'communityLikeCount': communityLikeCount,
    'likeCount': likeCount,
    'authorId': authorId,
    'authorName': authorName,
    'isOfficial': isOfficial,
    if (parentRecipeId != null) 'parentRecipeId': parentRecipeId,
    'commentCount': commentCount,
    'createdAt': Timestamp.fromDate(createdAt),
    if (modifiedAt != null) 'modifiedAt': Timestamp.fromDate(modifiedAt!),
  };

  static List<Map<String, dynamic>> _imageSourcesFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (source) =>
              source.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }
}

class MockCuisines {
  static const List<Map<String, String>> all = [
    {'flag': '🇹🇷', 'name': 'Türk'},
    {'flag': '🇮🇹', 'name': 'İtalyan'},
    {'flag': '🇯🇵', 'name': 'Japon'},
    {'flag': '🇲🇽', 'name': 'Meksika'},
    {'flag': '🇫🇷', 'name': 'Fransız'},
    {'flag': '🇮🇳', 'name': 'Hint'},
  ];
}

class RecipeTypes {
  static const List<Map<String, String>> all = [
    {'emoji': '🍲', 'name': 'Çorba'},
    {'emoji': '🥩', 'name': 'Ana Yemek'},
    {'emoji': '🥗', 'name': 'Salata'},
    {'emoji': '🍮', 'name': 'Tatlı'},
    {'emoji': '🥙', 'name': 'Hamur İşi'},
    {'emoji': '🍳', 'name': 'Kahvaltı'},
    {'emoji': '🍔', 'name': 'Burger'},
    {'emoji': '🍕', 'name': 'Pide & Pizza'},
    {'emoji': '🫙', 'name': 'Meze'},
    {'emoji': '🍽️', 'name': 'Yan Yemek'},
    {'emoji': '🥪', 'name': 'Atıştırmalık'},
    {'emoji': '🥞', 'name': 'Kahvaltılık'},
  ];
}
