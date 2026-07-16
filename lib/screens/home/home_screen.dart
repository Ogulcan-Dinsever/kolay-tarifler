import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/tutorial/tutorial_overlay.dart';
import '../../layouts/main_layout.dart';
import '../../core/utils/format.dart';
import '../../models/recipe.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/recipe_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cuisine_chip.dart';
import '../../widgets/featured_card.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/section_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCuisine = 'Türk';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Karıştırılmış 10 tarif — mutfak değişince sıfırlanır
  List<Recipe> _randomRecipes = [];
  String _randomizedFor = '';

  // Tutorial GlobalKey'leri
  final _searchKey = GlobalKey();
  final _cuisineKey = GlobalKey();
  final _recipeKey = GlobalKey();
  final _featuredKey = GlobalKey();
  final _bellKey = GlobalKey();

  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final should = await TutorialService.shouldShow('tutorial_home_v2');
    if (!should || !mounted) return;
    // Tarif listesinin yüklenmesi için bekle (recipeKey henüz render edilmedi)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _insertTutorial();
  }

  void _insertTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        storageKey: 'tutorial_home_v2',
        steps: [
          TutorialStep(
            emoji: '🔍',
            title: 'Tarif Ara',
            description:
                'Aradığın yemeği buraya yaz. Türkçe karakter takılmaz: "kofte" yazsan da İçli Köfte\'yi bulur.',
            targetKey: _searchKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🌍',
            title: 'Dünya Mutfakları',
            description:
                'Tarifi olan mutfaklar önce gelir. Bir mutfak seç; 10 farklı tarife göz at veya Tümünü gör ile hepsini keşfet.',
            targetKey: _cuisineKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '⭐',
            title: 'Haftanın Tarifi',
            description:
                'Her hafta öne çıkan seçki burada. Tek dokunuşla detayına git.',
            targetKey: _featuredKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🍽️',
            title: 'Tarif Kartları',
            description:
                'Karta tıkla: malzemeler, adımlar, yorumlar, kişisel notların ve topluluk sürümleri tek ekranda. Kalple beğenmeyi unutma!',
            targetKey: _recipeKey,
            spotlightPadding: 12,
          ),
          TutorialStep(
            emoji: '🔔',
            title: 'Bildirimlerin',
            description:
                'Tariflerine gelen beğeni ve yorumlar ile başvuru sonuçların zile düşer. Kırmızı nokta = okunmamış var.',
            targetKey: _bellKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🧭',
            title: 'Alt Menüyü Keşfet',
            description:
                'Malzeme: dolabındakileri seç, sana uygun tarifleri bulsun. Takvim: haftanı planla, alışveriş listen kendiliğinden oluşsun.',
            targetKey: MainShell.navBarKey,
            spotlightPadding: 6,
          ),
        ],
        onDone: () {
          _tutorialEntry?.remove();
          _tutorialEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildFeatured(WidgetRef ref) {
    final featuredAsync = ref.watch(featuredRecipeProvider);
    return featuredAsync.when(
      loading: () => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (recipe) {
        if (recipe == null) return const SizedBox.shrink();
        return FeaturedCard(
          emoji: recipe.emoji,
          imageUrl: recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
          badgeText: '✦ HAFTANIN TARİFİ',
          title: recipe.name,
          meta:
              '⏱ ${recipe.duration}   ❤️ ${formatCount(recipe.likeCount)} beğeni',
          onTap: () => context.push('/recipe/${recipe.id}'),
        );
      },
    );
  }

  List<Recipe> _filterRecipes(List<Recipe> all) {
    if (_searchQuery.isEmpty) return all;
    final q = RecipeService.foldTurkish(_searchQuery);
    return all
        .where(
          (r) =>
              RecipeService.foldTurkish(r.name).contains(q) ||
              RecipeService.foldTurkish(r.type).contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesByCuisineProvider(_selectedCuisine));
    final allRecipes =
        ref.watch(allRecipesProvider).valueOrNull ?? const <Recipe>[];
    final cuisines = MockCuisines.orderedForRecipes(allRecipes);

    return Column(
      children: [
        AppHeader(
          actions: [
            HeaderIconButton(
              key: _bellKey,
              icon: Icons.notifications_outlined,
              // Rozet yalnızca gerçekten okunmamış bildirim varken görünür
              showBadge: ref.watch(unreadNotificationCountProvider) > 0,
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SearchBarWidget(
                  key: _searchKey,
                  hint: '$_selectedCuisine mutfağında tüm tariflerde ara...',
                  controller: _searchCtrl,
                  onChanged: (v) {
                    if (_searchQuery != v) setState(() => _searchQuery = v);
                  },
                ),
                const SizedBox(height: 12),
                CuisineChipRow(
                  key: _cuisineKey,
                  items: cuisines,
                  selectedIndex: cuisines.indexWhere(
                    (c) => c['name'] == _selectedCuisine,
                  ),
                  onSelected: (i) {
                    setState(() {
                      _selectedCuisine = cuisines[i]['name']!;
                      _searchQuery = '';
                      _randomizedFor = '';
                    });
                    // setState sonrasında clear — onChanged('') tetikler ama
                    // _searchQuery zaten '' olduğu için ikinci setState atlanır
                    if (_searchCtrl.text.isNotEmpty) _searchCtrl.clear();
                  },
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Öne Çıkan Tarif'),
                KeyedSubtree(key: _featuredKey, child: _buildFeatured(ref)),
                recipesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Hata: $e')),
                  ),
                  data: (all) {
                    // Arama aktifse tüm tarifler içinde filtrele
                    // Arama yoksa mutfak başına 1 kez karıştırılmış 10 tarif göster
                    if (_searchQuery.isEmpty &&
                        _randomizedFor != _selectedCuisine) {
                      final shuffled = List<Recipe>.from(all)..shuffle();
                      _randomRecipes = shuffled.take(10).toList();
                      _randomizedFor = _selectedCuisine;
                    }

                    final recipes = _searchQuery.isEmpty
                        ? _randomRecipes
                        : _filterRecipes(all);

                    final actionText = _searchQuery.isEmpty
                        ? '${all.length} tariften ${recipes.length} tanesi'
                        : '${recipes.length} sonuç';

                    return Column(
                      children: [
                        SectionHeader(
                          title: '$_selectedCuisine Mutfağı',
                          action: actionText,
                        ),
                        if (recipes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('Bu mutfakta henüz tarif yok'),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                // Spotlight yalnız ilk kartı hedefler
                                for (var i = 0; i < recipes.length; i++)
                                  KeyedSubtree(
                                    key: i == 0 ? _recipeKey : null,
                                    child: RecipeCard(
                                      recipe: recipes[i],
                                      onTap: () => context.push(
                                        '/recipe/${recipes[i].id}',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (_searchQuery.isEmpty && all.length > recipes.length)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => context.push(
                                  Uri(
                                    path: '/cuisine',
                                    queryParameters: {'name': _selectedCuisine},
                                  ).toString(),
                                ),
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Tümünü gör'),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CuisineRecipesScreen extends ConsumerStatefulWidget {
  final String cuisine;

  const CuisineRecipesScreen({super.key, required this.cuisine});

  @override
  ConsumerState<CuisineRecipesScreen> createState() =>
      _CuisineRecipesScreenState();
}

class _CuisineRecipesScreenState extends ConsumerState<CuisineRecipesScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _recipes = <Recipe>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextPage());
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await ref
          .read(recipeServiceProvider)
          .fetchCuisineRecipePage(
            widget.cuisine,
            pageSize: _pageSize,
            startAfter: _lastDocument,
          );
      if (!mounted) return;
      final existingIds = _recipes.map((recipe) => recipe.id).toSet();
      setState(() {
        _recipes.addAll(
          page.recipes.where((recipe) => existingIds.add(recipe.id)),
        );
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          title: '${widget.cuisine} Mutfağı',
          showBackButton: true,
          showProfileAvatar: false,
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_recipes.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recipes.isEmpty && _error != null) {
      return _PageMessage(
        icon: Icons.cloud_off_rounded,
        message: 'Tarifler yüklenemedi',
        actionLabel: 'Tekrar dene',
        onAction: _loadNextPage,
      );
    }
    if (_recipes.isEmpty) {
      return const _PageMessage(
        icon: Icons.restaurant_menu_rounded,
        message: 'Bu mutfakta henüz tarif yok',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _recipes.length + 1,
      itemBuilder: (context, index) {
        if (index < _recipes.length) {
          final recipe = _recipes[index];
          return RecipeCard(
            recipe: recipe,
            onTap: () => context.push('/recipe/${recipe.id}'),
          );
        }
        if (_error != null) {
          return Center(
            child: TextButton.icon(
              onPressed: _loadNextPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Sonraki 20 tarifi tekrar yükle'),
            ),
          );
        }
        if (_isLoading) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_hasMore) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Tüm tarifleri gördünüz')),
          );
        }
        return const SizedBox(height: 1);
      },
    );
  }
}

class _PageMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PageMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
