import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ingredient.dart';
import '../../providers/admin_provider.dart';

class AddIngredientTab extends ConsumerStatefulWidget {
  const AddIngredientTab({super.key});

  @override
  ConsumerState<AddIngredientTab> createState() => _AddIngredientTabState();
}

class _AddIngredientTabState extends ConsumerState<AddIngredientTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  Uint8List? _imageBytes;
  IngredientCategory _category = IngredientCategory.other;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(adminServiceProvider);
      String imageUrl = '';

      if (_imageBytes != null) {
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_ingredient.jpg';
        imageUrl = await service.uploadImage(
          bytes: _imageBytes!,
          folder: 'ingredients',
          filename: filename,
        );
      }

      await service.addIngredient(
        name: _nameCtrl.text.trim(),
        category: _category.name,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      _nameCtrl.clear();
      _formKey.currentState?.reset();
      setState(() {
        _imageBytes = null;
        _category = IngredientCategory.other;
      });
      _showSnack('Malzeme başarıyla eklendi!', success: true);
    } catch (e) {
      if (mounted) _showSnack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.primary : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Malzeme Ekle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildImagePicker(),
            const SizedBox(height: 20),
            _buildField(
              controller: _nameCtrl,
              label: 'Malzeme Adı',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 28),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _loading ? null : _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: context.palette.g50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageBytes != null
                ? AppColors.primary
                : context.palette.border,
            width: 2,
          ),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      size: 44, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text(
                    'Fotoğraf Seç',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Galeriden seç',
                    style: TextStyle(
                        fontSize: 12, color: context.palette.textTertiary),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 13, color: context.palette.textTertiary),
        filled: true,
        fillColor: context.palette.g50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final isDark = context.isDark;
    return DropdownButtonFormField<IngredientCategory>(
      initialValue: _category,
      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
      style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: 'Kategori',
        labelStyle:
            TextStyle(fontSize: 13, color: context.palette.textTertiary),
        filled: true,
        fillColor: context.palette.g50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: IngredientCategory.values
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.label,
                    style: TextStyle(
                        fontSize: 14, color: context.palette.textPrimary)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _category = v);
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryText,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryText),
              )
            : const Text(
                'Malzeme Ekle',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
