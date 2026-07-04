import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_entry.dart';
import '../services/calendar_service.dart';

final calendarServiceProvider =
    Provider<CalendarService>((ref) => CalendarService());

// Tüm takvim girişleri (telefon)
final calendarEntriesProvider =
    AsyncNotifierProvider<CalendarNotifier, List<CalendarEntry>>(
  CalendarNotifier.new,
);

class CalendarNotifier extends AsyncNotifier<List<CalendarEntry>> {
  @override
  Future<List<CalendarEntry>> build() async {
    return ref.read(calendarServiceProvider).loadEntries();
  }

  Future<void> add(CalendarEntry entry) async {
    await ref.read(calendarServiceProvider).addEntry(entry);
    state = AsyncData([...state.valueOrNull ?? [], entry]);
  }

  Future<void> remove(String date, String recipeId) async {
    await ref.read(calendarServiceProvider).removeEntry(date, recipeId);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((e) => !(e.date == date && e.recipeId == recipeId))
          .toList(),
    );
  }
}

// Alışveriş listesi checkbox durumları
final shoppingCheckedProvider =
    AsyncNotifierProvider<ShoppingNotifier, Map<String, bool>>(
  ShoppingNotifier.new,
);

class ShoppingNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    return ref.read(calendarServiceProvider).loadShoppingChecked();
  }

  Future<void> toggle(String ingredientId) async {
    final current = state.valueOrNull ?? {};
    final next = !( current[ingredientId] ?? false);
    await ref
        .read(calendarServiceProvider)
        .setIngredientChecked(ingredientId, next);
    state = AsyncData({...current, ingredientId: next});
  }

  Future<void> clear() async {
    await ref.read(calendarServiceProvider).clearShoppingList();
    state = const AsyncData({});
  }
}
