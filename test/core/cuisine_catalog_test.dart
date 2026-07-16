import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/models/recipe.dart';

Recipe _recipe(String id, String cuisine) => Recipe(
  id: id,
  name: 'Tarif $id',
  description: '',
  cuisine: cuisine,
  type: 'Ana Yemek',
  duration: '30 dk',
  emoji: '🍽️',
  authorId: 'test',
  createdAt: DateTime(2026),
);

void main() {
  group('MockCuisines.orderedForRecipes', () {
    test('tarif bulunan mutfakları boş mutfaklardan önce sıralar', () {
      final ordered = MockCuisines.orderedForRecipes([
        _recipe('1', 'Kore'),
        _recipe('2', 'Yunan'),
      ]);

      final koreIndex = ordered.indexWhere((item) => item['name'] == 'Kore');
      final yunanIndex = ordered.indexWhere((item) => item['name'] == 'Yunan');
      final emptyIndex = ordered.indexWhere(
        (item) => item['name'] == 'Fransız',
      );

      expect(koreIndex, isNonNegative);
      expect(yunanIndex, isNonNegative);
      expect(koreIndex, lessThan(emptyIndex));
      expect(yunanIndex, lessThan(emptyIndex));
    });

    test('katalogda olmayan tarifli mutfağı otomatik ekler', () {
      final ordered = MockCuisines.orderedForRecipes([
        _recipe('1', 'Test Mutfağı'),
      ]);

      expect(ordered.firstWhere((item) => item['name'] == 'Test Mutfağı'), {
        'flag': '🌍',
        'name': 'Test Mutfağı',
      });
      expect(ordered.first['name'], 'Test Mutfağı');
    });

    test(
      'tarif sayısı yüksek mutfağı diğer tarifli mutfaklardan önce gösterir',
      () {
        final ordered = MockCuisines.orderedForRecipes([
          _recipe('1', 'Japon'),
          _recipe('2', 'Türk'),
          _recipe('3', 'Türk'),
        ]);

        expect(ordered[0]['name'], 'Türk');
        expect(ordered[1]['name'], 'Japon');
      },
    );
  });
}
