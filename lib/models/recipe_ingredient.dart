import 'package:hive/hive.dart';

part 'recipe_ingredient.g.dart';

/// Bir tarifte kullanılan malzeme + miktar bilgisi.
@HiveType(typeId: 1)
class RecipeIngredient {
  @HiveField(0)
  final String ingredientId;
  @HiveField(1)
  final String name; // Firestore'dan denormalize — join yapmamak için
  @HiveField(2)
  final String amount; // "2 su bardağı", "500 gr" gibi
  @HiveField(3)
  final String? emoji;

  const RecipeIngredient({
    required this.ingredientId,
    required this.name,
    required this.amount,
    this.emoji,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> data) {
    // Firestore'da alanlar script/admin düzenlemesiyle sayı olarak yazılmış
    // olabilir — tek bozuk belge tüm listeyi düşürmesin diye toString ile oku.
    return RecipeIngredient(
      ingredientId: data['ingredientId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      amount: data['amount']?.toString() ?? '',
      emoji: data['emoji']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ingredientId': ingredientId,
        'name': name,
        'amount': amount,
        if (emoji != null) 'emoji': emoji,
      };
}
