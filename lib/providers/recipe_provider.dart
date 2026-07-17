import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/user_activity.dart';
import '../services/recipe_service.dart';

final recipeServiceProvider = Provider<RecipeService>((ref) => RecipeService());

final ingredientsProvider = StreamProvider<List<Ingredient>>((ref) {
  return ref.watch(recipeServiceProvider).ingredientsStream();
});

final recipesByCuisineProvider = StreamProvider.family<List<Recipe>, String>((
  ref,
  cuisine,
) {
  return ref.watch(recipeServiceProvider).recipesStream(cuisine);
});

final recipeByIdProvider = FutureProvider.family<Recipe?, String>((ref, id) {
  return ref.watch(recipeServiceProvider).fetchById(id);
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((
  ref,
  recipeId,
) {
  return ref.watch(recipeServiceProvider).commentsStream(recipeId);
});

final recipeStreamProvider = StreamProvider.family<Recipe?, String>((ref, id) {
  return ref.watch(recipeServiceProvider).recipeStream(id);
});

/// Cache-first tarif stream'i — önbellekten anında gösterir,
/// modifiedAt ile değişiklik kontrolü yapar, per-recipe kayıt eder.
final cachedRecipeStreamProvider = StreamProvider.family<Recipe?, String>((
  ref,
  id,
) {
  return ref.watch(recipeServiceProvider).cachedRecipeStream(id);
});

typedef LikeParams = ({String recipeId, String userId});

final isLikedProvider = StreamProvider.family<bool, LikeParams>((ref, params) {
  return ref
      .watch(recipeServiceProvider)
      .isLikedStream(params.recipeId, params.userId);
});

/// Kullanıcının beğendiği tüm tarif ID'leri — tek Firestore listener.
/// RecipeCard'lar bu provider'ı paylaşır, kart başına listener açılmaz.
final userLikedIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  userId,
) {
  return ref.watch(recipeServiceProvider).userLikedIdsStream(userId);
});

final allRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(recipeServiceProvider).allRecipesStream();
});

/// Ana tarif listesinden türetilir; haftanın tarifi için ikinci bir Firestore
/// koleksiyon dinleyicisi açılmaz. Varyasyonlar allRecipesStream'de elenir.
final featuredRecipeProvider = Provider<AsyncValue<Recipe?>>((ref) {
  return ref.watch(allRecipesProvider).whenData((recipes) {
    if (recipes.isEmpty) return null;
    return recipes.reduce(
      (current, next) => next.recommendationScore > current.recommendationScore
          ? next
          : current,
    );
  });
});

final communityRecipesProvider = StreamProvider.family<List<Recipe>, String>((
  ref,
  parentId,
) {
  return ref.watch(recipeServiceProvider).communityRecipesStream(parentId);
});

final userCommentActivitiesProvider = StreamProvider.autoDispose
    .family<List<UserCommentActivity>, String>((ref, userId) {
      return ref
          .watch(recipeServiceProvider)
          .userCommentActivitiesStream(userId);
    });

final userLikeActivitiesProvider = StreamProvider.autoDispose
    .family<List<UserLikeActivity>, String>((ref, userId) {
      return ref.watch(recipeServiceProvider).userLikeActivitiesStream(userId);
    });
