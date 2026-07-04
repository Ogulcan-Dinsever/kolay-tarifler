import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/notes_provider.dart';

class NotesTab extends ConsumerStatefulWidget {
  final String recipeId;
  const NotesTab({super.key, required this.recipeId});

  @override
  ConsumerState<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<NotesTab> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _writing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ref.read(recipeNotesProvider(widget.recipeId).notifier).add(text);
      _ctrl.clear();
      _focusNode.unfocus();
      setState(() => _writing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not kaydedilemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(recipeNotesProvider(widget.recipeId));

    return Column(
      children: [
        Expanded(
          child: notesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (notes) => notes.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: notes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _NoteCard(
                          note: notes[i],
                          onDelete: () => ref
                              .read(recipeNotesProvider(widget.recipeId)
                                  .notifier)
                              .delete(notes[i].id),
                        ),
                  ),
          ),
        ),
        _buildInput(context),
      ],
    );
  }

  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📝', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz not yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yemeği yaptıktan sonra kendin için\nnotlar ekleyebilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textTertiary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        border: Border(
            top: BorderSide(color: context.palette.border, width: 1)),
      ),
      child: _writing
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  autofocus: true,
                  style: TextStyle(
                      fontSize: 14, color: context.palette.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Örn: 3 tatlı kaşığı un fazlaydı, bir sonraki seferinde 2 kaşık kullan...',
                    hintStyle: TextStyle(
                        fontSize: 13, color: context.palette.textTertiary),
                    filled: true,
                    fillColor: context.palette.g50,
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _ctrl.clear();
                          _focusNode.unfocus();
                          setState(() => _writing = false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.palette.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('İptal',
                            style: TextStyle(
                                color: context.palette.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Kaydet',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _writing = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Not Ekle',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final dynamic note;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = note.createdAt as DateTime;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textTertiary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red[300]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note.text as String,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notu Sil'),
        content: const Text('Bu not silinecek. Emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Sil',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
