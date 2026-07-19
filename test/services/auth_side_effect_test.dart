import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/services/auth_service.dart';

void main() {
  test('bildirim tokenı hatası tamamlanmış oturum açmayı bozmaz', () async {
    Object? reportedError;

    await expectLater(
      runPostSignInSideEffect(
        () async => throw StateError('APNs token is not set'),
        onError: (error, stack) async => reportedError = error,
      ),
      completes,
    );

    expect(reportedError, isA<StateError>());
  });

  test('hata raporlama servisi de hata verse oturum açma tamamlanır', () async {
    await expectLater(
      runPostSignInSideEffect(
        () async => throw StateError('token error'),
        onError: (error, stack) async => throw StateError('reporting error'),
      ),
      completes,
    );
  });

  test('temizlik hatası Firebase çıkışını engellemez', () async {
    var signedOut = false;
    Object? reportedError;

    await runSignOutFlow(
      cleanupOperations: [
        () async => throw StateError('APNs token is not set'),
        () async {},
      ],
      signOut: () async => signedOut = true,
      onCleanupError: (error, stack) async => reportedError = error,
    );

    expect(signedOut, isTrue);
    expect(reportedError, isA<StateError>());
  });
}
