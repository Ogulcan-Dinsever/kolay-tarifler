import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient.dart';

/// Malzeme ekranındaki seçimler. Ekran state'i yerine provider'da tutulur;
/// tarif detayına gidip dönünce veya sekme değişince seçimler kaybolmaz.
final selectedIngredientsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Akordeonda açık olan kategori (tek seferde bir tane).
/// Varsayılan: kullanım analizine göre ilk sıradaki Baharat.
final expandedIngredientCategoryProvider =
    StateProvider<IngredientCategory?>((ref) => IngredientCategory.spice);
