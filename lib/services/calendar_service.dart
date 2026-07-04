import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_entry.dart';

/// Takvim ve alışveriş listesini telefonda (SharedPreferences) saklar.
class CalendarService {
  static const _entriesKey = 'calendar_entries';
  static const _shoppingKey = 'shopping_checked';

  // ─── Takvim ──────────────────────────────────────────────

  Future<List<CalendarEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_entriesKey) ?? [];
    final entries = <CalendarEntry>[];
    for (final e in raw) {
      try {
        entries.add(CalendarEntry.fromJson(jsonDecode(e) as Map<String, dynamic>));
      } catch (_) {
        // Bozuk/eksik bir kayıt tüm listeyi (ve onu kullanan Takvim,
        // Alışveriş Listesi, Mutfak Karnesi ekranlarını) düşürmesin —
        // sadece o kaydı atla.
      }
    }
    return entries;
  }

  Future<void> addEntry(CalendarEntry entry) async {
    final entries = await loadEntries();
    entries.add(entry);
    await _saveEntries(entries);
  }

  Future<void> removeEntry(String date, String recipeId) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.date == date && e.recipeId == recipeId);
    await _saveEntries(entries);
  }

  Future<void> _saveEntries(List<CalendarEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _entriesKey,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Belirli tarih aralığındaki girişler (alışveriş listesi için)
  Future<List<CalendarEntry>> entriesInRange(DateTime from, DateTime to) async {
    final all = await loadEntries();
    return all.where((e) {
      final d = DateTime.tryParse(e.date);
      if (d == null) return false;
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  // ─── Alışveriş Listesi ───────────────────────────────────

  /// Belirli bir alışveriş oturumu için hangi malzemeler işaretlendi.
  /// Key: 'ingredientId', Value: checked mi?
  Future<Map<String, bool>> loadShoppingChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shoppingKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as bool?) ?? false));
    } catch (_) {
      return {};
    }
  }

  Future<void> setIngredientChecked(String ingredientId, bool checked) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadShoppingChecked();
    current[ingredientId] = checked;
    await prefs.setString(_shoppingKey, jsonEncode(current));
  }

  Future<void> clearShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shoppingKey);
  }
}
