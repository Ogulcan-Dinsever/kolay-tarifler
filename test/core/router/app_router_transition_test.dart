import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kolay_tarifler/core/router/app_router.dart';

void main() {
  testWidgets('alt menü sayfaları geçiş animasyonu kullanmaz', (tester) async {
    late GoRouterState routeState;
    final router = GoRouter(
      initialLocation: '/tab',
      routes: [
        GoRoute(
          path: '/tab',
          builder: (context, state) {
            routeState = state;
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      WidgetsApp.router(color: const Color(0xFFFFFFFF), routerConfig: router),
    );

    final page = buildMainTabPage(routeState, const SizedBox());
    expect(page, isA<NoTransitionPage<void>>());
    expect(page.key, routeState.pageKey);
  });
}
