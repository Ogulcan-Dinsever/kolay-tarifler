import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../services/admin_service.dart';

class ManageAdminsTab extends ConsumerStatefulWidget {
  const ManageAdminsTab({super.key});

  @override
  ConsumerState<ManageAdminsTab> createState() => _ManageAdminsTabState();
}

class _ManageAdminsTabState extends ConsumerState<ManageAdminsTab> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _adding = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _adding = true);
    try {
      await ref.read(adminServiceProvider).addAdmin(_emailCtrl.text.trim());
      if (!mounted) return;
      _emailCtrl.clear();
      _showSnack('Admin eklendi!', success: true);
    } catch (e) {
      if (mounted) _showSnack('Hata: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeAdmin(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admini Kaldır'),
        content: Text('$email adresinin admin yetkisi kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(adminServiceProvider).removeAdmin(email);
      if (mounted) _showSnack('Admin kaldırıldı', success: true);
    } catch (e) {
      if (mounted) _showSnack('Hata: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.primary : Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManageAdmins = ref.watch(isSuperAdminProvider);
    if (!canManageAdmins) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Admin yetkilerini yalnızca ${AdminService.initialAdminEmail} yönetebilir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
        ),
      );
    }

    final adminsAsync = ref.watch(adminUsersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Yönetimi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDarker,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bu listedeki e-posta adresleri admin paneline erişebilir.',
            style: TextStyle(fontSize: 13, color: context.palette.textTertiary),
          ),
          const SizedBox(height: 24),
          _buildAddSection(),
          const SizedBox(height: 28),
          Text(
            'Mevcut Adminler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          adminsAsync.when(
            data: (admins) => admins.isEmpty
                ? Text(
                    'Henüz admin yok.',
                    style: TextStyle(color: context.palette.textTertiary),
                  )
                : Column(
                    children: admins
                        .map((a) => _buildAdminTile(a['email'] as String))
                        .toList(),
                  ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) =>
                Text('Hata: $e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.g50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni Admin Ekle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'E-posta adresi',
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: context.palette.textTertiary,
                ),
                filled: true,
                fillColor: context.palette.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.palette.border,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.palette.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'E-posta gerekli';
                if (!v.contains('@')) return 'Geçerli e-posta girin';
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _adding ? null : _addAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryText,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryText,
                        ),
                      )
                    : const Text(
                        'Admin Olarak Ekle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTile(String email) {
    final isInitial = email == AdminService.initialAdminEmail;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInitial
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.palette.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isInitial ? context.palette.g100 : context.palette.g50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 18,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                if (isInitial)
                  const Text(
                    'Süper Admin',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
          ),
          if (!isInitial)
            IconButton(
              onPressed: () => _removeAdmin(email),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
              tooltip: 'Admin yetkisini kaldır',
            ),
        ],
      ),
    );
  }
}
