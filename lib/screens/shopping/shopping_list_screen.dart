import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/calendar_entry.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/ingredient_avatar.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() =>
      _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  List<CalendarEntry> _monthEntries(List<CalendarEntry> all) {
    return all
        .where((e) {
          final d = DateTime.tryParse(e.date);
          return d != null &&
              d.year == _month.year &&
              d.month == _month.month;
        })
        .toList();
  }

  List<_AggregatedItem> _aggregate(
      List<CalendarEntry> monthEntries, List<Recipe> recipes) {
    final map = <String, _AggregatedItem>{};
    for (final entry in monthEntries) {
      final matches = recipes.where((r) => r.id == entry.recipeId);
      if (matches.isEmpty) continue;
      for (final ing in matches.first.ingredients) {
        if (ing.ingredientId.isEmpty) continue;
        final id = ing.ingredientId;
        map.putIfAbsent(
          id,
          () => _AggregatedItem(
            ingredientId: id,
            name: ing.name,
            emoji: ing.emoji ?? '🥄',
          ),
        ).addAmount(ing.amount);
      }
    }
    return map.values.toList();
  }

  String _monthLabel() {
    const names = [
      '',
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${names[_month.month]} ${_month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        ref.watch(calendarEntriesProvider).valueOrNull ?? [];
    final allRecipes = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final allIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? [];
    final ingredientMap = {
      for (final i in allIngredients) i.id: i,
    };
    final monthEntries = _monthEntries(entries);
    final items = _aggregate(monthEntries, allRecipes);
    final checked =
        ref.watch(shoppingCheckedProvider).valueOrNull ?? {};

    return Column(
      children: [
        AppHeader(
          showBackButton: true,
          title: 'Alışveriş Listesi',
          actions: [
            if (items.isNotEmpty)
              HeaderIconButton(
                icon: Icons.clear_all,
                onTap: () => ref
                    .read(shoppingCheckedProvider.notifier)
                    .clear(),
              ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              // Ay seçici
              _buildMonthSelector(context),

              // İçerik
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState(context, monthEntries.length)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, i) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final isChecked =
                              checked[item.ingredientId] ?? false;
                          return _buildItem(
                              context, item, isChecked, ingredientMap);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: context.palette.textPrimary),
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1);
            }),
          ),
          Expanded(
            child: Text(
              _monthLabel(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: context.palette.textPrimary),
            onPressed: () => setState(() {
              _month = DateTime(_month.year, _month.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, int entryCount) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            entryCount == 0
                ? 'Bu ay takvime yemek eklenmedi'
                : 'Malzeme bilgisi bulunamadı',
            style: TextStyle(
                fontSize: 14, color: context.palette.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, _AggregatedItem item, bool isChecked,
      Map<String, Ingredient> ingredientMap) {
    final detail = ingredientMap[item.ingredientId];
    return GestureDetector(
      onTap: () => ref
          .read(shoppingCheckedProvider.notifier)
          .toggle(item.ingredientId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isChecked
              ? context.palette.g50
              : context.palette.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isChecked
                ? context.palette.border
                : context.palette.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            IngredientAvatar(
              emoji: item.emoji,
              imageUrl: detail?.imageUrl,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isChecked
                          ? context.palette.textTertiary
                          : context.palette.textPrimary,
                      decoration: isChecked
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: context.palette.textTertiary,
                    ),
                  ),
                  Text(
                    item.displayAmount,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked
                    ? AppColors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isChecked
                      ? AppColors.primary
                      : context.palette.border,
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check,
                      size: 15, color: AppColors.primaryText)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Veri sınıfları ────────────────────────────────────────────

class _AggregatedItem {
  final String ingredientId;
  final String name;
  final String emoji;

  // birim → toplam miktar
  final Map<String, double> _unitQty = {};

  _AggregatedItem({
    required this.ingredientId,
    required this.name,
    required this.emoji,
  });

  void addAmount(String rawAmount) {
    final (value, unit) = _parse(rawAmount);
    _unitQty[unit] = (_unitQty[unit] ?? 0) + value;
  }

  String get displayAmount {
    return _unitQty.entries.map((e) {
      final v = e.value;
      final u = e.key;
      final vStr = v.truncateToDouble() == v
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
      return u.isEmpty ? vStr : '$vStr $u';
    }).join(', ');
  }

  // "400 gr" → (400, "gr"),  "1 orta" → (1, "orta"),  "2 su bardağı" → (2, "su bardağı")
  static (double, String) _parse(String raw) {
    final trimmed = raw.trim();
    final m = RegExp(r'^(\d+(?:[,\.]\d+)?)\s*(.*)$').firstMatch(trimmed);
    if (m == null) return (1, trimmed);
    final value = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 1;
    return (value, m.group(2)!.trim());
  }
}
