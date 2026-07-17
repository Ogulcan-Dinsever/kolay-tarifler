import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/community/community_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ingredient.dart';
import '../../models/recipe_ingredient.dart';
import '../../models/recipe_step.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/ingredient_picker_sheet.dart';

class _IngredientRow {
  String? ingredientId;
  String? ingredientName;
  final amountCtrl = TextEditingController();

  void dispose() => amountCtrl.dispose();
}

class CreateSubRecipeScreen extends ConsumerStatefulWidget {
  final String parentRecipeId;

  const CreateSubRecipeScreen({super.key, required this.parentRecipeId});

  @override
  ConsumerState<CreateSubRecipeScreen> createState() =>
      _CreateSubRecipeScreenState();
}

class _CreateSubRecipeScreenState extends ConsumerState<CreateSubRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  final List<_IngredientRow> _ingredientRows = [_IngredientRow()];
  final List<TextEditingController> _stepCtrls = [TextEditingController()];
  final List<XFile> _selectedImages = [];

  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _durationCtrl.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final ctrl in _stepCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        final remaining = 6 - _selectedImages.length;
        _selectedImages.addAll(picked.take(remaining));
      });
    }
  }

  Future<List<String>> _uploadImages(String userId) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    try {
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = File(_selectedImages[i].path);
        final ref = storage.ref().child(
          'recipe_images/$userId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        await ref.putFile(file);
        urls.add(await ref.getDownloadURL());
      }
      return urls;
    } catch (_) {
      await _deleteUploadedImages(urls);
      rethrow;
    }
  }

  Future<void> _deleteUploadedImages(List<String> urls) async {
    await Future.wait(
      urls.map((url) async {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {
          // En iyi çaba: asıl kayıt hatasını gölgelememek için temizlik hatası yutulur.
        }
      }),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarif eklemek için giriş yapın')),
      );
      return;
    }
    if (!await ensureCommunityTermsAccepted(context, ref, user.uid)) return;
    if (!mounted) return;

    // Tüm satırlar tamamlanmış olmalı — bir satır malzeme seçilmeden veya
    // miktar girilmeden bırakılırsa artık sessizce atılmıyor, kullanıcı uyarılıyor.
    if (_ingredientRows.isEmpty ||
        _ingredientRows.any((r) => r.ingredientId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm malzemeleri listeden seç')),
      );
      return;
    }
    if (_ingredientRows.any((r) => r.amountCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm malzemelerin miktarını gir')),
      );
      return;
    }

    setState(() => _saving = true);

    var uploadedImageUrls = <String>[];
    var recipeCreated = false;
    try {
      final parent = await ref.read(
        recipeByIdProvider(widget.parentRecipeId).future,
      );
      if (parent == null) {
        throw StateError('Ana tarif bulunamadı.');
      }
      if (!parent.canHaveVariations) {
        throw StateError('Bir topluluk varyasyonuna yeni varyasyon eklenemez.');
      }

      uploadedImageUrls = await _uploadImages(user.uid);

      final ingredients = <RecipeIngredient>[];
      for (var i = 0; i < _ingredientRows.length; i++) {
        final row = _ingredientRows[i];
        ingredients.add(
          RecipeIngredient(
            ingredientId: row.ingredientId!,
            name: row.ingredientName!,
            amount: row.amountCtrl.text.trim(),
          ),
        );
      }

      final steps = <RecipeStep>[];
      var order = 1;
      for (final ctrl in _stepCtrls) {
        if (ctrl.text.trim().isNotEmpty) {
          steps.add(RecipeStep(order: order, text: ctrl.text.trim()));
          order++;
        }
      }

      final authorName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? 'Kullanıcı';

      await ref
          .read(recipeServiceProvider)
          .createSubRecipe(
            parentRecipeId: widget.parentRecipeId,
            authorId: user.uid,
            authorName: authorName,
            name: parent.name,
            description: _descCtrl.text.trim(),
            emoji: parent.emoji,
            duration: _durationCtrl.text.trim(),
            cuisine: parent.cuisine,
            ingredients: ingredients,
            steps: steps,
            imageUrls: uploadedImageUrls,
          );
      recipeCreated = true;

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Varyasyonunuz eklendi! Topluluk sekmesinde görünecek.',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (!recipeCreated && uploadedImageUrls.isNotEmpty) {
        await _deleteUploadedImages(uploadedImageUrls);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentAsync = ref.watch(recipeByIdProvider(widget.parentRecipeId));
    final allIngredients = ref.watch(ingredientsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDarker,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Kendi Varyasyonumu Paylaş',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: parentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) => _ParentUnavailable(
          icon: Icons.cloud_off_rounded,
          title: 'Ana tarif yüklenemedi',
          detail: 'Bağlantını kontrol edip tekrar dene.',
          actionLabel: 'Tekrar Dene',
          onAction: () =>
              ref.invalidate(recipeByIdProvider(widget.parentRecipeId)),
        ),
        data: (parent) {
          if (parent == null) {
            return _ParentUnavailable(
              icon: Icons.search_off_rounded,
              title: 'Ana tarif bulunamadı',
              detail: 'Bu tarif kaldırılmış olabilir.',
              actionLabel: 'Geri Dön',
              onAction: () => context.pop(),
            );
          }
          if (!parent.canHaveVariations) {
            return _ParentUnavailable(
              icon: Icons.account_tree_outlined,
              title: 'Bu bir topluluk varyasyonu',
              detail: 'Bir varyasyonun altına yeni varyasyon eklenemez.',
              actionLabel: 'Geri Dön',
              onAction: () => context.pop(),
            );
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Tarif adı ─────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          parent.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── Açıklama & Süre ───────────────────────────────────────────
                  _field(
                    controller: _descCtrl,
                    hint: 'Tarifin kısa açıklaması...',
                    label: 'Açıklama',
                    maxLines: 2,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Açıklama boş olamaz' : null,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _durationCtrl,
                    hint: 'örn. 45 dk',
                    label: 'Süre',
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Süre boş olamaz' : null,
                  ),
                  const SizedBox(height: 20),

                  // ─── Fotoğraflar ───────────────────────────────────────────────
                  _sectionTitle('Fotoğraflar'),
                  const SizedBox(height: 4),
                  Text(
                    'En fazla 6 fotoğraf ekleyebilirsiniz',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPhotoRow(context),
                  const SizedBox(height: 20),

                  // ─── Malzemeler ────────────────────────────────────────────────
                  _sectionTitle('Malzemeler'),
                  const SizedBox(height: 4),
                  if (allIngredients.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.palette.g50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Text(
                        'Sisteme henüz malzeme eklenmemiş.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  ..._ingredientRows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return _IngredientRowWidget(
                      key: ObjectKey(row),
                      row: row,
                      allIngredients: allIngredients,
                      canDelete: _ingredientRows.length > 1,
                      onDelete: () =>
                          setState(() => _ingredientRows.removeAt(i)),
                      onChanged: () => setState(() {}),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _ingredientRows.add(_IngredientRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Malzeme Ekle'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Yapılış Adımları ──────────────────────────────────────────
                  _sectionTitle('Yapılış Adımları'),
                  const SizedBox(height: 10),
                  ..._stepCtrls.asMap().entries.map((entry) {
                    final i = entry.key;
                    return _StepWidget(
                      key: ObjectKey(_stepCtrls[i]),
                      number: i + 1,
                      controller: _stepCtrls[i],
                      canDelete: _stepCtrls.length > 1,
                      onDelete: () => setState(() => _stepCtrls.removeAt(i)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _stepCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adım Ekle'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Tarifi Kaydet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoRow(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._selectedImages.asMap().entries.map((entry) {
            final i = entry.key;
            final img = entry.value;
            return Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(File(img.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImages.removeAt(i)),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.black87,
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
            );
          }),
          if (_selectedImages.length < 6)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: context.palette.textTertiary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ekle',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textTertiary,
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

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: context.palette.textPrimary,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: context.palette.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _ParentUnavailable extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  const _ParentUnavailable({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: context.palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

// ── Malzeme satırı widget'ı ─────────────────────────────────────────────────

class _IngredientRowWidget extends StatefulWidget {
  final _IngredientRow row;
  final List<Ingredient> allIngredients;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _IngredientRowWidget({
    super.key,
    required this.row,
    required this.allIngredients,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_IngredientRowWidget> createState() => _IngredientRowWidgetState();
}

class _IngredientRowWidgetState extends State<_IngredientRowWidget> {
  void _openPicker() {
    IngredientPickerSheet.show(
      context: context,
      ingredients: widget.allIngredients,
      onSelected: (ing) {
        widget.row.ingredientId = ing.id;
        widget.row.ingredientName = ing.name;
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.palette.border),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // ── Malzeme seçici ────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: widget.allIngredients.isEmpty ? null : _openPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.row.ingredientId != null
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : context.palette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.row.ingredientName ?? 'Malzeme seç...',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.row.ingredientName != null
                              ? context.palette.textPrimary
                              : context.palette.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: context.palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Miktar ────────────────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: widget.row.amountCtrl,
              decoration: InputDecoration(
                hintText: 'Miktar',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.palette.textTertiary,
                ),
                filled: true,
                fillColor: context.palette.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            child: widget.canDelete
                ? IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Adım widget'ı ────────────────────────────────────────────────────────────

class _StepWidget extends StatelessWidget {
  final int number;
  final TextEditingController controller;
  final bool canDelete;
  final VoidCallback onDelete;

  const _StepWidget({
    super.key,
    required this.number,
    required this.controller,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Bu adımı açıklayın...',
                filled: true,
                fillColor: context.palette.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: canDelete
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
