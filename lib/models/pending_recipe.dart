import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_ingredient.dart';
import 'recipe_step.dart';

enum PendingStatus { pending, approved, rejected }

class PendingRecipe {
  final String id;
  final String name;
  final String description;
  final String cuisine;
  final String type;
  final String duration;
  final String emoji;
  final List<String> imageUrls;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tags;
  final String authorId;
  final String authorName;
  final PendingStatus status;
  final String? rejectionComment;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const PendingRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.type,
    required this.duration,
    required this.emoji,
    required this.imageUrls,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.authorId,
    required this.authorName,
    required this.status,
    required this.createdAt,
    this.rejectionComment,
    this.reviewedAt,
  });

  factory PendingRecipe.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final d = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    String stringValue(String key, [String fallback = '']) =>
        d[key] is String ? d[key] as String : fallback;
    final ingredients = d['ingredients'] is List
        ? (d['ingredients'] as List)
              .whereType<Map>()
              .map(
                (item) => RecipeIngredient.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : <RecipeIngredient>[];
    final steps = d['steps'] is List
        ? (d['steps'] as List)
              .whereType<Map>()
              .map(
                (item) => RecipeStep.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : <RecipeStep>[];
    final createdAt = d['createdAt'];
    final reviewedAt = d['reviewedAt'];
    return PendingRecipe(
      id: doc.id,
      name: stringValue('name'),
      description: stringValue('description'),
      cuisine: stringValue('cuisine'),
      type: stringValue('type'),
      duration: stringValue('duration'),
      emoji: stringValue('emoji', '🍽️'),
      imageUrls: d['imageUrls'] is List
          ? (d['imageUrls'] as List).whereType<String>().toList()
          : const [],
      ingredients: ingredients,
      steps: steps,
      tags: d['tags'] is List
          ? (d['tags'] as List).whereType<String>().toList()
          : const [],
      authorId: stringValue('authorId'),
      authorName: stringValue('authorName'),
      status: _parseStatus(stringValue('status', 'pending')),
      rejectionComment: d['rejectionComment'] is String
          ? d['rejectionComment'] as String
          : null,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      reviewedAt: reviewedAt is Timestamp ? reviewedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'cuisine': cuisine,
    'type': type,
    'duration': duration,
    'emoji': emoji,
    'imageUrls': imageUrls,
    'ingredients': ingredients.map((e) => e.toMap()).toList(),
    'steps': steps.map((e) => e.toMap()).toList(),
    'tags': tags,
    'authorId': authorId,
    'authorName': authorName,
    'status': status.name,
    'rejectionComment': rejectionComment,
    'createdAt': FieldValue.serverTimestamp(),
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
  };

  static PendingStatus _parseStatus(String s) {
    switch (s) {
      case 'approved':
        return PendingStatus.approved;
      case 'rejected':
        return PendingStatus.rejected;
      default:
        return PendingStatus.pending;
    }
  }
}
