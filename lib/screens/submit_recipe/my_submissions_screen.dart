import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pending_recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pending_recipe_provider.dart';

class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.palette.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: context.palette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Başvurularım',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
      ),
      body: firebaseUser == null
          ? const Center(child: Text('Giriş yapman gerekiyor.'))
          : _SubmissionList(userId: firebaseUser.uid),
    );
  }
}

class _SubmissionList extends ConsumerWidget {
  final String userId;
  const _SubmissionList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(userSubmissionsProvider(userId));

    return submissionsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu_rounded,
                    size: 56, color: context.palette.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'Henüz tarif göndermedin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tariflerini toplulukla paylaş!',
                  style: TextStyle(
                      fontSize: 13, color: context.palette.textTertiary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/submit-recipe'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tarif Gönder',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _SubmissionCard(recipe: list[i]),
        );
      },
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final PendingRecipe recipe;
  const _SubmissionCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final status = recipe.status;
    final (label, color, icon) = switch (status) {
      PendingStatus.pending => ('İnceleniyor', const Color(0xFFF59E0B), Icons.hourglass_empty_rounded),
      PendingStatus.approved => ('Onaylandı', AppColors.primary, Icons.check_circle_rounded),
      PendingStatus.rejected => ('Reddedildi', Colors.red, Icons.cancel_rounded),
    };

    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(recipe.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${recipe.cuisine} • ${recipe.duration}',
                        style: TextStyle(
                            fontSize: 12, color: context.palette.textTertiary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (status == PendingStatus.rejected &&
                recipe.rejectionComment != null &&
                recipe.rejectionComment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        recipe.rejectionComment!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              _formatDate(recipe.createdAt),
              style: TextStyle(
                  fontSize: 11, color: context.palette.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
