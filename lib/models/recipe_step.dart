import 'package:hive/hive.dart';

part 'recipe_step.g.dart';

@HiveType(typeId: 2)
class RecipeStep {
  @HiveField(0)
  final int order;
  @HiveField(1)
  final String text;
  @HiveField(2)
  final String? imageUrl;

  const RecipeStep({
    required this.order,
    required this.text,
    this.imageUrl,
  });

  factory RecipeStep.fromMap(Map<String, dynamic> data) {
    // Firestore'daki tip tutarsızlıklarına dayanıklı oku (bkz. RecipeIngredient.fromMap).
    return RecipeStep(
      order: (data['order'] as num?)?.toInt() ?? 0,
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'order': order,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}
