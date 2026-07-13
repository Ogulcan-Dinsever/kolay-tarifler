import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/community_safety_service.dart';

final communitySafetyServiceProvider = Provider<CommunitySafetyService>(
  (ref) => CommunitySafetyService(),
);

final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(firebaseUserProvider).valueOrNull;
  if (user == null || user.isAnonymous) return Stream.value(const {});
  return ref
      .watch(communitySafetyServiceProvider)
      .blockedUserIdsStream(user.uid);
});
