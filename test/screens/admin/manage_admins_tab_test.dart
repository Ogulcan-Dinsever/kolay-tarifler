import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/core/theme/app_theme.dart';
import 'package:kolay_tarifler/providers/admin_provider.dart';
import 'package:kolay_tarifler/screens/admin/manage_admins_tab.dart';

void main() {
  Widget app({
    required bool isSuperAdmin,
    Stream<List<Map<String, dynamic>>>? admins,
  }) {
    return ProviderScope(
      overrides: [
        isSuperAdminProvider.overrideWith((ref) => isSuperAdmin),
        adminUsersProvider.overrideWith(
          (ref) => admins ?? const Stream.empty(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ManageAdminsTab()),
      ),
    );
  }

  testWidgets('super admin sees the existing admin list', (tester) async {
    await tester.pumpWidget(
      app(
        isSuperAdmin: true,
        admins: Stream.value(const [
          {'email': 'ogulcandnsvr@gmail.com'},
          {'email': 'editor@example.com'},
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ogulcandnsvr@gmail.com'), findsOneWidget);
    expect(find.text('editor@example.com'), findsOneWidget);
    expect(find.text('Admin Olarak Ekle'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('delegated admin cannot access admin management', (tester) async {
    await tester.pumpWidget(app(isSuperAdmin: false));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Admin yetkilerini yalnızca ogulcandnsvr@gmail.com yönetebilir.',
      ),
      findsOneWidget,
    );
    expect(find.text('Admin Olarak Ekle'), findsNothing);
  });
}
