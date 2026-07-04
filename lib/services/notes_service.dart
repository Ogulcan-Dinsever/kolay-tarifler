import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_note.dart';

class NotesService {
  static const _prefix = 'recipe_notes_';

  Future<List<RecipeNote>> getNotes(String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$recipeId') ?? [];
    return list.map(RecipeNote.fromJsonString).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addNote(String recipeId, String text) async {
    final notes = await getNotes(recipeId);
    notes.insert(
      0,
      RecipeNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await _save(recipeId, notes);
  }

  Future<void> deleteNote(String recipeId, String noteId) async {
    final notes = await getNotes(recipeId);
    notes.removeWhere((n) => n.id == noteId);
    await _save(recipeId, notes);
  }

  Future<void> _save(String recipeId, List<RecipeNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '$_prefix$recipeId',
      notes.map((n) => n.toJsonString()).toList(),
    );
  }
}
