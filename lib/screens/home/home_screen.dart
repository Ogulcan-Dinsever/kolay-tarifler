import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/tutorial/tutorial_overlay.dart';
import '../../core/utils/format.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
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
  final _searchKey    = GlobalKey();
  final _cuisineKey   = GlobalKey();
  final _recipeKey    = GlobalKey();

  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final should = await TutorialService.shouldShow('tutorial_home_v1');
    if (!should || !mounted) return;
    // Tarif listesinin yüklenmesi için bekle (recipeKey henüz render edilmedi)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) _insertTutorial();
  }

  void _insertTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        storageKey: 'tutorial_home_v1',
        steps: [
          TutorialStep(
            emoji: '🔍',
            title: 'Tarif Ara',
            description:
                'Aradığın yemeği buraya yaz — ad, tür veya mutfağa göre anında filtrele.',
            targetKey: _searchKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🌍',
            title: 'Mutfak Seç',
            description:
                'Türk, İtalyan, Japon… Chip\'lere tıklayarak farklı mutfakları keşfet.',
            targetKey: _cuisineKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🍽️',
            title: 'Tariflere Göz At',
            description:
                'Bir tarif kartına tıklayarak malzemeleri, adımları ve yorumları gör. Beğendiğin tarifleri kalp ikonuyla işaretle!',
            targetKey: _recipeKey,
            spotlightPadding: 12,
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
          meta: '⏱ ${recipe.duration}   ❤️ ${formatCount(recipe.likeCount)} beğeni',
          onTap: () => context.push('/recipe/${recipe.id}'),
        );
      },
    );
  }

  List<Recipe> _filterRecipes(List<Recipe> all) {
    if (_searchQuery.isEmpty) return all;
    final lower = _searchQuery.toLowerCase();
    return all
        .where((r) =>
            r.name.toLowerCase().contains(lower) ||
            r.type.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesByCuisineProvider(_selectedCuisine));

    return Column(
      children: [
        AppHeader(
          actions: [
            HeaderIconButton(
              icon: Icons.notifications_outlined,
              showBadge: true,
              onTap: () {},
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
                  items: MockCuisines.all,
                  selectedIndex: MockCuisines.all
                      .indexWhere((c) => c['name'] == _selectedCuisine),
                  onSelected: (i) {
                    setState(() {
                      _selectedCuisine = MockCuisines.all[i]['name']!;
                      _searchQuery = '';
                      _randomizedFor = '';
                    });
                    // setState sonrasında clear — onChanged('') tetikler ama
                    // _searchQuery zaten '' olduğu için ikinci setState atlanır
                    if (_searchCtrl.text.isNotEmpty) _searchCtrl.clear();
                  },
                ),
                const SizedBox(height: 12),
                const SectionHeader(
                  title: 'Öne Çıkan Tarif',
                ),
                _buildFeatured(ref),
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
                        ? '${all.length} tariften 10 tanesi'
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              key: _recipeKey,
                              children: recipes
                                  .map((recipe) => RecipeCard(
                                        recipe: recipe,
                                        onTap: () => context
                                            .push('/recipe/${recipe.id}'),
                                      ))
                                  .toList(),
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
