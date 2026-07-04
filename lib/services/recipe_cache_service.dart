import 'package:hive_flutter/hive_flutter.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';

/// Hive tabanlı yerel cache.
/// Box'lar main.dart'ta açılır; buradaki metodlar her zaman açık box'a erişir.
class RecipeCacheService {
  static const recipesBoxName = 'recipes';
  static const ingredientsBoxName = 'ingredients';

  Box<Recipe> get _recipes => Hive.box<Recipe>(recipesBoxName);
  Box<Ingredient> get _ingredients => Hive.box<Ingredient>(ingredientsBoxName);

  // ─── Tarifler ───────────────────────────────────────────────────────────────

  List<Recipe> loadRecipes() => _recipes.values.toList();

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final map = {for (final r in recipes) r.id: r};
    await _recipes.putAll(map);
  }

  // ─── Malzemeler ─────────────────────────────────────────────────────────────

  List<Ingredient> loadIngredients() => _ingredients.values.toList();

  Future<void> saveIngredients(List<Ingredient> ingredients) async {
    final map = {for (final i in ingredients) i.id: i};
    await _ingredients.putAll(map);
  }

  // ─── Tekil tarif ────────────────────────────────────────────────────────────

  Recipe? loadRecipeById(String id) => _recipes.get(id);

  Future<void> saveRecipeById(Recipe recipe) async {
    await _recipes.put(recipe.id, recipe);
  }
}
