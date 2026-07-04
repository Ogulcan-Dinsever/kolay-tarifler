import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'models/ingredient.dart';
import 'models/recipe.dart';
import 'models/recipe_ingredient.dart';
import 'models/recipe_step.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/recipe_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Fontu önceden indir — sonraki açılışlarda disk cache'ten anında yükler.
  await GoogleFonts.pendingFonts([GoogleFonts.nunito()]);

  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Hive
  await Hive.initFlutter();
  Hive.registerAdapter(IngredientCategoryAdapter());
  Hive.registerAdapter(RecipeIngredientAdapter());
  Hive.registerAdapter(RecipeStepAdapter());
  Hive.registerAdapter(IngredientAdapter());
  Hive.registerAdapter(RecipeAdapter());
  try {
    await Future.wait([
      Hive.openBox<Recipe>(RecipeCacheService.recipesBoxName),
      Hive.openBox<Ingredient>(RecipeCacheService.ingredientsBoxName),
    ]);
  } catch (_) {
    // Box açılamazsa (disk dolu, şema değişimi) önbelleği sıfırla ve yeniden dene
    await Hive.deleteBoxFromDisk(RecipeCacheService.recipesBoxName);
    await Hive.deleteBoxFromDisk(RecipeCacheService.ingredientsBoxName);
    await Future.wait([
      Hive.openBox<Recipe>(RecipeCacheService.recipesBoxName),
      Hive.openBox<Ingredient>(RecipeCacheService.ingredientsBoxName),
    ]);
  }

  // Eski SharedPreferences cache'ini bir kerelik temizle
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('cache_recipes_v1') ||
      prefs.containsKey('cache_ingredients_v1')) {
    await prefs.remove('cache_recipes_v1');
    await prefs.remove('cache_ingredients_v1');
    final oldKeys =
        prefs.getKeys().where((k) => k.startsWith('cache_recipe_')).toList();
    for (final key in oldKeys) {
      await prefs.remove(key);
    }
  }

  // FCM + yerel bildirimler
  await NotificationService.init();

  final savedTheme = prefs.getString('theme_mode') == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(() => ThemeModeNotifier(savedTheme)),
      ],
      child: const TarifliApp(),
    ),
  );
}

class TarifliApp extends ConsumerStatefulWidget {
  const TarifliApp({super.key});

  @override
  ConsumerState<TarifliApp> createState() => _TarifliAppState();
}

class _TarifliAppState extends ConsumerState<TarifliApp> {
  StreamSubscription<String>? _notifSub;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();

    // Bildirime tıklanınca yönlendir
    _notifSub = NotificationService.routeStream.listen((route) {
      _router?.go(route);
    });

    // Uygulama kapalıyken tıklanmış rota varsa ilk frame'de işle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.pendingRoute;
      if (pending != null) {
        NotificationService.pendingRoute = null;
        _router?.go(pending);
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Kolay Tarifler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router!,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final widthFactor = (mq.size.width / 390.0).clamp(0.78, 1.0);
        final userScale = mq.textScaler.scale(1.0).clamp(0.78, 1.2);
        final combined = (widthFactor * userScale).clamp(0.78, 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(combined)),
          child: child!,
        );
      },
    );
  }
}
