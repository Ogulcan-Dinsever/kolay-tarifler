import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/comment.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/recipe_provider.dart';

class CommentsSection extends ConsumerStatefulWidget {
  final String recipeId;
  final bool isAuth;

  const CommentsSection({
    super.key,
    required this.recipeId,
    required this.isAuth,
  });

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı bilgisi yüklenemedi, lütfen tekrar deneyin'),
          ),
        );
      }
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(recipeServiceProvider).addComment(
            Comment(
              id: '',
              recipeId: widget.recipeId,
              userId: user.id,
              userDisplayName: user.displayName,
              userAvatarUrl: user.avatarUrl,
              text: text,
              createdAt: DateTime.now(),
            ),
          );
      if (mounted) _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.recipeId));

    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (comments) {
              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💬',
                          style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text(
                        'Henüz yorum yok. İlk yorumu sen yaz!',
                        style: TextStyle(
                            color: context.palette.textTertiary,
                            fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.palette.border),
                itemBuilder: (_, i) => _CommentTile(comment: comments[i]),
              );
            },
          ),
        ),
        if (widget.isAuth) _buildInput(context),
        if (!widget.isAuth)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Yorum yapmak için giriş yapmalısın',
              style: TextStyle(
                  fontSize: 13, color: context.palette.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border(
            top: BorderSide(color: context.palette.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(
                  fontSize: 13, color: context.palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Yorum yaz...',
                hintStyle: TextStyle(
                    fontSize: 13, color: context.palette.textTertiary),
                filled: true,
                fillColor: context.palette.g50,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: context.palette.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: context.palette.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: !_sending,
            label: 'Yorum gönder',
            child: GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryText),
                      )
                    : const Icon(Icons.send,
                        size: 18, color: AppColors.primaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            backgroundImage: comment.userAvatarUrl != null
                ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                : null,
            child: comment.userAvatarUrl == null
                ? Text(
                    comment.userDisplayName.isNotEmpty
                        ? comment.userDisplayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userDisplayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: context.palette.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: context.palette.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays < 1) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }
}
