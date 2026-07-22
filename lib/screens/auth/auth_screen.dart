import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_safety_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureLogin = true;
  bool _obscureReg = true;
  bool _termsAccepted = false;

  static final _termsUrl = Uri.parse(
    'https://kolaytarifler-37c45.web.app/terms',
  );
  static final _privacyUrl = Uri.parse(
    'https://kolaytarifler-37c45.web.app/privacy',
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;
    if (!_ensureTermsAccepted()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      await _recordTermsAcceptance();
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_firebaseError(e.code));
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_ensureTermsAccepted()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signUp(
            email: _regEmailCtrl.text.trim(),
            password: _regPasswordCtrl.text,
            displayName: _nameCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
          );
      await _recordTermsAcceptance();
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_firebaseError(e.code));
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_ensureTermsAccepted()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null) await _recordTermsAcceptance();
      if (user != null && mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_firebaseError(e.code));
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'network_error') {
        _showError(
          'İnternet bağlantısı yok. Lütfen bağlantını kontrol edip tekrar dene.',
        );
      } else {
        _showError(
          'Google ile giriş yapılamadı (${e.code}). Lütfen tekrar dene.',
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('google_cancelled')) {
        _showError('Google hesabı seçilmedi. Cihazında Google hesabı ekli mi?');
      } else {
        _showError('Google ile giriş yapılamadı. Lütfen tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (!_ensureTermsAccepted()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithApple();
      if (user != null) await _recordTermsAcceptance();
      if (user != null && mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      const cancelledCodes = {
        'web-context-cancelled',
        'popup-closed-by-user',
        'cancelled-popup-request',
      };
      if (!cancelledCodes.contains(e.code)) {
        _showError(
          'Apple ile giriş yapılamadı (${e.code}). Lütfen tekrar dene.',
        );
      }
    } on Exception catch (_) {
      if (mounted) {
        _showError('Apple ile giriş yapılamadı. Lütfen tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (!_ensureTermsAccepted()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).continueAsGuest();
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_firebaseError(e.code));
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _ensureTermsAccepted() {
    if (_termsAccepted) return true;
    _showError(
      'Devam etmek için Kullanım ve Topluluk Koşulları’nı kabul etmelisin.',
    );
    return false;
  }

  Future<void> _recordTermsAcceptance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    await ref.read(communitySafetyServiceProvider).acceptTerms(user.uid);
  }

  String _firebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter gir.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen biraz bekle.';
      case 'user-disabled':
        return 'Bu hesap topluluk kurallarını ihlal ettiği için askıya alınmıştır.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      default:
        return 'Bir hata oluştu ($code). Lütfen tekrar dene.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              _buildLogo(),
              const SizedBox(height: 32),
              _buildTabBar(),
              const SizedBox(height: 24),
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabs,
                  children: [_buildLoginForm(), _buildRegisterForm()],
                ),
              ),
              const SizedBox(height: 16),
              _buildTermsAcceptance(),
              const SizedBox(height: 16),
              _buildDivider(),
              const SizedBox(height: 16),
              // App Store Guideline 4.8: Google girişi sunulduğu için Apple
              // ile Giriş iOS/macOS'ta zorunlu olarak gösterilir.
              if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) ...[
                _buildAppleButton(),
                const SizedBox(height: 10),
              ],
              _buildGoogleButton(),
              const SizedBox(height: 10),
              _buildGuestButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text('🌿', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Kolay Tarifler',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDarker,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dünya mutfaklarından tarifler',
          style: TextStyle(fontSize: 13, color: context.palette.textTertiary),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.g50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primaryText,
        unselectedLabelColor: context.palette.textTertiary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Giriş Yap'),
          Tab(text: 'Kayıt Ol'),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          _field(
            controller: _emailCtrl,
            label: 'E-posta',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Geçerli e-posta girin'
                : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _passwordCtrl,
            label: 'Şifre',
            obscure: _obscureLogin,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLogin ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: context.palette.textTertiary,
              ),
              onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'En az 6 karakter' : null,
          ),
          const SizedBox(height: 20),
          _primaryButton(
            label: 'Giriş Yap',
            onTap: _loading || !_termsAccepted ? null : _signIn,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          _field(
            controller: _nameCtrl,
            label: 'Ad Soyad',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ad Soyad gerekli' : null,
          ),
          const SizedBox(height: 10),
          _field(
            controller: _usernameCtrl,
            label: 'Kullanıcı Adı',
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'En az 3 karakter' : null,
          ),
          const SizedBox(height: 10),
          _field(
            controller: _regEmailCtrl,
            label: 'E-posta',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Geçerli e-posta girin'
                : null,
          ),
          const SizedBox(height: 10),
          _field(
            controller: _regPasswordCtrl,
            label: 'Şifre',
            obscure: _obscureReg,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureReg ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: context.palette.textTertiary,
              ),
              onPressed: () => setState(() => _obscureReg = !_obscureReg),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'En az 6 karakter' : null,
          ),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'Kayıt Ol',
            onTap: _loading || !_termsAccepted ? null : _signUp,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: context.palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'veya',
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
          ),
        ),
        Expanded(child: Divider(color: context.palette.border)),
      ],
    );
  }

  Widget _buildTermsAcceptance() {
    return Semantics(
      checked: _termsAccepted,
      label: 'Kullanım ve Topluluk Koşulları kabulü',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
        decoration: BoxDecoration(
          color: context.palette.g50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _termsAccepted ? AppColors.primary : context.palette.border,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _termsAccepted,
              activeColor: AppColors.primary,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _termsAccepted = value ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Giriş yapmadan veya hesap oluşturmadan önce Kullanım ve '
                    'Topluluk Koşulları’nı okudum ve kabul ediyorum.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Uygunsuz içerik ve kötüye kullanıma sıfır tolerans uygulanır.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => launchUrl(
                          _termsUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Koşulları oku'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => launchUrl(
                          _privacyUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Gizlilik Politikası'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white : Colors.black;
    final fg = isDark ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: _loading || !_termsAccepted ? null : _signInWithApple,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apple, size: 22, color: fg),
            const SizedBox(width: 8),
            Text(
              'Apple ile Giriş Yap',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _loading || !_termsAccepted ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              height: 20,
              width: 20,
              errorBuilder: (context, error, stackTrace) => const Text(
                'G',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Google ile Giriş Yap',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return GestureDetector(
      onTap: _loading || !_termsAccepted ? null : _continueAsGuest,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.g50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.border, width: 1.5),
        ),
        child: Center(
          child: Text(
            'Misafir olarak devam et',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 14, color: context.palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: context.palette.textTertiary,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.palette.g50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? context.palette.g200 : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryText,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
        ),
      ),
    );
  }
}
