import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import 'add_ingredient_tab.dart';
import 'add_recipe_tab.dart';
import 'manage_admins_tab.dart';
import 'pending_recipes_tab.dart';
import 'reports_tab.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) => isAdmin ? const _AdminPanel() : const _AccessDenied(),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.palette.card,
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Admin Panel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.palette.border, width: 1),
                ),
              ),
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primaryDarker,
                unselectedLabelColor: context.palette.textTertiary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.shopping_basket_rounded, size: 18),
                    text: 'Malzeme',
                  ),
                  Tab(
                    icon: Icon(Icons.restaurant_rounded, size: 18),
                    text: 'Tarif',
                  ),
                  Tab(
                    icon: Icon(Icons.manage_accounts_rounded, size: 18),
                    text: 'Adminler',
                  ),
                  Tab(
                    icon: Icon(Icons.pending_actions_rounded, size: 18),
                    text: 'Başvurular',
                  ),
                  Tab(
                    icon: Icon(Icons.flag_outlined, size: 18),
                    text: 'Bildirimler',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            AddIngredientTab(),
            AddRecipeTab(),
            ManageAdminsTab(),
            PendingRecipesTab(),
            ReportsTab(),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: context.palette.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Erişim Yok',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu sayfayı görüntüleme yetkiniz bulunmuyor.',
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
