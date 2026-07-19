import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/core/theme/app_theme.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/providers/auth_provider.dart';
import 'package:kolay_tarifler/widgets/recipe_card.dart';

void main() {
  final recipe = Recipe(
    id: 'recipe-1',
    name: 'Mercimek Yemeği',
    description: 'Test tarifi',
    cuisine: 'Türk',
    type: 'Ana Yemek',
    duration: '1 sa 30 dk',
    emoji: '🍲',
    authorId: 'official',
    createdAt: DateTime(2026),
  );

  testWidgets('kart aksiyonları sağ kenara hizalanır', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: RecipeCard(recipe: recipe)),
        ),
      ),
    );
    await tester.pump();

    final actions = tester.widget<Column>(
      find.byKey(const Key('recipe-card-actions')),
    );
    expect(actions.crossAxisAlignment, CrossAxisAlignment.end);
  });

  test('beğeni görünümü uzak yazma bitmeden iyimser güncellenir', () async {
    final persistGate = Completer<void>();
    bool? optimisticValue;

    final operation = runOptimisticLikeToggle(
      currentValue: false,
      setOptimisticValue: (value) => optimisticValue = value,
      persist: () => persistGate.future,
    );

    expect(optimisticValue, isTrue);
    persistGate.complete();
    await operation;
    expect(optimisticValue, isTrue);
  });

  test('beğeni yazması başarısızsa iyimser durum geri alınır', () async {
    bool? optimisticValue;

    await expectLater(
      runOptimisticLikeToggle(
        currentValue: false,
        setOptimisticValue: (value) => optimisticValue = value,
        persist: () async => throw StateError('network'),
      ),
      throwsStateError,
    );

    expect(optimisticValue, isNull);
  });
}
