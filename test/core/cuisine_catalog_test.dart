import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/screens/splash/splash_screen.dart';

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
  group('Splash startup', () {
    test('navigasyon arka plan hazirligini beklemez', () async {
      final animation = Completer<void>();
      final preparation = Completer<void>();
      var navigationReady = false;

      final navigation = waitForSplashNavigation(
        animation: animation.future,
        preparation: preparation.future,
      ).then((_) => navigationReady = true);

      await Future<void>.delayed(Duration.zero);
      expect(navigationReady, isFalse);

      animation.complete();
      await navigation;

      expect(navigationReady, isTrue);
      expect(preparation.isCompleted, isFalse);
      preparation.complete();
    });

    test('splash seffaf logoyu kullanir', () {
      expect(splashLogoAsset, 'assets/images/app_header_logo.png');
    });
  });

  group('MockCuisines.orderedForRecipes', () {
    test('eski mutfak adlarini ulke adlariyla gosterir', () {
      final ordered = MockCuisines.orderedForRecipes([
        _recipe('1', 'Azeri'),
        _recipe('2', 'Ermeni'),
      ]);
      final names = ordered.map((item) => item['name']).toList();

      expect(names, containsAll(<String>['Azerbaycan', 'Ermenistan']));
      expect(names, isNot(contains('Azeri')));
      expect(names, isNot(contains('Ermeni')));
      expect(MockCuisines.storageName('Azerbaycan'), 'Azeri');
      expect(MockCuisines.storageName('Ermenistan'), 'Ermeni');
    });

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
