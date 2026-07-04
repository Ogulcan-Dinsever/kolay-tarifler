import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kolay_tarifler/services/calendar_service.dart';

void main() {
  group('CalendarService.loadEntries', () {
    test('returns all entries when all stored JSON is well-formed', () async {
      SharedPreferences.setMockInitialValues({
        'calendar_entries': [
          '{"date":"2026-07-01","recipeId":"r1","recipeName":"Mercimek Çorbası","recipeEmoji":"🍲"}',
          '{"date":"2026-07-02","recipeId":"r2","recipeName":"Karnıyarık","recipeEmoji":"🥘"}',
        ],
      });

      final entries = await CalendarService().loadEntries();

      expect(entries.length, 2);
      expect(entries[0].recipeName, 'Mercimek Çorbası');
      expect(entries[1].recipeName, 'Karnıyarık');
    });

    test(
      'CRITICAL regression: skips malformed entries and returns the rest instead of throwing',
      () async {
        SharedPreferences.setMockInitialValues({
          'calendar_entries': [
            '{"date":"2026-07-01","recipeId":"r1","recipeName":"Mercimek Çorbası","recipeEmoji":"🍲"}',
            '{"date":"2026-07-02","recipeId":"r2"}', // eksik zorunlu alanlar (recipeName/recipeEmoji)
            'not even valid json',
            '',
            '{"date":"2026-07-03","recipeId":"r3","recipeName":"Ev Yapımı Pide","recipeEmoji":"🍕"}',
          ],
        });

        final entries = await CalendarService().loadEntries();

        expect(entries.length, 2);
        expect(entries.map((e) => e.recipeId), containsAll(['r1', 'r3']));
      },
    );

    test(
      'returns an empty list, not a thrown error, when every entry is malformed',
      () async {
        SharedPreferences.setMockInitialValues({
          'calendar_entries': ['not json', '{broken', ''],
        });

        final entries = await CalendarService().loadEntries();

        expect(entries, isEmpty);
      },
    );

    test('returns an empty list when no entries are stored', () async {
      SharedPreferences.setMockInitialValues({});

      final entries = await CalendarService().loadEntries();

      expect(entries, isEmpty);
    });
  });
}
