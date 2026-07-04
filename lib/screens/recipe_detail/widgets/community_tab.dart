import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/recipe_card.dart';

class CommunityTab extends ConsumerWidget {
  final String parentRecipeId;

  const CommunityTab({super.key, required this.parentRecipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final recipesAsync = ref.watch(communityRecipesProvider(parentRecipeId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Topluluk Tarifleri',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              if (isAuth)
                GestureDetector(
                  onTap: () =>
                      context.push('/recipe/$parentRecipeId/create-version'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '+ Versiyonumu Ekle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: recipesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (recipes) {
              if (recipes.isEmpty) {
                return _buildEmpty(context, isAuth);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () => context.push('/recipe/${recipe.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, bool isAuth) {
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('👨‍🍳', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz topluluk tarifi yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAuth
                        ? 'İlk versiyonu sen ekle!'
                        : 'Kendi versiyonunu paylaşmak için\ngiriş yapmanız gerekiyor.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isAuth) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => context
                          .push('/recipe/$parentRecipeId/create-version'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Versiyonumu Ekle',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
