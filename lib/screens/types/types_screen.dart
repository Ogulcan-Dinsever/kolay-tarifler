import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/section_header.dart';

class TypesScreen extends ConsumerStatefulWidget {
  const TypesScreen({super.key});

  @override
  ConsumerState<TypesScreen> createState() => _TypesScreenState();
}

class _TypesScreenState extends ConsumerState<TypesScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allRecipesProvider).valueOrNull ?? [];
    final recipes = _selectedType == null
        ? <Recipe>[]
        : all.where((r) => r.type == _selectedType).toList();

    return Column(
      children: [
        const AppHeader(
          titleWidget: Text(
            'Türe Göre Tarif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF063B16),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildTypeGrid(context),
                const SizedBox(height: 24),
                if (_selectedType != null) ...[
                  SectionHeader(
                    title: '$_selectedType Tarifleri',
                    action: '${recipes.length} tarif',
                  ),
                  if (recipes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Bu türde henüz tarif yok',
                          style: TextStyle(
                              color: context.palette.textTertiary),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: recipes
                            .map((recipe) => RecipeCard(
                                  recipe: recipe,
                                  onTap: () =>
                                      context.push('/recipe/${recipe.id}'),
                                ))
                            .toList(),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'Bir tür seç',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeGrid(BuildContext context) {
    final cols = context.isTinyScreen ? 2 : 3;
    final spacing = context.rs(10);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(16)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 1,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: RecipeTypes.all.length,
        itemBuilder: (context, i) {
          final type = RecipeTypes.all[i];
          final isSelected = _selectedType == type['name'];
          return GestureDetector(
            onTap: () => setState(() => _selectedType = type['name']),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1DD94C)
                    : context.palette.g50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1DD94C)
                      : context.palette.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    type['emoji']!,
                    style: TextStyle(fontSize: context.sp(28)),
                  ),
                  SizedBox(height: context.rs(6)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rs(4)),
                    child: Text(
                      type['name']!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.sp(11),
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF063B16)
                            : context.palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
