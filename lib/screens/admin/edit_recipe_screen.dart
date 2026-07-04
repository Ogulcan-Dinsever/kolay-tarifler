import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../models/recipe_ingredient.dart';
import '../../models/recipe_step.dart';
import '../../services/recipe_service.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _emojiCtrl;
  late String _cuisine;
  late String _type;
  late List<RecipeIngredient> _ingredients;
  late List<RecipeStep> _steps;
  late List<String> _imageUrls;
  final List<XFile> _newImages = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _nameCtrl = TextEditingController(text: r.name);
    _descCtrl = TextEditingController(text: r.description);
    _durationCtrl = TextEditingController(text: r.duration);
    _emojiCtrl = TextEditingController(text: r.emoji);
    _cuisine = r.cuisine;
    _type = r.type;
    _ingredients = List.from(r.ingredients);
    _steps = List.from(r.steps)..sort((a, b) => a.order.compareTo(b.order));
    _imageUrls = List.from(r.imageUrls);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Tarif adı boş olamaz', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final service = RecipeService();

      // Yeni fotoğrafları Storage'a yükle
      final uploaded = <String>[];
      for (final file in _newImages) {
        final url = await service.uploadRecipeImage(widget.recipe.id, file);
        uploaded.add(url);
      }

      // Adımları yeniden numaralandır
      final steps = _steps.asMap().entries.map((e) {
        return RecipeStep(
          order: e.key + 1,
          text: e.value.text,
          imageUrl: e.value.imageUrl,
        );
      }).toList();

      await service.updateRecipe(
        id: widget.recipe.id,
        name: name,
        description: _descCtrl.text.trim(),
        emoji: _emojiCtrl.text.trim().isEmpty ? '🍽️' : _emojiCtrl.text.trim(),
        duration: _durationCtrl.text.trim(),
        cuisine: _cuisine,
        type: _type,
        ingredients: _ingredients,
        steps: steps,
        imageUrls: [..._imageUrls, ...uploaded],
        tags: widget.recipe.tags,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarif güncellendi ✓'),
            backgroundColor: AppColors.primaryDark,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      _snack('Hata: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : AppColors.primaryDark,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _newImages.add(file));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Tarifi Düzenle',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: AppColors.primaryDarker,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Kaydet',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('Temel Bilgiler', [
            _field(_nameCtrl, 'Tarif Adı'),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Açıklama', maxLines: 3),
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(width: 90, child: _field(_emojiCtrl, 'Emoji')),
              const SizedBox(width: 10),
              Expanded(child: _field(_durationCtrl, 'Süre (örn: 30 dk)')),
            ]),
            const SizedBox(height: 10),
            _dropdown(
              'Mutfak',
              _cuisine,
              MockCuisines.all.map((e) => e['name']!).toList(),
              (v) => setState(() => _cuisine = v!),
            ),
            const SizedBox(height: 10),
            _dropdown(
              'Tür',
              _type,
              RecipeTypes.all.map((e) => e['name']!).toList(),
              (v) => setState(() => _type = v!),
            ),
          ]),
          const SizedBox(height: 14),
          _card('Fotoğraflar', [_buildPhotos()]),
          const SizedBox(height: 14),
          _card('Malzemeler', [
            ..._ingredients.asMap().entries.map((e) => _ingTile(e.key, e.value)),
            _addButton('Malzeme Ekle', () => _showIngredientSheet(null, null)),
          ]),
          const SizedBox(height: 14),
          _card('Adımlar', [
            ..._steps.asMap().entries.map((e) => _stepTile(e.key, e.value)),
            _addButton('Adım Ekle', () => _showStepSheet(null, null)),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── KART WRAPPER ────────────────────────────────────────────────────────────

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: context.palette.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ─── FORM ELEMANLARI ─────────────────────────────────────────────────────────

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: context.palette.textTertiary, fontSize: 13),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      void Function(String?) onChanged) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final safeValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      key: ValueKey(safeValue),
      initialValue: safeValue,
      dropdownColor: context.palette.card,
      style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: context.palette.textTertiary, fontSize: 13),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    );
  }

  // ─── FOTOĞRAFLAR ─────────────────────────────────────────────────────────────

  Widget _buildPhotos() {
    final total = _imageUrls.length + _newImages.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: total + 1,
      itemBuilder: (context, i) {
        // + butonu
        if (i == total) {
          return GestureDetector(
            onTap: _pickImage,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.palette.border, width: 1.5),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: AppColors.primary),
            ),
          );
        }
        // Mevcut URL
        if (i < _imageUrls.length) {
          return _photoThumb(
            child: CachedNetworkImage(
                imageUrl: _imageUrls[i], fit: BoxFit.cover),
            onDelete: () => setState(() => _imageUrls.removeAt(i)),
          );
        }
        // Yeni dosya
        final ni = i - _imageUrls.length;
        return _photoThumb(
          child: Image.file(File(_newImages[ni].path), fit: BoxFit.cover),
          onDelete: () => setState(() => _newImages.removeAt(ni)),
        );
      },
    );
  }

  Widget _photoThumb(
      {required Widget child, required VoidCallback onDelete}) {
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
      Positioned(
        top: 4,
        right: 4,
        child: GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.close, size: 13, color: Colors.white),
          ),
        ),
      ),
    ]);
  }

  // ─── MALZEMELİST ────────────────────────────────────────────────────────────

  Widget _ingTile(int index, RecipeIngredient ing) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(ing.emoji ?? '🥄', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ing.name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                    fontSize: 13)),
            Text(ing.amount,
                style: TextStyle(
                    color: context.palette.textTertiary, fontSize: 12)),
          ]),
        ),
        _iconBtn(Icons.edit_outlined, AppColors.primaryDarker,
            () => _showIngredientSheet(index, ing)),
        const SizedBox(width: 4),
        _iconBtn(Icons.delete_outline, Colors.red,
            () => setState(() => _ingredients.removeAt(index))),
      ]),
    );
  }

  // ─── ADIMLAR ─────────────────────────────────────────────────────────────────

  Widget _stepTile(int index, RecipeStep step) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Text('${index + 1}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(step.text,
              style: TextStyle(
                  color: context.palette.textPrimary, fontSize: 13)),
        ),
        _iconBtn(Icons.edit_outlined, AppColors.primaryDarker,
            () => _showStepSheet(index, step)),
        const SizedBox(width: 4),
        _iconBtn(Icons.delete_outline, Colors.red,
            () => setState(() => _steps.removeAt(index))),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // ─── MALZEME SHEET ───────────────────────────────────────────────────────────

  void _showIngredientSheet(int? editIndex, RecipeIngredient? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(text: existing?.amount ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                editIndex != null ? 'Malzemeyi Düzenle' : 'Malzeme Ekle',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: context.palette.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              SizedBox(width: 80, child: _sheetField(ctx, emojiCtrl, 'Emoji')),
              const SizedBox(width: 10),
              Expanded(
                  child: _sheetField(ctx, nameCtrl, 'Malzeme Adı')),
            ]),
            const SizedBox(height: 10),
            _sheetField(ctx, amountCtrl, 'Miktar (örn: 2 su bardağı)'),
            const SizedBox(height: 16),
            _saveButton(ctx, () {
              final ing = RecipeIngredient(
                ingredientId: existing?.ingredientId ?? '',
                name: nameCtrl.text.trim(),
                amount: amountCtrl.text.trim(),
                emoji: emojiCtrl.text.trim().isEmpty
                    ? null
                    : emojiCtrl.text.trim(),
              );
              setState(() {
                if (editIndex != null) {
                  _ingredients[editIndex] = ing;
                } else {
                  _ingredients.add(ing);
                }
              });
              Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  // ─── ADIM SHEET ──────────────────────────────────────────────────────────────

  void _showStepSheet(int? editIndex, RecipeStep? existing) {
    final textCtrl = TextEditingController(text: existing?.text ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(editIndex != null ? 'Adımı Düzenle' : 'Adım Ekle',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: context.palette.textPrimary)),
            const SizedBox(height: 16),
            _sheetField(ctx, textCtrl, 'Adım açıklaması', maxLines: 4),
            const SizedBox(height: 16),
            _saveButton(ctx, () {
              final step = RecipeStep(
                order: editIndex != null
                    ? _steps[editIndex].order
                    : (_steps.length + 1),
                text: textCtrl.text.trim(),
              );
              setState(() {
                if (editIndex != null) {
                  _steps[editIndex] = step;
                } else {
                  _steps.add(step);
                }
              });
              Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  // ─── SHEET YARDIMCILARI ──────────────────────────────────────────────────────

  Widget _sheetField(BuildContext sheetCtx, TextEditingController ctrl,
      String label,
      {int maxLines = 1}) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: context.palette.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: context.palette.textTertiary, fontSize: 13),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _saveButton(BuildContext sheetCtx, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
        onPressed: onTap,
        child: const Text('Kaydet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}
