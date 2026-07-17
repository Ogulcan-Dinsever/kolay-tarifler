import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/services/recipe_service.dart';

Recipe _recipe({
  required String id,
  required bool isOfficial,
  String? parentRecipeId,
}) {
  return Recipe(
    id: id,
    name: id,
    description: 'Açıklama',
    cuisine: 'Türk',
    type: 'Ana Yemek',
    duration: '30 dk',
    emoji: '🍲',
    authorId: 'user-1',
    authorName: 'Test Kullanıcı',
    isOfficial: isOfficial,
    parentRecipeId: parentRecipeId,
    createdAt: DateTime.utc(2026, 7, 17),
  );
}

void main() {
  group('Recipe hierarchy', () {
    test('approved user submission is a discoverable main recipe', () {
      final recipe = _recipe(id: 'user-main', isOfficial: false);

      expect(recipe.isMainRecipe, isTrue);
      expect(recipe.isUserSubmittedMain, isTrue);
      expect(recipe.isVariation, isFalse);
      expect(recipe.canHaveVariations, isTrue);
      expect(recipe.recipeKind, Recipe.mainKind);
      expect(recipe.toFirestore()['recipeKind'], Recipe.mainKind);
      expect(recipe.toFirestore().containsKey('parentRecipeId'), isFalse);
    });

    test('community recipe is a one-level variation', () {
      final recipe = _recipe(
        id: 'variation',
        isOfficial: false,
        parentRecipeId: 'main-recipe',
      );

      expect(recipe.isMainRecipe, isFalse);
      expect(recipe.isUserSubmittedMain, isFalse);
      expect(recipe.isVariation, isTrue);
      expect(recipe.canHaveVariations, isFalse);
      expect(recipe.recipeKind, Recipe.variationKind);
      expect(recipe.toFirestore()['recipeKind'], Recipe.variationKind);
      expect(recipe.toFirestore()['parentRecipeId'], 'main-recipe');
    });

    test('discoverable lists exclude variations but include user mains', () {
      final official = _recipe(id: 'official', isOfficial: true);
      final userMain = _recipe(id: 'user-main', isOfficial: false);
      final variation = _recipe(
        id: 'variation',
        isOfficial: false,
        parentRecipeId: official.id,
      );

      final result = RecipeService.discoverableRecipes([
        official,
        variation,
        userMain,
      ]);

      expect(result.map((recipe) => recipe.id), ['official', 'user-main']);
    });
  });
}
