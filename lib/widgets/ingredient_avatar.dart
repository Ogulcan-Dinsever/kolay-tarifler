import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Malzeme için resim varsa resim, yoksa emoji gösterir.
class IngredientAvatar extends StatelessWidget {
  final String emoji;
  final String? imageUrl;
  final double size;

  const IngredientAvatar({
    super.key,
    required this.emoji,
    required this.imageUrl,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.palette.g50,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      clipBehavior: hasImage ? Clip.antiAlias : Clip.none,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Center(
                child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
              ),
              errorWidget: (_, _, _) => Center(
                child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
              ),
            )
          : Center(
              child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
            ),
    );
  }
}
