import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/recipe_ingredient.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/ingredient_avatar.dart';

class IngredientsTab extends ConsumerWidget {
  final List<RecipeIngredient> ingredients;
  const IngredientsTab({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ingredients.isEmpty) {
      return Center(
        child: Text(
          'Malzeme listesi henüz eklenmedi',
          style: TextStyle(color: context.palette.textTertiary),
        ),
      );
    }

    final allIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? [];
    final ingredientMap = {
      for (final i in allIngredients) i.id: i,
    };

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ingredients.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.palette.border),
      itemBuilder: (context, i) {
        final ing = ingredients[i];
        final detail = ingredientMap[ing.ingredientId];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              IngredientAvatar(
                emoji: ing.emoji ?? '🥄',
                imageUrl: detail?.imageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ing.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.palette.g100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ing.amount,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarker,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
