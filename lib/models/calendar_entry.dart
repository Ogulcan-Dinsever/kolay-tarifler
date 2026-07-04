/// Yerel (telefon) takvim girişi.
/// shared_preferences'ta JSON olarak saklanır.
class CalendarEntry {
  final String date;      // 'yyyy-MM-dd' formatı
  final String recipeId;
  final String recipeName;
  final String recipeEmoji;

  const CalendarEntry({
    required this.date,
    required this.recipeId,
    required this.recipeName,
    required this.recipeEmoji,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    return CalendarEntry(
      date: json['date'] as String,
      recipeId: json['recipeId'] as String,
      recipeName: json['recipeName'] as String,
      recipeEmoji: json['recipeEmoji'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'recipeId': recipeId,
        'recipeName': recipeName,
        'recipeEmoji': recipeEmoji,
      };
}
