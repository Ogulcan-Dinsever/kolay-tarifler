import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/admin_provider.dart';
import '../widgets/anchored_banner_ad.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  /// Ana ekran turunun alt menüyü spotlight'layabilmesi için (tek shell instance'ı var).
  static final GlobalKey navBarKey = GlobalKey(debugLabel: 'mainNavBar');

  static const _baseNavItems = [
    _NavItem(path: '/', icon: Icons.home_rounded, label: 'Mutfaklar'),
    _NavItem(
      path: '/ingredients',
      icon: Icons.shopping_bag_rounded,
      label: 'Malzeme',
    ),
    _NavItem(path: '/types', icon: Icons.restaurant_menu_rounded, label: 'Tür'),
    _NavItem(path: '/search', icon: Icons.search_rounded, label: 'Ara'),
    _NavItem(
      path: '/calendar',
      icon: Icons.calendar_month_rounded,
      label: 'Takvim',
    ),
    _NavItem(path: '/profile', icon: Icons.person_rounded, label: 'Profil'),
  ];

  static const _adminNavItem = _NavItem(
    path: '/admin',
    icon: Icons.admin_panel_settings_rounded,
    label: 'Admin',
  );

  int _activeIndex(String location, bool isAdmin) {
    if (location.startsWith('/ingredients')) return 1;
    if (location.startsWith('/types')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/calendar')) return 4;
    if (location.startsWith('/shopping')) return 4;
    if (location.startsWith('/profile')) return 5;
    if (isAdmin && location.startsWith('/admin')) return 6;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final navItems = isAdmin
        ? [..._baseNavItems, _adminNavItem]
        : _baseNavItems;
    final activeIndex = _activeIndex(location, isAdmin);
    final showsBannerAd =
        !isAdmin &&
        (location == '/' ||
            location.startsWith('/ingredients') ||
            location.startsWith('/types') ||
            location.startsWith('/search') ||
            location.startsWith('/recipe/'));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showsBannerAd) const AnchoredBannerAd(),
          _buildBottomNav(context, activeIndex, navItems),
        ],
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    int activeIndex,
    List<_NavItem> navItems,
  ) {
    return Container(
      key: navBarKey,
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border(
          top: BorderSide(color: context.palette.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(8),
            vertical: context.rs(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (i) {
              final item = navItems[i];
              final isActive = activeIndex == i;
              return _NavButton(
                item: item,
                isActive: isActive,
                onTap: () => context.go(item.path),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(isActive ? 12 : 8),
          vertical: context.rs(6),
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: context.rs(20),
              color: isActive
                  ? AppColors.primary
                  : context.palette.textTertiary,
            ),
            if (isActive) ...[
              SizedBox(width: context.rs(5)),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: context.sp(11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  const _NavItem({required this.path, required this.icon, required this.label});
}
