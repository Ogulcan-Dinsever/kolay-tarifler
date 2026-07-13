import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tutorial/tutorial_overlay.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/recipe_ingredient_ids.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../providers/ingredient_selection_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/recipe_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/section_header.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  // Seçimler ve açık kategori provider'da: ekran yeniden oluşsa da
  // (sekme değişimi, tarif detayına gidip dönme) durum korunur.
  Set<String> get _selectedIngredients =>
      ref.watch(selectedIngredientsProvider);

  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Tutorial
  final _selectKey = GlobalKey();
  OverlayEntry? _tutorialEntry;

  /// 757 tarifin malzeme listeleri üzerinden çıkarılan kullanım sıklığı
  /// (scripts/analyze_ingredient_usage.js) — en çok kullanılan kategori üstte.
  static const _categoryOrder = [
    IngredientCategory.spice,
    IngredientCategory.vegetable,
    IngredientCategory.oil,
    IngredientCategory.other,
    IngredientCategory.grain,
    IngredientCategory.dairy,
    IngredientCategory.meat,
    IngredientCategory.fruit,
    IngredientCategory.egg,
    IngredientCategory.nut,
    IngredientCategory.seafood,
  ];

  /// Türk alfabesi sırası — toLowerCase öncesi I→ı, İ→i düzeltmesi yapılır.
  /// q/w/x Türk alfabesinde yok ama malzeme adlarında geçebilir (Wasabi);
  /// en yakın harfin yanına yerleştirildi ki listenin başına düşmesinler.
  static const _trAlphabet = 'aâbcçdefgğhıiîjklmnoöpqrsştuüûvwxyz';

  static String _trFold(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  static int _trCompare(String a, String b) {
    final fa = _trFold(a);
    final fb = _trFold(b);
    final len = fa.length < fb.length ? fa.length : fb.length;
    for (var i = 0; i < len; i++) {
      var ra = _trAlphabet.indexOf(fa[i]);
      var rb = _trAlphabet.indexOf(fb[i]);
      // Alfabede olmayan karakter (rakam, boşluk vs.) kod sırasıyla, harflerden önce
      if (ra == -1) ra = fa.codeUnitAt(i) - 1000;
      if (rb == -1) rb = fb.codeUnitAt(i) - 1000;
      if (ra != rb) return ra - rb;
    }
    return fa.length - fb.length;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final should = await TutorialService.shouldShow('tutorial_ingredients_v1');
    if (!should || !mounted) return;
    // Malzeme listesinin yüklenmesini bekle
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _insertTutorial();
  }

  void _insertTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        storageKey: 'tutorial_ingredients_v1',
        steps: [
          TutorialStep(
            emoji: '🥕',
            title: 'Dolabında Ne Varsa',
            description:
                'Kategorilere dokunarak aç, evdeki malzemeleri işaretle. Aradığını üstteki kutuya yazarak da anında bulabilirsin.',
            targetKey: _selectKey,
            spotlightPadding: 8,
          ),
          TutorialStep(
            emoji: '🎯',
            title: 'Eşleşen Tarifler En Altta',
            description:
                'Sayfanın EN ALTINDA tüm malzemesi sende olan tarifler "Eşleşen Tarifler"de listelenir; 1-3 malzemesi eksik olanlar "Birkaç Malzeme Eksik" önerilerinde. Aşağı kaydırmayı unutma!',
            targetKey: _selectKey,
            spotlightPadding: 8,
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

  /// Tam eşleşme: tarifin TÜM malzemeleri seçili.
  /// Yakın eşleşme: 1-3 malzemesi eksik (ve en az bir seçili malzeme içeriyor).
  /// Her iki listede Türk mutfağı önce gelir.
  ({List<Recipe> exact, List<(Recipe, int)> near}) _matchRecipes(
    List<Recipe> all,
    List<Ingredient> ingredients,
  ) {
    if (_selectedIngredients.isEmpty) {
      return (exact: <Recipe>[], near: <(Recipe, int)>[]);
    }
    final exact = <Recipe>[];
    final near = <(Recipe, int)>[];
    for (final recipe in all) {
      final ids = resolvedRecipeIngredientIds(recipe, ingredients);
      if (ids.isEmpty) continue;
      final missing = ids.difference(_selectedIngredients).length;
      if (missing == 0) {
        exact.add(recipe);
      } else if (missing <= 3 &&
          ids.intersection(_selectedIngredients).isNotEmpty) {
        near.add((recipe, missing));
      }
    }
    int turkFirst(Recipe a, Recipe b) {
      final ta = a.cuisine == 'Türk' ? 0 : 1;
      final tb = b.cuisine == 'Türk' ? 0 : 1;
      return ta - tb;
    }

    exact.sort((a, b) {
      final t = turkFirst(a, b);
      return t != 0 ? t : _trCompare(a.name, b.name);
    });
    near.sort((a, b) {
      final t = turkFirst(a.$1, b.$1);
      if (t != 0) return t;
      final m = a.$2.compareTo(b.$2);
      return m != 0 ? m : _trCompare(a.$1.name, b.$1.name);
    });
    return (exact: exact, near: near);
  }

  void _toggleIngredient(String id) {
    final current = ref.read(selectedIngredientsProvider);
    ref.read(selectedIngredientsProvider.notifier).state = current.contains(id)
        ? ({...current}..remove(id))
        : {...current, id};
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider).valueOrNull ?? [];
    final allRecipes = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final matches = _matchRecipes(allRecipes, ingredients);

    final grouped = <IngredientCategory, List<Ingredient>>{};
    for (final ing in ingredients) {
      grouped.putIfAbsent(ing.category, () => []).add(ing);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => _trCompare(a.name, b.name));
    }
    // Kullanım sıklığı sırasına göre, yalnız dolu kategoriler
    final orderedCategories = _categoryOrder
        .where((c) => grouped.containsKey(c))
        .toList();

    final byId = {for (final ing in ingredients) ing.id: ing};
    final searching = _searchQuery.trim().isNotEmpty;

    return Column(
      children: [
        AppHeader(
          titleWidget: Text(
            'Malzemeye Göre Tarif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        // Arama + seçili şerit sabit: liste kaydırılsa da görünür kalır
        const SizedBox(height: 8),
        SearchBarWidget(
          hint: 'Malzeme ara... (ör. domates)',
          controller: _searchCtrl,
          onChanged: (v) {
            if (_searchQuery != v) setState(() => _searchQuery = v);
          },
        ),
        if (_selectedIngredients.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSelectedStrip(context, byId),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyedSubtree(
                  key: _selectKey,
                  child: SectionHeader(
                    title: 'Malzemeleri Seç',
                    action: _selectedIngredients.isNotEmpty
                        ? '${_selectedIngredients.length} seçili'
                        : null,
                  ),
                ),
                if (searching)
                  _buildSearchResults(context, ingredients)
                else
                  ...orderedCategories.map(
                    (c) => _buildCategorySection(context, c, grouped[c]!),
                  ),
                if (_selectedIngredients.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Eşleşen Tarifler',
                    action: '${matches.exact.length} tarif',
                  ),
                  if (matches.exact.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Center(
                        child: Text(
                          matches.near.isEmpty
                              ? 'Bu malzemelerle yapılabilecek tarif yok'
                              : 'Seçtiklerinle birebir yapılabilecek tarif yok — aşağıdaki önerilere göz at 👇',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.palette.textTertiary),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: matches.exact
                            .map(
                              (recipe) => RecipeCard(
                                recipe: recipe,
                                onTap: () =>
                                    context.push('/recipe/${recipe.id}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (matches.near.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionHeader(
                      title: 'Birkaç Malzeme Eksik',
                      action: '${matches.near.length} tarif',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: matches.near
                            .map(
                              (entry) => RecipeCard(
                                recipe: entry.$1,
                                badgeText: '${entry.$2} Malzeme Eksik',
                                onTap: () =>
                                    context.push('/recipe/${entry.$1.id}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Seçilen malzemeler — yatay kayan şerit, dokununca kaldırır.
  Widget _buildSelectedStrip(
    BuildContext context,
    Map<String, Ingredient> byId,
  ) {
    final selected =
        _selectedIngredients
            .map((id) => byId[id])
            .whereType<Ingredient>()
            .toList()
          ..sort((a, b) => _trCompare(a.name, b.name));
    return SizedBox(
      height: context.rs(44),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: selected.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ing = selected[index];
          return GestureDetector(
            onTap: () => _toggleIngredient(ing.id),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.rs(10)),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(ing.emoji, style: TextStyle(fontSize: context.sp(13))),
                  SizedBox(width: context.rs(5)),
                  Text(
                    ing.name,
                    style: TextStyle(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                  SizedBox(width: context.rs(5)),
                  Icon(
                    Icons.close_rounded,
                    size: context.rs(14),
                    color: AppColors.primaryText,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Arama sonuçları — kategorilerden bağımsız düz liste (Türkçe katlamalı eşleşme).
  Widget _buildSearchResults(
    BuildContext context,
    List<Ingredient> ingredients,
  ) {
    final q = RecipeService.foldTurkish(_searchQuery.trim());
    final results =
        ingredients
            .where((ing) => RecipeService.foldTurkish(ing.name).contains(q))
            .toList()
          ..sort((a, b) => _trCompare(a.name, b.name));

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Aramana uyan malzeme yok',
            style: TextStyle(color: context.palette.textTertiary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: results
            .map((ing) => _buildIngredientChip(context, ing))
            .toList(),
      ),
    );
  }

  /// Akordeon kategori başlığı + açıksa malzeme chip'leri.
  Widget _buildCategorySection(
    BuildContext context,
    IngredientCategory category,
    List<Ingredient> ingredients,
  ) {
    final isExpanded =
        ref.watch(expandedIngredientCategoryProvider) == category;
    final selectedCount = ingredients
        .where((ing) => _selectedIngredients.contains(ing.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: () =>
                ref.read(expandedIngredientCategoryProvider.notifier).state =
                    isExpanded ? null : category,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rs(14),
                vertical: context.rs(12),
              ),
              decoration: BoxDecoration(
                color: context.palette.g50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isExpanded
                      ? AppColors.primary
                      : context.palette.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    category.emoji,
                    style: TextStyle(fontSize: context.sp(16)),
                  ),
                  SizedBox(width: context.rs(8)),
                  Expanded(
                    child: Text(
                      category.label,
                      style: TextStyle(
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rs(8),
                        vertical: context.rs(2),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$selectedCount',
                        style: TextStyle(
                          fontSize: context.sp(11),
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rs(8)),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: context.rs(22),
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ingredients
                        .map((ing) => _buildIngredientChip(context, ing))
                        .toList(),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _emojiBox(BuildContext context, String emoji) => SizedBox(
    width: context.rs(26),
    height: context.rs(26),
    child: Center(
      child: Text(emoji, style: TextStyle(fontSize: context.sp(15))),
    ),
  );

  Widget _buildIngredientChip(BuildContext context, Ingredient ing) {
    final isSelected = _selectedIngredients.contains(ing.id);
    final imgSize = context.rs(26);
    return GestureDetector(
      onTap: () => _toggleIngredient(ing.id),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rs(10),
          vertical: context.rs(7),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.palette.g50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ing.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ing.imageUrl,
                      width: imgSize,
                      height: imgSize,
                      fit: BoxFit.cover,
                      placeholder: (_, url) => _emojiBox(context, ing.emoji),
                      errorWidget: (_, url, err) =>
                          _emojiBox(context, ing.emoji),
                    )
                  : _emojiBox(context, ing.emoji),
            ),
            SizedBox(width: context.rs(5)),
            Text(
              ing.name,
              style: TextStyle(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primaryText
                    : context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
