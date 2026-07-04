import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tutorial/tutorial_overlay.dart';
import '../../models/recipe.dart';
import '../../models/calendar_entry.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/recipe_provider.dart';
import 'widgets/ingredients_tab.dart';
import 'widgets/steps_tab.dart';
import 'widgets/comments_section.dart';
import 'widgets/notes_tab.dart';
import 'widgets/community_tab.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(cachedRecipeStreamProvider(recipeId));

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Hata: $e')),
      ),
      data: (recipe) {
        if (recipe == null) {
          return const Scaffold(
            body: Center(child: Text('Tarif bulunamadı')),
          );
        }
        return _RecipeDetailView(recipe: recipe);
      },
    );
  }
}

// Stateful — TabController'ı burada tutarak sekme sayısını tarif türüne göre ayarlarız.
class _RecipeDetailView extends ConsumerStatefulWidget {
  final Recipe recipe;
  const _RecipeDetailView({required this.recipe});

  @override
  ConsumerState<_RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends ConsumerState<_RecipeDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late final PageController _pageCtrl;
  int _currentPage = 0;

  // Tutorial GlobalKey'leri
  final _likeKey   = GlobalKey();
  final _tabBarKey = GlobalKey();
  OverlayEntry? _tutorialEntry;

  Recipe get recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: recipe.isOfficial ? 5 : 4,
      vsync: this,
    );
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final should = await TutorialService.shouldShow('tutorial_detail_v1');
    if (should && mounted) _insertTutorial();
  }

  void _insertTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        storageKey: 'tutorial_detail_v1',
        steps: [
          TutorialStep(
            emoji: '❤️',
            title: 'Tarifi Beğen',
            description:
                'Kalp ikonuna tıklayarak bu tarifi beğen. Beğeniler topluluk sıralamasını şekillendirir!',
            targetKey: _likeKey,
            spotlightPadding: 10,
          ),
          TutorialStep(
            emoji: '💬',
            title: 'Yorum Ekle',
            description:
                '"Yorumlar" sekmesine geçerek tarifi denedin mi? Deneyimini toplulukla paylaş.',
            targetKey: _tabBarKey,
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
  void didUpdateWidget(_RecipeDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.isOfficial != widget.recipe.isOfficial) {
      final prevIndex = _tabs.index;
      _tabs.dispose();
      _tabs = TabController(
        length: recipe.isOfficial ? 5 : 4,
        vsync: this,
        initialIndex: prevIndex.clamp(0, recipe.isOfficial ? 4 : 3),
      );
    }
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    _tabs.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxHeroHeight = screenHeight < 600 ? 180.0
        : screenHeight < 700 ? 220.0
        : 280.0;
    final targetHeroHeight = keyboardHeight > 0 ? 70.0 : maxHeroHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetHeroHeight),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, heroHeight, _) => Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHero(context, topPadding, heroHeight),
          ),
          Positioned(
            top: topPadding + heroHeight - 20,
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTabBar(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        IngredientsTab(ingredients: recipe.ingredients),
                        StepsTab(steps: recipe.steps),
                        CommentsSection(recipeId: recipe.id, isAuth: isAuth),
                        NotesTab(recipeId: recipe.id),
                        if (recipe.isOfficial)
                          CommunityTab(parentRecipeId: recipe.id),
                      ],
                    ),
                  ),
                  if (keyboardHeight == 0) _buildCalendarButton(context),
                ],
              ),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(
      BuildContext context, double topPadding, double heroHeight) {
    final userAsync = ref.watch(firebaseUserProvider);
    final user = userAsync.valueOrNull;
    final isAuth = user != null && !user.isAnonymous;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    final isLiked = isAuth
        ? ref
                .watch(isLikedProvider(
                    (recipeId: recipe.id, userId: user.uid)))
                .valueOrNull ??
            false
        : false;

    return GestureDetector(
      onTap: () => _showFullscreenImage(context),
      child: SizedBox(
        width: double.infinity,
        height: topPadding + heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (recipe.imageUrls.isNotEmpty)
              PageView.builder(
                controller: _pageCtrl,
                itemCount: recipe.imageUrls.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) => CachedNetworkImage(
                  imageUrl: recipe.imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (_, url) => _heroFallback(),
                  errorWidget: (_, url, err) => _heroFallback(),
                ),
              )
            else
              _heroFallback(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            // Fotoğraf sayfa göstergesi (birden fazla fotoğraf varsa)
            if (recipe.imageUrls.length > 1)
              Positioned(
                bottom: 72,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    recipe.imageUrls.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _currentPage == i ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: _currentPage == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: topPadding + 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.zoom_out_map,
                    color: Colors.white, size: 16),
              ),
            ),
            if (isAdmin)
              Positioned(
                top: topPadding + 46,
                right: 12,
                child: GestureDetector(
                  onTap: () => context.push(
                    '/recipe/${recipe.id}/edit',
                    extra: recipe,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            Positioned(
              bottom: 28,
              left: 14,
              right: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!recipe.isOfficial)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '👥 Topluluk Tarifi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 6)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _metaChip('⏱ ${recipe.duration}'),
                  const SizedBox(width: 6),
                  GestureDetector(
                    key: _likeKey,
                    onTap: () async {
                      if (!isAuth) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Beğenmek için giriş yapın'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      await ref
                          .read(recipeServiceProvider)
                          .toggleLike(recipe.id, user.uid);
                    },
                    child: _likeChip(isLiked, recipe.likeCount),
                  ),
                  const SizedBox(width: 6),
                  _metaChip(recipe.cuisine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC5F5D5), Color(0xFF7EE89C)],
        ),
      ),
      child: Center(
        child: Text(recipe.emoji, style: const TextStyle(fontSize: 100)),
      ),
    );
  }

  void _showFullscreenImage(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, anim2, anim3) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              if (recipe.imageUrls.isNotEmpty)
                PageView.builder(
                  controller: PageController(initialPage: _currentPage),
                  itemCount: recipe.imageUrls.length,
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: recipe.imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (_, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (_, url, err) => Center(
                      child: Text(recipe.emoji,
                          style: const TextStyle(fontSize: 120)),
                    ),
                  ),
                )
              else
                Center(
                  child: Text(recipe.emoji,
                      style: const TextStyle(fontSize: 200)),
                ),
              Positioned(
                top: 48,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border(
          top: BorderSide(color: context.palette.border, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showAddToCalendar(context),
          icon: const Icon(Icons.calendar_today_outlined, size: 17),
          label: const Text(
            'Takvime Ekle',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryText,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  Widget _likeChip(bool liked, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: liked
            ? Colors.red.withValues(alpha: 0.75)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            size: 13,
            color: Colors.white,
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              _fmt(count),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}B';
    return count.toString();
  }

  Widget _buildTabBar(BuildContext context) {
    return ClipRRect(
      key: _tabBarKey,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: ColoredBox(
        color: AppColors.primaryDarker,
        child: TabBar(
          controller: _tabs,
          isScrollable: recipe.isOfficial,
          tabAlignment: recipe.isOfficial
              ? TabAlignment.start
              : TabAlignment.fill,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.primary, width: 3),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'Malzemeler'),
            const Tab(text: 'Tarif'),
            const Tab(text: 'Yorumlar'),
            const Tab(text: 'Notlarım'),
            if (recipe.isOfficial) const Tab(text: 'Topluluk'),
          ],
        ),
      ),
    );
  }

  void _showAddToCalendar(BuildContext context) {
    DateTime selectedDay = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Takvime Ekle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gün seç:',
                style: TextStyle(
                    fontSize: 13, color: context.palette.textTertiary),
              ),
              const SizedBox(height: 8),
              CalendarDatePicker(
                initialDate: selectedDay,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                onDateChanged: (d) =>
                    setModalState(() => selectedDay = d),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final dateStr =
                        '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
                    try {
                      await ref
                          .read(calendarEntriesProvider.notifier)
                          .add(CalendarEntry(
                            date: dateStr,
                            recipeId: recipe.id,
                            recipeName: recipe.name,
                            recipeEmoji: recipe.emoji,
                          ));
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${recipe.name} takvime eklendi 📅'),
                            backgroundColor: AppColors.primaryDark,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Takvime eklenemedi: $e'),
                            backgroundColor: Colors.red[700],
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Ekle',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
