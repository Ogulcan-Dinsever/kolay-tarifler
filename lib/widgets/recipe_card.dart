import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/format.dart';
import '../core/utils/responsive.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';

class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseUserProvider.select((a) => a.valueOrNull));
    final isAuth = user != null && !user.isAnonymous;

    // Tek bir collectionGroup listener tüm kartlar arasında paylaşılır;
    // kart başına ayrı Firestore dinleyicisi açılmaz.
    final isLiked = isAuth
        ? (ref.watch(userLikedIdsProvider(user.uid)).valueOrNull ?? {})
            .contains(recipe.id)
        : false;

    return RepaintBoundary(
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: context.rs(10)),
        padding: EdgeInsets.all(context.rs(10)),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.border, width: 1.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: recipe.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: recipe.imageUrls.first,
                      width: context.rs(68),
                      height: context.rs(68),
                      fit: BoxFit.cover,
                      placeholder: (_, url) => _emojiThumb(context),
                      errorWidget: (_, url, err) => _emojiThumb(context),
                    )
                  : _emojiThumb(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recipe.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: recipe.tags
                        .map((tag) => _buildTag(context, tag))
                        .toList(),
                  ),
                  if (!recipe.isOfficial && recipe.authorName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12,
                            color: context.palette.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          recipe.authorName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (!isAuth) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Beğenmek için giriş yapın'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    await ref
                        .read(recipeServiceProvider)
                        .toggleLike(recipe.id, user.uid);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isLiked
                          ? const Color(0xFFFFE0D9)
                          : const Color(0xFFFFF3F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLiked
                            ? AppColors.accent
                            : const Color(0xFFFFD6C7),
                      ),
                    ),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: isLiked ? AppColors.accent : Colors.grey,
                    ),
                  ),
                ),
                if (recipe.likeCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatCount(recipe.likeCount),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isLiked
                          ? AppColors.accent
                          : context.palette.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '⏱ ${recipe.duration}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  Widget _emojiThumb(BuildContext context) {
    final size = context.rs(68);
    return Container(
      width: size,
      height: size,
      color: context.palette.g50,
      child: Center(
          child: Text(recipe.emoji, style: TextStyle(fontSize: context.sp(30)))),
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.g50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.palette.textPrimary,
        ),
      ),
    );
  }

}
