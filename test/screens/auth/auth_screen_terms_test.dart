import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/core/theme/app_theme.dart';
import 'package:kolay_tarifler/screens/auth/auth_screen.dart';

void main() {
  testWidgets(
    'giriş seçenekleri koşullar kabul edilmeden de dokunmaya yanıt verir',
    (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.text('Google ile Giriş Yap');
      await tester.scrollUntilVisible(
        googleButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(googleButton);
      await tester.pump();

      expect(
        find.text(
          'Devam etmek için Kullanım ve Topluluk Koşulları’nı kabul etmelisin.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('koşul kartının tamamı kabul seçimini değiştirir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final termsCard = find.byKey(const Key('terms_acceptance_card'));
    await tester.scrollUntilVisible(
      termsCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(termsCard);
    await tester.pump();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });
}
