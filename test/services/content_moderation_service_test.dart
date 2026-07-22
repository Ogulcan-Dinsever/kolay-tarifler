import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/services/content_moderation_service.dart';

void main() {
  group('ContentModerationService', () {
    test('normal recipe text is accepted', () {
      expect(
        () => ContentModerationService.validate(
          'Soğanları pembeleşene kadar kavurun ve mercimeği ekleyin.',
        ),
        returnsNormally,
      );
    });

    test('Turkish characters are normalized before filtering', () {
      expect(
        () => ContentModerationService.validate('SİKTİR git'),
        throwsA(isA<ContentModerationException>()),
      );
    });

    test('objectionable phrase is rejected', () {
      expect(
        () => ContentModerationService.validate('kill yourself'),
        throwsA(isA<ContentModerationException>()),
      );
    });

    test('spam redirect is rejected', () {
      expect(
        () => ContentModerationService.validate(
          'https://bit.ly/ornek üzerinden bahis kuponu al',
        ),
        throwsA(isA<ContentModerationException>()),
      );
    });

    test('substring inside a legitimate word is not rejected', () {
      expect(
        () => ContentModerationService.validate('Kapıcı usulü pilav'),
        returnsNormally,
      );
    });
  });
}
