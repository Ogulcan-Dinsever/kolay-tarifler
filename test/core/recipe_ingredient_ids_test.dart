import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/core/utils/recipe_ingredient_ids.dart';
import 'package:kolay_tarifler/models/ingredient.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/models/recipe_ingredient.dart';

void main() {
  test('resolves stale recipe IDs from a Turkish ingredient name', () {
    const mincedMeat = Ingredient(
      id: 'ingredient-kiyma',
      name: 'Kıyma',
      emoji: '🥩',
      category: IngredientCategory.meat,
    );
    final recipe = Recipe(
      id: 'izmir-kofte',
      name: 'İzmir Köfte',
      description: '',
      cuisine: 'Türk',
      type: '',
      duration: '',
      emoji: '🍲',
      authorId: '',
      createdAt: DateTime(2026),
      ingredients: const [
        RecipeIngredient(
          ingredientId: 'old-kiyma-id',
          name: 'KIYMA',
          amount: '500 g',
        ),
      ],
    );

    expect(resolvedRecipeIngredientIds(recipe, [mincedMeat]), {
      'ingredient-kiyma',
    });
  });

  test('keeps a valid recipe ingredient ID without relying on its name', () {
    const oregano = Ingredient(
      id: 'ingredient-kekik',
      name: 'Kekik',
      emoji: '🌿',
      category: IngredientCategory.spice,
    );
    final recipe = Recipe(
      id: 'salata',
      name: 'Salata',
      description: '',
      cuisine: 'Türk',
      type: '',
      duration: '',
      emoji: '🥗',
      authorId: '',
      createdAt: DateTime(2026),
      ingredients: const [
        RecipeIngredient(
          ingredientId: 'ingredient-kekik',
          name: '',
          amount: '1 çay kaşığı',
        ),
      ],
    );

    expect(resolvedRecipeIngredientIds(recipe, [oregano]), {
      'ingredient-kekik',
    });
  });
}
