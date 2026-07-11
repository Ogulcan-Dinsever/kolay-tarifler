import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/calendar_entry.dart';
import '../../models/recipe.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/recipe_service.dart';
import '../../widgets/app_header.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _focusedDay = today;
    _selectedDay = today;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<CalendarEntry> _entriesForDay(List<CalendarEntry> all, DateTime day) =>
      all.where((e) => e.date == _dateStr(day)).toList();

  String _monthName(int month) {
    const names = [
      '',
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return names[month];
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(calendarEntriesProvider).valueOrNull ?? [];
    final selectedDayEntries = _entriesForDay(entries, _selectedDay);

    return Column(
      children: [
        AppHeader(
          titleWidget: Text(
            'Yemek Takvimi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          actions: [
            HeaderIconButton(
              icon: Icons.shopping_cart_outlined,
              onTap: () => context.push('/shopping'),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendar(context, entries),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedDay.day} ${_monthName(_selectedDay.month)} Yemekleri',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.palette.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAddMealModal(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  size: 15, color: AppColors.primaryText),
                              SizedBox(width: 4),
                              Text(
                                'Yemek Ekle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedDayEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Bu gün için yemek planlanmadı',
                        style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textTertiary),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: selectedDayEntries
                          .map((e) => _buildEntryCard(context, e))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, List<CalendarEntry> entries) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: TableCalendar(
        locale: 'tr_TR',
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => _entriesForDay(entries, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) =>
            setState(() => _focusedDay = focusedDay),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: context.palette.g100,
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
          markerDecoration: const BoxDecoration(
            color: AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
          defaultTextStyle:
              TextStyle(color: context.palette.textPrimary),
          outsideTextStyle:
              TextStyle(color: context.palette.textTertiary),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: context.palette.textPrimary),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: context.palette.textPrimary),
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, CalendarEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.palette.g50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(entry.recipeEmoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.recipeName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 18, color: context.palette.textTertiary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref
                .read(calendarEntriesProvider.notifier)
                .remove(entry.date, entry.recipeId),
          ),
        ],
      ),
    );
  }

  void _showAddMealModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMealSheet(
        selectedDay: _selectedDay,
        monthName: _monthName(_selectedDay.month),
        onAdd: (recipe) async {
          try {
            await ref.read(calendarEntriesProvider.notifier).add(
                  CalendarEntry(
                    date: _dateStr(_selectedDay),
                    recipeId: recipe.id,
                    recipeName: recipe.name,
                    recipeEmoji: recipe.emoji,
                  ),
                );
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${recipe.name} takvime eklendi 📅'),
                  backgroundColor: AppColors.primaryDark,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Takvime eklenemedi: $e'),
                  backgroundColor: Colors.red[700],
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ─── Arama özellikli tarif seçme sheet'i ──────────────────────

class _AddMealSheet extends ConsumerStatefulWidget {
  final DateTime selectedDay;
  final String monthName;
  final Future<void> Function(Recipe recipe) onAdd;

  const _AddMealSheet({
    required this.selectedDay,
    required this.monthName,
    required this.onAdd,
  });

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final filtered = all.where((r) {
      if (_query.isEmpty) return true;
      final q = RecipeService.foldTurkish(_query);
      return RecipeService.foldTurkish(r.name).contains(q) ||
          RecipeService.foldTurkish(r.cuisine).contains(q) ||
          RecipeService.foldTurkish(r.type).contains(q);
    }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          // Sürükleme tutacağı
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Arama kutusu + tarih
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                        fontSize: 14, color: context.palette.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tarif ara...',
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: context.palette.textTertiary),
                      prefixIcon: Icon(Icons.search,
                          size: 20, color: context.palette.textTertiary),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close,
                                  size: 18,
                                  color: context.palette.textTertiary),
                            )
                          : null,
                      filled: true,
                      fillColor: context.palette.g50,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: context.palette.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: context.palette.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.selectedDay.day} ${widget.monthName}',
                  style: TextStyle(
                      fontSize: 12, color: context.palette.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tarif listesi
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tarif bulunamadı',
                      style: TextStyle(
                          fontSize: 13,
                          color: context.palette.textTertiary),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) =>
                        Divider(height: 1, color: context.palette.border),
                    itemBuilder: (_, i) {
                      final recipe = filtered[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.palette.g50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(recipe.emoji,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        title: Text(
                          recipe.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.palette.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${recipe.duration} · ${recipe.cuisine}',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.palette.textTertiary),
                        ),
                        onTap: () => widget.onAdd(recipe),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
