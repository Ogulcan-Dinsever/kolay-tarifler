import 'comment.dart';
import 'recipe.dart';

class UserCommentActivity {
  final Comment comment;
  final String recipeId;
  final Recipe? recipe;

  const UserCommentActivity({
    required this.comment,
    required this.recipeId,
    required this.recipe,
  });
}

class UserLikeActivity {
  final String recipeId;
  final DateTime createdAt;
  final Recipe? recipe;

  const UserLikeActivity({
    required this.recipeId,
    required this.createdAt,
    required this.recipe,
  });
}
