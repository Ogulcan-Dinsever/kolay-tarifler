import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';

/// Yatay kaydırılabilir mutfak chip listesi.
class CuisineChipRow extends StatelessWidget {
  final List<Map<String, String>> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CuisineChipRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isActive = selectedIndex == i;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : context.palette.g50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.primary : context.palette.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(items[i]['flag']!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    items[i]['name']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? AppColors.primaryText
                          : context.palette.textPrimary,
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
