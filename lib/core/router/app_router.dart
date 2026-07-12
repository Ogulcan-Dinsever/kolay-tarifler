import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../layouts/main_layout.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/ingredients/ingredients_screen.dart';
import '../../screens/types/types_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/recipe_detail/recipe_detail_screen.dart';
import '../../screens/shopping/shopping_list_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/create_sub_recipe/create_sub_recipe_screen.dart';
import '../../models/recipe.dart';
import '../../screens/admin/admin_screen.dart';
import '../../screens/admin/edit_recipe_screen.dart';
import '../../screens/submit_recipe/submit_recipe_screen.dart';
import '../../screens/submit_recipe/my_submissions_screen.dart';
import '../../screens/notifications/notifications_screen.dart';

// Auth state değişince router'ı yenile
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null && !user.isAnonymous;
      final isOnAuth = state.matchedLocation == '/auth';

      // Giriş yapmış kullanıcı auth ekranına gitmeye çalışırsa ana sayfaya yönlendir
      if (isLoggedIn && isOnAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/ingredients',
            builder: (context, state) => const IngredientsScreen(),
          ),
          GoRoute(
            path: '/types',
            builder: (context, state) => const TypesScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/recipe/:id',
            builder: (context, state) => RecipeDetailScreen(
              recipeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/shopping',
            builder: (context, state) => const ShoppingListScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
          GoRoute(
            path: '/submit-recipe',
            builder: (context, state) => const SubmitRecipeScreen(),
          ),
          GoRoute(
            path: '/my-submissions',
            builder: (context, state) => const MySubmissionsScreen(),
          ),
          // Bildirim merkezi — alt menüde sekmesi yok; yalnızca ana
          // ekrandaki zil butonundan açılır.
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/recipe/:parentId/create-version',
        builder: (context, state) => CreateSubRecipeScreen(
          parentRecipeId: state.pathParameters['parentId']!,
        ),
      ),
      GoRoute(
        path: '/recipe/:id/edit',
        builder: (context, state) => EditRecipeScreen(
          recipe: state.extra as Recipe,
        ),
      ),
    ],
  );
});
