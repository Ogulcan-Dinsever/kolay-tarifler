import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _plistValue(String contents, String key) {
  final pattern = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  );
  return pattern.firstMatch(contents)?.group(1) ?? '';
}

void main() {
  test(
    'Google Sign-In istemci kimliği ve dönüş şeması iOS plistleriyle eşleşir',
    () {
      final info = File('ios/Runner/Info.plist').readAsStringSync();
      final google = File(
        'ios/Runner/GoogleService-Info.plist',
      ).readAsStringSync();

      expect(
        _plistValue(info, 'GIDClientID'),
        _plistValue(google, 'CLIENT_ID'),
      );
      expect(info, contains(_plistValue(google, 'REVERSED_CLIENT_ID')));
    },
  );

  test('Apple ile giriş yetkisi Runner entitlement dosyasında bulunur', () {
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();

    expect(entitlements, contains('com.apple.developer.applesignin'));
    expect(entitlements, contains('<string>Default</string>'));
  });
}
