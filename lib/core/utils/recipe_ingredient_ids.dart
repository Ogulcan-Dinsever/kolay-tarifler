import '../../models/ingredient.dart';
import '../../models/recipe.dart';

/// Resolves recipe ingredient references to the IDs emitted by the ingredient
/// selector. Older Firestore recipes can contain stale or blank ingredientId
/// values, so the denormalized ingredient name is used as a safe fallback.
Set<String> resolvedRecipeIngredientIds(
  Recipe recipe,
  Iterable<Ingredient> ingredients,
) {
  final ingredientIds = {for (final ingredient in ingredients) ingredient.id};
  final idsByNormalizedName = {
    for (final ingredient in ingredients)
      _normalize(ingredient.name): ingredient.id,
  };

  return {
    for (final recipeIngredient in recipe.ingredients)
      _resolveIngredientId(
        recipeIngredient.ingredientId,
        recipeIngredient.name,
        ingredientIds,
        idsByNormalizedName,
      ),
  }..remove('');
}

String _resolveIngredientId(
  String ingredientId,
  String ingredientName,
  Set<String> knownIds,
  Map<String, String> idsByNormalizedName,
) {
  if (knownIds.contains(ingredientId)) return ingredientId;
  return idsByNormalizedName[_normalize(ingredientName)] ?? ingredientId;
}

String _normalize(String value) => value
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
