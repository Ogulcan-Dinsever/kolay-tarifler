import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/recipe_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final results = _query.isEmpty
        ? <Recipe>[]
        : all.where((r) {
            final q = _query.toLowerCase();
            return r.name.toLowerCase().contains(q) ||
                r.description.toLowerCase().contains(q) ||
                r.type.toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        const AppHeader(
          titleWidget: Text(
            'Ara',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF063B16),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tarif adı ara...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.palette.textTertiary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: context.palette.textTertiary,
                    ),
                    filled: true,
                    fillColor: context.palette.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: context.palette.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: context.palette.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF1DD94C), width: 2),
                    ),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: context.palette.textTertiary,
                            ),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: _query.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔍',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'Tarif adını yazarak arayın',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('❌',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  'Sonuç bulunamadı',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: results
                                  .map((recipe) => RecipeCard(
                                        recipe: recipe,
                                        onTap: () => context
                                            .push('/recipe/${recipe.id}'),
                                      ))
                                  .toList(),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
