import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/admin_service.dart';
import '../../services/notification_service.dart';
import '../../services/recipe_cache_service.dart';
import '../../services/recipe_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      _prepareApp(),
    ]);
    if (mounted) context.go('/');
  }

  Future<void> _prepareApp() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}

    // Kalıcı oturumla açılan gerçek kullanıcıda FCM token'ını yeniden kaydet ve
    // onTokenRefresh dinleyicisini aktifleştir. Aksi halde token rotasyonu
    // Firestore'a yansımaz, kullanıcıya bildirim sessizce durur.
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null && !u.isAnonymous) {
        await NotificationService.saveToken(u.uid);
      }
    } catch (_) {}

    try {
      final service = RecipeService();
      final cache = RecipeCacheService();
      await service.seedIngredientsIfEmpty();
      await service.seedIfEmpty();
      await AdminService().seedInitialAdmin();

      final cached = cache.loadRecipes();
      if (cached.isEmpty) {
        final recipes = await service.fetchAllRecipesOnce();
        await cache.saveRecipes(recipes);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                'assets/images/logo_slogan.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
