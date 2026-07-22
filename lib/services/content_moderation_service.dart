class ContentModerationException implements Exception {
  const ContentModerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lightweight on-device moderation for all user-generated text.
///
/// The same policy is repeated in Cloud Functions as a server-side safety net.
/// This first pass prevents clearly abusive, sexual, threatening, spam, and
/// contact-harvesting content from being submitted in the normal app flow.
class ContentModerationService {
  const ContentModerationService._();

  static const _blockedTerms = <String>{
    'amk',
    'aq',
    'orospu',
    'siktir',
    'sikerim',
    'pic',
    'ibne',
    'geber',
    'oldururum',
    'tecavuz',
    'porn',
    'porno',
    'nude',
    'nudes',
    'onlyfans',
    'kill yourself',
    'kys',
    'fuck you',
  };

  static final RegExp _contactOrSpamPattern = RegExp(
    r'(https?://|www\.|t\.me/|wa\.me/|bit\.ly/|tinyurl\.com/|telegram|whatsapp).{0,80}(para|kazanc|bahis|casino|kupon|yatirim|takipci|reklam)',
    caseSensitive: false,
  );

  static final RegExp _excessiveRepeatPattern = RegExp(r'(.)\1{9,}');

  static void validate(String text, {String fieldName = 'İçerik'}) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return;

    for (final term in _blockedTerms) {
      if (_containsPhrase(normalized, term)) {
        throw ContentModerationException(
          '$fieldName topluluk kurallarına aykırı bir ifade içeriyor. '
          'Lütfen metni düzenleyip tekrar dene.',
        );
      }
    }

    if (_contactOrSpamPattern.hasMatch(normalized) ||
        _excessiveRepeatPattern.hasMatch(normalized)) {
      throw ContentModerationException(
        '$fieldName spam veya yanıltıcı yönlendirme içeriyor. '
        'Lütfen metni düzenleyip tekrar dene.',
      );
    }
  }

  static void validateAll(
    Iterable<String> values, {
    String fieldName = 'İçerik',
  }) {
    for (final value in values) {
      validate(value, fieldName: fieldName);
    }
  }

  static bool _containsPhrase(String normalized, String phrase) {
    final escaped = RegExp.escape(phrase);
    return RegExp('(^|\\s)$escaped(\\s|\$)').hasMatch(normalized);
  }

  static String normalize(String value) {
    const replacements = <String, String>{
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    var normalized = value.toLowerCase();
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9@:/._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
