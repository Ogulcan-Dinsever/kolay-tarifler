import 'dart:convert';

class RecipeNote {
  final String id;
  final String text;
  final DateTime createdAt;

  const RecipeNote({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  factory RecipeNote.fromJson(Map<String, dynamic> json) => RecipeNote(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static RecipeNote fromJsonString(String s) =>
      RecipeNote.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}
