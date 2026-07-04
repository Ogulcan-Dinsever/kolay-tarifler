import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pending_recipe.dart';
import '../services/pending_recipe_service.dart';

final pendingRecipeServiceProvider =
    Provider<PendingRecipeService>((ref) => PendingRecipeService());

final pendingRecipesProvider = StreamProvider<List<PendingRecipe>>((ref) {
  return ref.watch(pendingRecipeServiceProvider).pendingRecipesStream();
});

final userSubmissionsProvider =
    StreamProvider.family<List<PendingRecipe>, String>((ref, userId) {
  return ref.watch(pendingRecipeServiceProvider).userSubmissionsStream(userId);
});
