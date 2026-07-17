import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tutorial/tutorial_overlay.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/ad_consent_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static final _privacyUrl = Uri.parse(
    'https://kolaytarifler-37c45.web.app/privacy',
  );
  static final _termsUrl = Uri.parse(
    'https://kolaytarifler-37c45.web.app/terms',
  );
  static final _supportUrl = Uri(
    scheme: 'mailto',
    path: 'ogulcandnsvr@gmail.com',
    queryParameters: {'subject': 'Kolay Tarifler Destek'},
  );
  // Tutorial
  final _themeKey = GlobalKey();
  final _recipesKey = GlobalKey();
  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    // Misafir görünümünde TARİFLER grubu yok — turu yalnız üyeye göster
    if (!ref.read(isAuthenticatedProvider)) return;
    final should = await TutorialService.shouldShow('tutorial_profile_v1');
    if (!should || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _insertTutorial();
  }

  void _insertTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        storageKey: 'tutorial_profile_v1',
        steps: [
          TutorialStep(
            emoji: '🎨',
            title: 'Koyu / Açık Tema',
            description:
                'Gözünü yormayan koyu temaya buradan geç. Tercihin cihazında saklanır.',
            targetKey: _themeKey,
            spotlightPadding: 6,
          ),
          TutorialStep(
            emoji: '👨‍🍳',
            title: 'Kendi Tarifini Yayınla',
            description:
                'Tarif Gönder ile başvur; onaylanınca yayına girer ve sana bildirim gelir. Başvurularım\'dan durumu takip et.',
            targetKey: _recipesKey,
            spotlightPadding: 6,
          ),
        ],
        onDone: () {
          _tutorialEntry?.remove();
          _tutorialEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        KeyedSubtree(
          key: _themeKey,
          child: _buildSettingsGroup(
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
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  activeTrackColor: AppColors.primary,
                  activeThumbColor: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: _recipesKey,
          child: _buildSettingsGroup(
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
              _SettingItem(
                icon: Icons.forum_outlined,
                label: 'Yorum ve Beğenilerim',
                onTap: () => context.push('/profile/activity'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsGroup(
          context,
          ref,
          title: 'YARDIM',
          items: [
            _SettingItem(
              icon: Icons.replay_rounded,
              label: 'Tanıtım Turunu Sıfırla',
              onTap: () => _resetTutorials(context),
            ),
            _SettingItem(
              icon: Icons.notifications_outlined,
              label: 'Bildirimleri Aç',
              onTap: () => _requestNotificationPermission(context),
            ),
            _SettingItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Gizlilik Politikası',
              onTap: () => _openExternal(context, _privacyUrl),
            ),
            _SettingItem(
              icon: Icons.gavel_outlined,
              label: 'Kullanım ve Topluluk Koşulları',
              onTap: () => _openExternal(context, _termsUrl),
            ),
            _SettingItem(
              icon: Icons.support_agent_rounded,
              label: 'Destek: ogulcandnsvr@gmail.com',
              onTap: () => _openExternal(context, _supportUrl),
            ),
            if (AdConsentService.privacyOptionsRequired)
              _SettingItem(
                icon: Icons.ads_click_outlined,
                label: 'Reklam Gizlilik Tercihleri',
                onTap: () => _openAdPrivacyOptions(context),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSettingsGroup(
          context,
          ref,
          title: 'HESAP',
          items: [
            _SettingItem(
              icon: Icons.logout,
              label: 'Çıkış Yap',
              isDanger: true,
              onTap: () => _showLogoutConfirm(context, ref),
            ),
            _SettingItem(
              icon: Icons.delete_forever_outlined,
              label: 'Hesabımı Sil',
              isDanger: true,
              onTap: () => _showDeleteAccountConfirm(context, ref),
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
    final isGoogleUser =
        firebaseUser?.providerData.any((p) => p.providerId == 'google.com') ??
        false;

    final initials = displayName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

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
                        errorBuilder: (context, url, error) =>
                            const SizedBox.shrink(),
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
        const SizedBox(height: 12),
        _buildSettingsGroup(
          context,
          ref,
          title: 'YARDIM',
          items: [
            _SettingItem(
              icon: Icons.replay_rounded,
              label: 'Tanıtım Turunu Sıfırla',
              onTap: () => _resetTutorials(context),
            ),
            _SettingItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Gizlilik Politikası',
              onTap: () => _openExternal(context, _privacyUrl),
            ),
            _SettingItem(
              icon: Icons.gavel_outlined,
              label: 'Kullanım ve Topluluk Koşulları',
              onTap: () => _openExternal(context, _termsUrl),
            ),
            _SettingItem(
              icon: Icons.support_agent_rounded,
              label: 'Destek: ogulcandnsvr@gmail.com',
              onTap: () => _openExternal(context, _supportUrl),
            ),
            if (AdConsentService.privacyOptionsRequired)
              _SettingItem(
                icon: Icons.ads_click_outlined,
                label: 'Reklam Gizlilik Tercihleri',
                onTap: () => _openAdPrivacyOptions(context),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _resetTutorials(BuildContext context) async {
    await TutorialService.resetAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tanıtım turları sıfırlandı — ekranları gezdikçe yeniden gösterilecek. 🧭',
          ),
        ),
      );
    }
  }

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı açılamadı. Lütfen daha sonra tekrar dene.'),
        ),
      );
    }
  }

  Future<void> _openAdPrivacyOptions(BuildContext context) async {
    final error = await AdConsentService.showPrivacyOptions();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reklam tercihleri açılamadı: ${error.message}'),
        ),
      );
    }
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.palette.border,
                  ),
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

  Future<void> _requestNotificationPermission(BuildContext context) async {
    final granted = await NotificationService.requestPermission();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Bildirimler açıldı.'
              : 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsin.',
        ),
      ),
    );
  }

  void _showDeleteAccountConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabımı Sil'),
        content: const Text(
          'Hesabın ve tüm verilerin (beğeniler, profil) kalıcı olarak '
          'silinecek. Daha önce onaylanıp ana tarif olarak yayımlanan '
          'tariflerin, adın kaldırılarak yayında kalır. Bu işlem geri '
          'alınamaz. Devam etmek istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount(context, ref);
            },
            child: const Text(
              'Hesabımı Sil',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // Silme sırasında dokunmayı engelleyen basit bir yükleniyor göstergesi.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Hesabın silindi.')));
      router.go('/');
    } on AccountDeletionException catch (_) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      // Firebase yakın zamanda giriş ister — kullanıcıyı çıkışa/girişe yönlendir.
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Güvenlik için hesabını silmeden önce tekrar giriş yapman gerekiyor. '
            'Lütfen çıkış yapıp yeniden giriş yaptıktan sonra tekrar dene.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      await ref.read(authServiceProvider).signOut();
      router.go('/auth');
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text('Hesap silinemedi: $e')));
    }
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
