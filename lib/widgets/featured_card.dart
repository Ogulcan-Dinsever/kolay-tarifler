import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';

/// "Haftanın Tarifi" için öne çıkan büyük kart.
class FeaturedCard extends StatelessWidget {
  final String emoji;
  final String badgeText;
  final String title;
  final String meta;
  final String? imageUrl;
  final VoidCallback? onTap;

  const FeaturedCard({
    super.key,
    required this.emoji,
    required this.badgeText,
    required this.title,
    required this.meta,
    this.imageUrl,
    this.onTap,
  });

  Widget _emojiBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC5F5D5), Color(0xFF7EE89C)],
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 58)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(context.rs(16), 0, context.rs(16), context.rs(14)),
        height: context.rh(150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC5F5D5), Color(0xFF7EE89C)],
          ),
        ),
        child: Stack(
          children: [
            // Arka plan: fotoğraf varsa göster, yoksa emoji+gradient
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _emojiBackground(),
                    errorWidget: (context, url, error) => _emojiBackground(),
                  ),
                ),
              )
            else
              Positioned.fill(child: _emojiBackground()),
            // Altta koyu gradient — yazıyı okunur yapar
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
