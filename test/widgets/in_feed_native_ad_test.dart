import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/widgets/in_feed_native_ad.dart';

void main() {
  group('buildInFeedEntries', () {
    test('does not insert an ad before five items', () {
      final entries = buildInFeedEntries([1, 2, 3, 4]);

      expect(entries.whereType<InFeedAdSlot<int>>(), isEmpty);
    });

    test('inserts ads after item 5 and item 15', () {
      final entries = buildInFeedEntries(List.generate(20, (i) => i));
      final adIndexes = <int>[];
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] is InFeedAdSlot<int>) adIndexes.add(i);
      }

      expect(adIndexes, [5, 16]);
      expect(entries.whereType<InFeedAdSlot<int>>().length, 2);
    });

    test('preserves content order', () {
      final items = List.generate(31, (i) => 'recipe-$i');
      final entries = buildInFeedEntries(items);

      expect(
        entries.whereType<InFeedContent<String>>().map((e) => e.item),
        items,
      );
    });
  });

  test('native retry delay is bounded', () {
    expect(inFeedNativeRetryDelay(1), const Duration(seconds: 10));
    expect(inFeedNativeRetryDelay(99), const Duration(minutes: 5));
  });

  test('native card reserves enough height for a 120-point media view', () {
    expect(inFeedNativeAdHeight, greaterThanOrEqualTo(136));
  });
}
