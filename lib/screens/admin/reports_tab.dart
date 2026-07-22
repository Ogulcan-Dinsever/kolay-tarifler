import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';

final _openReportsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).openReportsStream();
});

class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(_openReportsProvider);
    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Raporlar yüklenemedi: $error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Açık topluluk bildirimi yok.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) => _ReportCard(report: items[index]),
        );
      },
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = report['createdAt'] as Timestamp?;
    final type = report['targetType'] as String? ?? 'içerik';
    final canDelete = type == 'comment' || type == 'recipe';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_label(type)} • ${report['reason'] ?? 'Neden belirtilmedi'}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hedef kullanıcı: ${report['targetUserId'] ?? '-'}\n'
            'Hedef kimliği: ${report['targetId'] ?? '-'}\n'
            'Bildiren: ${report['reporterId'] ?? '-'}'
            '${createdAt == null ? '' : '\nTarih: ${createdAt.toDate()}'}',
            style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => ref
                    .read(adminServiceProvider)
                    .resolveReport(report['id'] as String),
                child: const Text('İncelendi'),
              ),
              if (canDelete)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => _confirmRemove(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('İçeriği Sil'),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                ),
                onPressed: () =>
                    _confirmSuspend(context, ref, removeContent: canDelete),
                icon: const Icon(Icons.person_off_outlined, size: 18),
                label: Text(
                  canDelete ? 'Sil ve Uzaklaştır' : 'Kullanıcıyı Uzaklaştır',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İçeriği sil'),
        content: const Text('Bildirilen içerik kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminServiceProvider).removeReportedContent(report);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İçerik silinemedi: $error')));
      }
    }
  }

  Future<void> _confirmSuspend(
    BuildContext context,
    WidgetRef ref, {
    required bool removeContent,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcıyı uzaklaştır'),
        content: Text(
          removeContent
              ? 'Bildirilen içerik silinecek ve kullanıcı yeni topluluk '
                    'içeriği paylaşamayacak.'
              : 'Kullanıcı yeni topluluk içeriği paylaşamayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade900),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Uzaklaştır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(adminServiceProvider)
          .suspendReportedUser(report, removeContent: removeContent);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı topluluktan uzaklaştırıldı.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı uzaklaştırılamadı: $error')),
        );
      }
    }
  }

  String _label(String type) {
    return switch (type) {
      'comment' => 'Yorum',
      'recipe' => 'Tarif',
      'user' => 'Kullanıcı',
      _ => 'İçerik',
    };
  }
}
