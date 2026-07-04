import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/ingredient.dart';

class IngredientPickerSheet extends StatefulWidget {
  final List<Ingredient> ingredients;
  final void Function(Ingredient) onSelected;

  const IngredientPickerSheet({
    super.key,
    required this.ingredients,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Ingredient> ingredients,
    required void Function(Ingredient) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientPickerSheet(
        ingredients: ingredients,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<IngredientPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<Ingredient> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.ingredients;
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = widget.ingredients
          .where((i) => i.name.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            _buildHandle(),
            const Text(
              'Malzeme Seç',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchField(),
            const SizedBox(height: 4),
            Expanded(child: _buildList(scrollCtrl)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.lightBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(fontSize: 14, color: AppColors.lightText),
        decoration: InputDecoration(
          hintText: 'Malzeme ara...',
          hintStyle:
              const TextStyle(fontSize: 14, color: AppColors.lightTextTertiary),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.lightTextTertiary, size: 20),
          filled: true,
          fillColor: AppColors.lightG50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.lightBorder, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.lightBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollCtrl) {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.lightTextTertiary),
            SizedBox(height: 8),
            Text('Malzeme bulunamadı',
                style: TextStyle(
                    fontSize: 14, color: AppColors.lightTextTertiary)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filtered.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.lightBorder),
      itemBuilder: (ctx, i) {
        final ing = _filtered[i];
        return ListTile(
          leading: _buildLeading(ing),
          title: Text(
            ing.name,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.lightText),
          ),
          subtitle: Text(
            ing.category.label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.lightTextTertiary),
          ),
          onTap: () {
            widget.onSelected(ing);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Widget _buildLeading(Ingredient ing) {
    if (ing.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          ing.imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _emojiBox(ing.emoji),
        ),
      );
    }
    return _emojiBox(ing.emoji);
  }

  Widget _emojiBox(String emoji) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.lightG50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji.isEmpty ? '🥬' : emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
