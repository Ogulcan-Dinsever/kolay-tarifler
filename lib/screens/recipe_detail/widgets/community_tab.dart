import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/community/community_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/recipe.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_safety_provider.dart';
import '../../../providers/recipe_provider.dart';
import '../../../widgets/recipe_card.dart';

class CommunityTab extends ConsumerWidget {
  final String parentRecipeId;

  const CommunityTab({super.key, required this.parentRecipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final recipesAsync = ref.watch(communityRecipesProvider(parentRecipeId));
    final blockedIds =
        ref.watch(blockedUserIdsProvider).valueOrNull ?? const {};
    final currentUserId = ref.watch(firebaseUserProvider).valueOrNull?.uid;

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
                  onTap: () => _openCreate(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (recipes) {
              final visibleRecipes = recipes
                  .where((recipe) => !blockedIds.contains(recipe.authorId))
                  .toList();
              if (visibleRecipes.isEmpty) {
                return _buildEmpty(context, ref, isAuth);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: visibleRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = visibleRecipes[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RecipeCard(
                          recipe: recipe,
                          onTap: () => context.push('/recipe/${recipe.id}'),
                        ),
                      ),
                      if (currentUserId != null &&
                          currentUserId != recipe.authorId)
                        PopupMenuButton<String>(
                          tooltip: 'Tarif seçenekleri',
                          onSelected: (value) {
                            if (value == 'report') {
                              _reportRecipe(context, ref, recipe);
                            } else if (value == 'block') {
                              _blockUser(context, ref, recipe);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'report',
                              child: Text('Tarifi bildir'),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Text('Kullanıcıyı engelle'),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref, bool isAuth) {
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
                      onTap: () => _openCreate(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
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

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final user = ref.read(firebaseUserProvider).valueOrNull;
    if (user == null || user.isAnonymous) return;
    if (!await ensureCommunityTermsAccepted(context, ref, user.uid)) return;
    if (context.mounted) {
      context.push('/recipe/$parentRecipeId/create-version');
    }
  }

  Future<void> _reportRecipe(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final user = ref.read(firebaseUserProvider).valueOrNull;
    if (user == null || user.uid == recipe.authorId) return;
    final reason = await showReportReasonDialog(context);
    if (reason == null || !context.mounted) return;
    await ref
        .read(communitySafetyServiceProvider)
        .report(
          reporterId: user.uid,
          targetType: 'recipe',
          targetId: recipe.id,
          targetUserId: recipe.authorId,
          reason: reason,
          recipeId: recipe.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirim alındı. Teşekkür ederiz.')),
      );
    }
  }

  Future<void> _blockUser(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final user = ref.read(firebaseUserProvider).valueOrNull;
    if (user == null || user.uid == recipe.authorId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcıyı engelle'),
        content: Text(
          '${recipe.authorName} adlı kullanıcının tarif ve yorumları artık '
          'sana gösterilmeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(communitySafetyServiceProvider)
        .blockUser(userId: user.uid, blockedUserId: recipe.authorId);
  }
}
