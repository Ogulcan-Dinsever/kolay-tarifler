import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/app_header.dart';

/// Bildirim merkezi — yalnızca ana ekrandaki zil butonundan ulaşılır.
/// Beğeni, yorum ve tarif onay/red bildirimleri burada listelenir
/// (kaynak: users/{uid}/notifications, yazan: Cloud Functions).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isAuthenticatedProvider);
    final notifsAsync = ref.watch(notificationsProvider);
    final actions = ref.watch(notificationActionsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AppHeader(
            title: 'Bildirimler',
            showBackButton: true,
            showProfileAvatar: false,
            actions: [
              if (unreadCount > 0 && actions != null)
                TextButton(
                  onPressed: () async {
                    final items = notifsAsync.valueOrNull ?? const <AppNotification>[];
                    await actions.markAllRead(items);
                  },
                  child: const Text(
                    'Tümünü okundu işaretle',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Expanded(
            child: !isLoggedIn
                ? _GuestPrompt()
                : notifsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bildirimler yüklenemedi. Lütfen tekrar dene.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.palette.textSecondary),
                        ),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? _EmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _NotificationTile(
                              notification: items[i],
                              onTap: () async {
                                final n = items[i];
                                if (!n.read) await actions?.markRead(n.id);
                                final route = n.route;
                                if (route != null && context.mounted) {
                                  context.push(route);
                                }
                              },
                              onDismissed: () => actions?.delete(items[i].id),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Bildirimler için giriş yap',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tariflerine gelen beğeni, yorum ve onay durumlarını burada görürsün.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Giriş Yap / Kayıt Ol',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Henüz bildirim yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tariflerine beğeni ya da yorum gelince ve başvuruların sonuçlanınca burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  IconData get _icon => switch (notification.type) {
        'recipe_liked' => Icons.favorite_rounded,
        'comment' => Icons.chat_bubble_rounded,
        'pending_recipe' => Icons.assignment_turned_in_rounded,
        _ => Icons.notifications_rounded,
      };

  Color get _iconColor => switch (notification.type) {
        'recipe_liked' => const Color(0xFFE0533D),
        'comment' => const Color(0xFF2F80ED),
        'pending_recipe' => AppColors.primary,
        _ => AppColors.primary,
      };

  // Türkçe göreli zaman: Az önce / X dk önce / X sa önce / dd.MM.yyyy
  String _timeLabel() {
    final t = notification.createdAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = !notification.read;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE0533D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread ? AppColors.primary.withValues(alpha: 0.45) : palette.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, size: 20, color: _iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: palette.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeLabel(),
                        style: TextStyle(fontSize: 11, color: palette.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
