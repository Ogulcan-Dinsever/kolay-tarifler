import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';

/// "Öne Çıkan Tarif" gibi bölüm başlıkları için ortak widget.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDarker,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
