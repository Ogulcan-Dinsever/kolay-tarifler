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

final isAdminProvider = StreamProvider<bool>((ref) {
  final email = ref.watch(_adminEmailProvider);
  if (email == null) return Stream.value(false);
  return ref.watch(adminServiceProvider).isAdminStream(email);
});
