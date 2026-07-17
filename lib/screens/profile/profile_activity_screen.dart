import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../models/user_activity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/recipe_service.dart';

class ProfileActivityScreen extends ConsumerWidget {
  const ProfileActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseUserProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: context.palette.card,
          foregroundColor: context.palette.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Etkileşimlerim',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: context.palette.textPrimary,
            unselectedLabelColor: context.palette.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Yorumlarım'),
              Tab(icon: Icon(Icons.favorite_border), text: 'Beğenilerim'),
            ],
          ),
        ),
        body: user.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) => const _ActivityMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Hesap bilgisi yüklenemedi',
            detail: 'Lütfen bağlantını kontrol edip tekrar dene.',
          ),
          data: (currentUser) {
            if (currentUser == null || currentUser.isAnonymous) {
              return const _ActivityMessage(
                icon: Icons.lock_outline_rounded,
                title: 'Giriş yapman gerekiyor',
                detail: 'Yorum ve beğenilerini görmek için hesabına giriş yap.',
              );
            }
            return TabBarView(
              children: [
                _CommentsTab(userId: currentUser.uid),
                _LikesTab(userId: currentUser.uid),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommentsTab extends ConsumerWidget {
  final String userId;

  const _CommentsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(userCommentActivitiesProvider(userId));
    return activities.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const _ActivityMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Yorumlar yüklenemedi',
        detail: 'Lütfen bağlantını kontrol edip tekrar dene.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _ActivityMessage(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Henüz yorum yapmadın',
            detail: 'Tariflerde paylaştığın yorumlar burada görünecek.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount:
              items.length +
              (items.length == RecipeService.profileActivityLimit ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const _ActivityLimitNotice();
            }
            final activity = items[index];
            return _ActivityCard(
              recipe: activity.recipe,
              date: activity.comment.createdAt,
              body: activity.comment.text,
              trailing: IconButton(
                tooltip: 'Yorumu sil',
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.red,
                onPressed: () => _deleteComment(context, ref, activity),
              ),
              onTap: activity.recipe == null
                  ? null
                  : () => context.push('/recipe/${activity.recipeId}'),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref,
    UserCommentActivity activity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yorumu sil'),
        content: const Text('Bu yorum kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(recipeServiceProvider)
          .deleteComment(
            recipeId: activity.recipeId,
            commentId: activity.comment.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yorum silinemedi: $error')));
      }
    }
  }
}

class _LikesTab extends ConsumerWidget {
  final String userId;

  const _LikesTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(userLikeActivitiesProvider(userId));
    return activities.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => const _ActivityMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Beğeniler yüklenemedi',
        detail: 'Lütfen bağlantını kontrol edip tekrar dene.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _ActivityMessage(
            icon: Icons.favorite_border_rounded,
            title: 'Henüz tarif beğenmedin',
            detail: 'Kalp bıraktığın tarifler burada görünecek.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount:
              items.length +
              (items.length == RecipeService.profileActivityLimit ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const _ActivityLimitNotice();
            }
            final activity = items[index];
            return _ActivityCard(
              recipe: activity.recipe,
              date: activity.createdAt,
              leadingIcon: Icons.favorite_rounded,
              leadingColor: Colors.red,
              onTap: activity.recipe == null
                  ? null
                  : () => context.push('/recipe/${activity.recipeId}'),
            );
          },
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Recipe? recipe;
  final DateTime date;
  final String? body;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.recipe,
    required this.date,
    this.body,
    this.leadingIcon,
    this.leadingColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentRecipe = recipe;
    return Material(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (leadingColor ?? AppColors.primary).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: leadingIcon != null
                    ? Icon(leadingIcon, color: leadingColor)
                    : Text(
                        currentRecipe?.emoji ?? '🍽️',
                        style: const TextStyle(fontSize: 22),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentRecipe?.name ?? 'Tarif artık yayında değil',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    if (currentRecipe?.isVariation == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Topluluk varyasyonu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                    if (body != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        body!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _ActivityMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.palette.textTertiary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLimitNotice extends StatelessWidget {
  const _ActivityLimitNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        'En yeni ${RecipeService.profileActivityLimit} kayıt gösteriliyor.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Tarih bilgisi yok';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} · $hour:$minute';
}
