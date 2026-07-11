import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/section_header.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final Set<String> _selectedIngredients = {};

  List<Recipe> _matchingRecipes(List<Recipe> all) {
    if (_selectedIngredients.isEmpty) return [];
    final result = all.where((recipe) {
      final ids = recipe.ingredients.map((i) => i.ingredientId).toSet();
      return ids.intersection(_selectedIngredients).isNotEmpty;
    }).toList()
      ..sort((a, b) {
        final aCount = a.ingredients
            .where((i) => _selectedIngredients.contains(i.ingredientId))
            .length;
        final bCount = b.ingredients
            .where((i) => _selectedIngredients.contains(i.ingredientId))
            .length;
        return bCount.compareTo(aCount);
      });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider).valueOrNull ?? [];
    final allRecipes = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final matching = _matchingRecipes(allRecipes);

    final grouped = <IngredientCategory, List<Ingredient>>{};
    for (final ing in ingredients) {
      grouped.putIfAbsent(ing.category, () => []).add(ing);
    }

    return Column(
      children: [
        AppHeader(
          titleWidget: Text(
            'Malzemeye Göre Tarif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Malzemeleri Seç',
                  action: _selectedIngredients.isNotEmpty
                      ? '${_selectedIngredients.length} seçili'
                      : null,
                ),
                ..._buildCategoryGroups(context, grouped),
                if (_selectedIngredients.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Eşleşen Tarifler',
                    action: '${matching.length} tarif',
                  ),
                  if (matching.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Bu malzemeyle yapılabilecek tarif yok',
                          style: TextStyle(
                              color: context.palette.textTertiary),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: matching
                            .map((recipe) => RecipeCard(
                                  recipe: recipe,
                                  onTap: () =>
                                      context.push('/recipe/${recipe.id}'),
                                ))
                            .toList(),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryGroups(
    BuildContext context,
    Map<IngredientCategory, List<Ingredient>> grouped,
  ) {
    final widgets = <Widget>[];
    for (final category in grouped.keys) {
      final ingredients = grouped[category]!;
      widgets.addAll([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.palette.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients
                .map((ing) => _buildIngredientChip(context, ing))
                .toList(),
          ),
        ),
      ]);
    }
    return widgets;
  }

  Widget _emojiBox(BuildContext context, String emoji) => SizedBox(
        width: context.rs(26),
        height: context.rs(26),
        child: Center(
            child: Text(emoji,
                style: TextStyle(fontSize: context.sp(15)))),
      );

  Widget _buildIngredientChip(BuildContext context, Ingredient ing) {
    final isSelected = _selectedIngredients.contains(ing.id);
    final imgSize = context.rs(26);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIngredients.remove(ing.id);
          } else {
            _selectedIngredients.add(ing.id);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rs(10), vertical: context.rs(7)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.palette.g50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ing.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ing.imageUrl,
                      width: imgSize,
                      height: imgSize,
                      fit: BoxFit.cover,
                      placeholder: (_, url) => _emojiBox(context, ing.emoji),
                      errorWidget: (_, url, err) =>
                          _emojiBox(context, ing.emoji),
                    )
                  : _emojiBox(context, ing.emoji),
            ),
            SizedBox(width: context.rs(5)),
            Text(
              ing.name,
              style: TextStyle(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primaryText
                    : context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
