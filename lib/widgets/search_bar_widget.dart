import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const SearchBarWidget({
    super.key,
    this.hint = 'Tarif ara...',
    this.controller,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: onChanged == null && onTap != null,
        style: TextStyle(fontSize: 13, color: context.palette.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: context.palette.textTertiary),
          prefixIcon: Icon(Icons.search, size: 18, color: context.palette.textTertiary),
          suffixIcon: controller != null && (controller!.text.isNotEmpty)
              ? GestureDetector(
                  onTap: () {
                    controller!.clear();
                    onChanged?.call('');
                  },
                  child: Icon(Icons.close, size: 16, color: context.palette.textTertiary),
                )
              : null,
          filled: true,
          fillColor: context.palette.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.palette.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.palette.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
