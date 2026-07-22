import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/community_safety_provider.dart';

const _termsUrl = 'https://kolaytarifler-37c45.web.app/terms';

Future<bool> ensureCommunityTermsAccepted(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final service = ref.read(communitySafetyServiceProvider);
  if (await service.hasAcceptedTerms(userId)) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Topluluk kuralları'),
      content: const Text(
        'Tarif veya yorum paylaşmadan önce Kullanım ve Topluluk '
        'Koşulları’nı kabul etmen gerekiyor. Uygunsuz içerik ve kötüye '
        'kullanıma sıfır tolerans uygulanır. İçerikler otomatik olarak '
        'filtrelenebilir; bildirimler 24 saat içinde incelenerek içerik '
        'kaldırılabilir ve hesaplar askıya alınabilir.',
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(_termsUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Koşulları Oku'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Kabul Ediyorum'),
        ),
      ],
    ),
  );

  if (accepted != true) return false;
  await service.acceptTerms(userId);
  return true;
}

Future<String?> showReportReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Bildirme nedeni'),
      children: [
        for (final reason in const [
          'Spam veya reklam',
          'Taciz ya da nefret söylemi',
          'Uygunsuz veya tehlikeli içerik',
          'Telif ya da gizlilik ihlali',
          'Diğer',
        ])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, reason),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(reason),
            ),
          ),
      ],
    ),
  );
}
