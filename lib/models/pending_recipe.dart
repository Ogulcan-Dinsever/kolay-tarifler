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
    final d = doc.data() as Map<String, dynamic>;
    return PendingRecipe(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      cuisine: d['cuisine'] as String? ?? '',
      type: d['type'] as String? ?? '',
      duration: d['duration'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '🍽️',
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
      ingredients: (d['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      steps: (d['steps'] as List<dynamic>? ?? [])
          .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
          .toList(),
      tags: List<String>.from(d['tags'] ?? []),
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      status: _parseStatus(d['status'] as String? ?? 'pending'),
      rejectionComment: d['rejectionComment'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
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
