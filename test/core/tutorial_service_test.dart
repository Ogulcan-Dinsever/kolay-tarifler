import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/core/tutorial/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tutorialKey = 'tutorial_home_v2';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'claims a tutorial before it is displayed, even if it is not completed',
    () async {
      expect(await TutorialService.shouldShow(tutorialKey), isTrue);
      expect(await TutorialService.shouldShow(tutorialKey), isFalse);
    },
  );

  test('resetAll makes a claimed tutorial available again', () async {
    await TutorialService.shouldShow(tutorialKey);

    await TutorialService.resetAll();

    expect(await TutorialService.shouldShow(tutorialKey), isTrue);
  });
}
