import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_service.dart';
import 'auth_provider.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// Email ayrı provider'da tutulur; aynı email için tekrar tetiklenmez.
// firebaseUserProvider token yenileme gibi durumlarda emit etse bile
// email değişmezse isAdminProvider yeniden açılmaz.
final _adminEmailProvider = Provider<String?>((ref) {
  return ref.watch(firebaseUserProvider).valueOrNull?.email?.toLowerCase();
});

final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(_adminEmailProvider) == AdminService.initialAdminEmail;
});

final isAdminProvider = StreamProvider<bool>((ref) {
  final email = ref.watch(_adminEmailProvider);
  if (email == null) return Stream.value(false);
  if (email == AdminService.initialAdminEmail) return Stream.value(true);
  return ref.watch(adminServiceProvider).isAdminStream(email);
});

final adminUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (!ref.watch(isSuperAdminProvider)) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }

  return ref.watch(adminServiceProvider).adminsStream().map((admins) {
    final result = [...admins];
    final hasOwner = result.any(
      (admin) => admin['email'] == AdminService.initialAdminEmail,
    );
    if (!hasOwner) {
      result.insert(0, const {
        'email': AdminService.initialAdminEmail,
        'role': 'owner',
      });
    }
    result.sort(
      (a, b) => (a['email'] as String).compareTo(b['email'] as String),
    );
    return result;
  });
});
