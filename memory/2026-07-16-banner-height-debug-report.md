# Banner Height Debug Report — 2026-07-16

- **Symptom:** The anchored AdMob banner reserved substantially more vertical space than the rendered creative above the bottom navigation.
- **Root cause:** `AnchoredBannerAd` requested the large anchored adaptive size and added 8 logical pixels of bottom padding, so the slot was taller than a standard banner.
- **Fix:** Request the standard 320×50 AdMob banner and size the surrounding frame to the exact creative height without extra vertical padding.
- **Evidence:** Verified on Android 17 emulator with Google's test ad; the loaded ad occupies one 50 logical-pixel slot directly above navigation.
- **Regression test:** `test/widgets/anchored_banner_ad_test.dart` asserts both the frame height and creative size.
- **Related:** No earlier banner sizing regression was found in project history.
- **Status:** DONE
