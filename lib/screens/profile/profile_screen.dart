import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_header.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);

    return Column(
      children: [
        AppHeader(
          showProfileAvatar: false,
          titleWidget: Text(
            'Profilim',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isAuth
                ? _buildAuthenticatedProfile(context, ref)
                : _buildGuestProfile(context, ref),
          ),
        ),
      ],
    );
  }

  // ─── GİRİŞ YAPMIŞ KULLANICI ────────────────────────────────────────────────

  Widget _buildAuthenticatedProfile(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserCard(context, ref),
        const SizedBox(height: 20),
        _buildSettingsGroup(
          context,
          ref,
          title: 'GÖRÜNÜM',
          items: [
            _SettingItem(
              icon: Icons.palette_outlined,
              label: 'Tema',
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              trailing: Switch.adaptive(
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                activeTrackColor: AppColors.primary,
                activeThumbColor: AppColors.primaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSettingsGroup(
          context,
          ref,
          title: 'TARİFLER',
          items: [
            _SettingItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Tarif Gönder',
              onTap: () => context.push('/submit-recipe'),
            ),
            _SettingItem(
              icon: Icons.pending_actions_rounded,
              label: 'Başvurularım',
              onTap: () => context.push('/my-submissions'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSettingsGroup(
          context,
          ref,
          title: 'HESAP',
          items: [
            const _SettingItem(
              icon: Icons.notifications_outlined,
              label: 'Bildirimler',
            ),
            _SettingItem(
              icon: Icons.logout,
              label: 'Çıkış Yap',
              isDanger: true,
              onTap: () => _showLogoutConfirm(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, WidgetRef ref) {
    final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;

    final displayName = firebaseUser?.displayName ?? 'Kullanıcı';
    final email = firebaseUser?.email ?? '';
    final photoUrl = firebaseUser?.photoURL;
    final isGoogleUser = firebaseUser?.providerData
            .any((p) => p.providerId == 'google.com') ??
        false;

    final initials = displayName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          // Avatar
          if (photoUrl != null && isGoogleUser)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) => _initialsAvatar(initials),
                errorWidget: (context, url, error) => _initialsAvatar(initials),
              ),
            )
          else
            _initialsAvatar(initials),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
                if (isGoogleUser) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 12,
                        width: 12,
                        errorBuilder: (context, url, error) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Google hesabı',
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
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initials) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
      ),
    );
  }

  // ─── MİSAFİR KULLANICI ─────────────────────────────────────────────────────

  Widget _buildGuestProfile(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.palette.g50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text('👤', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Hoş geldin!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tariflere göz atabilir, takvime ekleyebilirsin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.palette.textTertiary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryText,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/auth'),
            child: const Text(
              'Giriş Yap / Kayıt Ol',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Beğenme, yorum yazma ve kendi tariflerini ekleme gibi özellikleri kullanmak için giriş yap.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: context.palette.textTertiary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildSettingsGroup(
          context,
          ref,
          title: 'GÖRÜNÜM',
          items: [
            _SettingItem(
              icon: Icons.palette_outlined,
              label: 'Tema',
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              trailing: Switch.adaptive(
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                activeTrackColor: AppColors.primary,
                activeThumbColor: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── ORTAK BİLEŞENLER ──────────────────────────────────────────────────────

  Widget _buildSettingsGroup(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<_SettingItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: context.palette.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border, width: 1.5),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: GestureDetector(
                    onTap: items[i].onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: context.palette.g50,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            items[i].icon,
                            size: 15,
                            color: items[i].isDanger
                                ? Colors.red[400]
                                : context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            items[i].label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: items[i].isDanger
                                  ? Colors.red[400]
                                  : context.palette.textPrimary,
                            ),
                          ),
                        ),
                        if (items[i].trailing != null)
                          items[i].trailing!
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.palette.textTertiary,
                          ),
                      ],
                    ),
                  ),
                ),
                if (i < items.length - 1)
                  Divider(height: 1, thickness: 1, color: context.palette.border),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesaptan çıkmak istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pop(ctx);
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool isDanger;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.isDanger = false,
    this.onTap,
  });
}
