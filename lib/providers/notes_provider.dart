import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe_note.dart';
import '../services/notes_service.dart';

class RecipeNotesNotifier
    extends StateNotifier<AsyncValue<List<RecipeNote>>> {
  final String recipeId;
  final NotesService _service;

  RecipeNotesNotifier(this.recipeId, this._service)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await _service.getNotes(recipeId);
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(String text) async {
    if (text.trim().isEmpty) return;
    await _service.addNote(recipeId, text);
    await _load();
  }

  Future<void> delete(String noteId) async {
    await _service.deleteNote(recipeId, noteId);
    await _load();
  }
}

final recipeNotesProvider = StateNotifierProvider.family<
    RecipeNotesNotifier, AsyncValue<List<RecipeNote>>, String>(
  (ref, recipeId) => RecipeNotesNotifier(recipeId, NotesService()),
);
