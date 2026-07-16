import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/services/recipe_service.dart';

Recipe _recipe(String id, String name) => Recipe(
  id: id,
  name: name,
  description: '',
  cuisine: 'Türk',
  type: 'Ana Yemek',
  duration: '30 dk',
  emoji: '🍽️',
  authorId: 'test',
  createdAt: DateTime(2026),
);

void main() {
  test(
    'cuisine recipes are ordered alphabetically with a stable id tie-break',
    () {
      final recipes = [
        _recipe('2', 'Zeytinyağlı Dolma'),
        _recipe('2', 'Baklava'),
        _recipe('1', 'Baklava'),
        _recipe('3', 'Ayran'),
      ]..sort(RecipeService.compareRecipesAlphabetically);

      expect(recipes.map((recipe) => recipe.id), ['3', '1', '2', '2']);
      expect(recipes.map((recipe) => recipe.name), [
        'Ayran',
        'Baklava',
        'Baklava',
        'Zeytinyağlı Dolma',
      ]);
    },
  );
}
