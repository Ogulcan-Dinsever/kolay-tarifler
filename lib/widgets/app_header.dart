import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/auth_provider.dart';

class AppHeader extends ConsumerWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final bool showBottomCurve;
  final bool showProfileAvatar;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.showBottomCurve = true,
    this.showProfileAvatar = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.rs(20), context.rs(8), context.rs(12), context.rs(8)),
              child: Row(
                children: [
                  if (showBackButton) ...[
                    _iconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    if (title != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ] else if (titleWidget != null) ...[
                    titleWidget!,
                    const Spacer(),
                  ] else
                    _buildLogo(context),
                  ...?actions,
                  if (showProfileAvatar) ...[
                    const SizedBox(width: 8),
                    _ProfileAvatar(ref: ref),
                  ],
                ],
              ),
            ),
            if (showBottomCurve)
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Expanded(
      child: Image.asset(
        'assets/images/app_header_logo.png',
        height: context.rh(80),
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        color: AppColors.primary,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }

  static Widget _iconButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: AppColors.primaryText),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final WidgetRef ref;
  const _ProfileAvatar({required this.ref});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;
    final isLoggedIn = firebaseUser != null && !firebaseUser.isAnonymous;
    final photoUrl = firebaseUser?.photoURL;
    final displayName = firebaseUser?.displayName ?? '';
    final initials = displayName.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: context.rs(34),
        height: context.rs(34),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isLoggedIn ? AppColors.primary : AppColors.lightBorder,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: photoUrl != null && isLoggedIn
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _fallback(initials, isLoggedIn),
                  errorWidget: (context, url, error) => _fallback(initials, isLoggedIn),
                )
              : _fallback(initials, isLoggedIn),
        ),
      ),
    );
  }

  Widget _fallback(String initials, bool isLoggedIn) {
    if (isLoggedIn && initials.isNotEmpty) {
      return Container(
        color: AppColors.primary,
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.lightG50,
      child: const Icon(Icons.person_outline, size: 18, color: AppColors.lightTextTertiary),
    );
  }
}

/// Header'da kullanılan ikon buton — bildirim, menü vs.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  final VoidCallback? onTap;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.showBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: context.rs(34),
            height: context.rs(34),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: context.rs(18), color: AppColors.primaryText),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
