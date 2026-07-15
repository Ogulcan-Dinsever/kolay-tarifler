import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/community/community_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../models/recipe_step.dart';
import '../../providers/pending_recipe_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/ingredient_picker_sheet.dart';

class _IngredientEntry {
  String? id;
  String? name;
  final amountCtrl = TextEditingController();
  void dispose() => amountCtrl.dispose();
}

class SubmitRecipeScreen extends ConsumerStatefulWidget {
  const SubmitRecipeScreen({super.key});

  @override
  ConsumerState<SubmitRecipeScreen> createState() => _SubmitRecipeScreenState();
}

class _SubmitRecipeScreenState extends ConsumerState<SubmitRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();

  String _cuisine = MockCuisines.all.first['name']!;
  String _type = RecipeTypes.all.first['name']!;

  final List<Uint8List> _photoBytes = [];
  final List<_IngredientEntry> _ingredients = [];
  final List<TextEditingController> _steps = [];

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _emojiCtrl.dispose();
    for (final e in _ingredients) {
      e.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photoBytes.length >= 5) {
      _showSnack('En fazla 5 fotoğraf eklenebilir');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 85,
    );
    for (final xf in picked) {
      if (_photoBytes.length >= 5) break;
      final bytes = await xf.readAsBytes();
      setState(() => _photoBytes.add(bytes));
    }
  }

  void _openIngredientPicker(
    BuildContext context,
    List<Ingredient> allIngredients,
    _IngredientEntry entry,
  ) {
    IngredientPickerSheet.show(
      context: context,
      ingredients: allIngredients,
      onSelected: (ing) {
        if (mounted) {
          setState(() {
            entry.id = ing.id;
            entry.name = ing.name;
          });
        }
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _showSnack('Tarif göndermek için giriş yap');
      return;
    }
    if (!await ensureCommunityTermsAccepted(context, ref, user.uid)) return;
    if (!mounted) return;
    if (_photoBytes.isEmpty) {
      _showSnack('En az bir fotoğraf ekle');
      return;
    }
    if (_ingredients.isEmpty || _ingredients.any((e) => e.id == null)) {
      _showSnack('Tüm malzemeleri listeden seç');
      return;
    }
    if (_ingredients.any((e) => e.amountCtrl.text.trim().isEmpty)) {
      _showSnack('Tüm malzemelerin miktarını gir');
      return;
    }
    if (_steps.isEmpty) {
      _showSnack('En az bir yapılış adımı ekle');
      return;
    }

    setState(() => _loading = true);
    final service = ref.read(pendingRecipeServiceProvider);
    final imageUrls = <String>[];
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < _photoBytes.length; i++) {
        final url = await service.uploadImage(
          bytes: _photoBytes[i],
          filename: '${timestamp}_$i.jpg',
        );
        imageUrls.add(url);
      }

      final ingredients = _ingredients.asMap().entries.map((e) {
        return RecipeIngredient(
          ingredientId: e.value.id!,
          name: e.value.name!,
          amount: e.value.amountCtrl.text.trim(),
        );
      }).toList();

      final steps = _steps.asMap().entries.map((e) {
        return RecipeStep(order: e.key + 1, text: e.value.text.trim());
      }).toList();

      await service.submitRecipe(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        cuisine: _cuisine,
        type: _type,
        duration: _durationCtrl.text.trim(),
        emoji: _emojiCtrl.text.trim().isEmpty ? '🍽️' : _emojiCtrl.text.trim(),
        imageUrls: imageUrls,
        ingredients: ingredients,
        steps: steps,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      // Firestore kaydı başarısız olduysa yüklenen fotoğrafları temizle
      if (imageUrls.isNotEmpty) {
        service.deleteImages(imageUrls);
      }
      if (mounted) _showSnack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tarif Gönderildi!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDarker,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tarifin inceleme kuyruğuna alındı. Sonucu her zaman zil ekranında görebilirsin. Telefonuna da haber vermemiz için bildirimleri açabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _enableResultNotifications,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Sonuç Bildirimini Aç'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                  child: const Text(
                    'Tamam',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableResultNotifications() async {
    final granted = await NotificationService.requestPermission();
    final user = FirebaseAuth.instance.currentUser;
    if (granted && user != null && !user.isAnonymous) {
      await NotificationService.saveToken(user.uid);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Telefon bildirimleri açıldı.'
              : 'Bildirim izni verilmedi. Profil > Bildirimleri Aç bölümünden daha sonra açabilirsin.',
        ),
      ),
    );
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
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final allIngredients = ingredientsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: context.palette.g50,
      appBar: AppBar(
        backgroundColor: context.palette.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.palette.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Tarif Gönder',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bilgi banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gönderdiğin tarif admin onayından geçtikten sonra yayına alınacak. Reddedilirse sebebi sana bildirilecek.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDarker,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildField(_nameCtrl, 'Yemek Adı', validator: _required),
              const SizedBox(height: 12),
              _buildField(
                _descCtrl,
                'Açıklama',
                maxLines: 3,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _buildField(
                _durationCtrl,
                'Süre (örn: 30 dk)',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _buildField(_emojiCtrl, 'Emoji (örn: 🍲)'),
              const SizedBox(height: 16),
              _buildDropdownRow(),
              const SizedBox(height: 24),

              _sectionTitle('Fotoğraflar', '(en fazla 5)'),
              const SizedBox(height: 10),
              _buildPhotoSection(),
              const SizedBox(height: 24),

              _sectionTitle('Malzemeler', ''),
              const SizedBox(height: 10),
              if (ingredientsAsync.isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else
                _buildIngredientsList(context, allIngredients),
              if (allIngredients.isNotEmpty)
                _buildAddButton(
                  '+ Malzeme Ekle',
                  () => setState(() => _ingredients.add(_IngredientEntry())),
                ),
              const SizedBox(height: 24),

              _sectionTitle('Yapılış Adımları', ''),
              const SizedBox(height: 10),
              _buildStepsList(),
              _buildAddButton(
                '+ Adım Ekle',
                () => setState(() => _steps.add(TextEditingController())),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryText,
                          ),
                        )
                      : const Text(
                          'Onaya Gönder',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Yardımcı widget'lar ──────────────────────────────────────────────────────

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.sp(16),
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(width: context.rs(6)),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: context.sp(12),
              color: context.palette.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            label: 'Mutfak',
            value: _cuisine,
            items: MockCuisines.all.map((e) => e['name']!).toList(),
            onChanged: (v) => setState(() => _cuisine = v!),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown(
            label: 'Tür',
            value: _type,
            items: RecipeTypes.all.map((e) => e['name']!).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final palette = context.palette;
    final isDark = context.isDark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _inputDecoration(label),
      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
      style: TextStyle(fontSize: context.sp(13), color: palette.textPrimary),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: palette.textTertiary,
        size: context.rs(20),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e,
                style: TextStyle(
                  fontSize: context.sp(13),
                  color: palette.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPhotoSection() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._photoBytes.asMap().entries.map(
            (e) => Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(e.value, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => setState(() => _photoBytes.removeAt(e.key)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_photoBytes.length < 5)
            GestureDetector(
              onTap: _loading ? null : _pickPhotos,
              child: Container(
                width: context.rs(100),
                height: context.rs(100),
                decoration: BoxDecoration(
                  color: context.palette.g50,
                  borderRadius: BorderRadius.circular(context.rs(12)),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      size: context.rs(28),
                      color: AppColors.primary,
                    ),
                    SizedBox(height: context.rs(4)),
                    Text(
                      'Ekle',
                      style: TextStyle(
                        fontSize: context.sp(11),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(
    BuildContext context,
    List<Ingredient> allIngredients,
  ) {
    return Column(
      children: _ingredients.asMap().entries.map((e) {
        final i = e.key;
        final entry = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () =>
                      _openIngredientPicker(context, allIngredients, entry),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rs(12),
                      vertical: context.rs(13),
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.g50,
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      border: Border.all(
                        color: entry.id != null
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : context.palette.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name ?? 'Malzeme seç...',
                            style: TextStyle(
                              fontSize: context.sp(13),
                              color: entry.name != null
                                  ? context.palette.textPrimary
                                  : context.palette.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: context.rs(18),
                          color: context.palette.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rs(8)),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.amountCtrl,
                  style: TextStyle(
                    fontSize: context.sp(13),
                    color: context.palette.textPrimary,
                  ),
                  decoration: _inputDecoration('Miktar'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  entry.dispose();
                  setState(() => _ingredients.removeAt(i));
                },
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsList() {
    return Column(
      children: _steps.asMap().entries.map((e) {
        final i = e.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 10, right: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: e.value,
                  maxLines: 2,
                  validator: _required,
                  style: TextStyle(
                    fontSize: context.sp(13),
                    color: context.palette.textPrimary,
                  ),
                  decoration: _inputDecoration('Adım ${i + 1} açıklaması'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  e.value.dispose();
                  setState(() => _steps.removeAt(i));
                },
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.add_circle_outline_rounded,
        size: 18,
        color: AppColors.primary,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        fontSize: context.sp(14),
        color: context.palette.textPrimary,
      ),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final palette = context.palette;
    final r = BorderRadius.circular(context.rs(12));
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: context.sp(13),
        color: palette.textTertiary,
      ),
      filled: true,
      fillColor: palette.g50,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.rs(14),
        vertical: context.rs(12),
      ),
      border: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: palette.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: palette.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Bu alan zorunlu' : null;
}
