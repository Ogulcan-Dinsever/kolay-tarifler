import 'package:hive/hive.dart';

part 'ingredient.g.dart';

@HiveType(typeId: 0)
enum IngredientCategory {
  @HiveField(0)
  vegetable,
  @HiveField(1)
  fruit,
  @HiveField(2)
  meat,
  @HiveField(3)
  seafood,
  @HiveField(4)
  dairy,
  @HiveField(5)
  grain,
  @HiveField(6)
  spice,
  @HiveField(7)
  oil,
  @HiveField(8)
  nut,
  @HiveField(9)
  egg,
  @HiveField(10)
  other,
}

extension IngredientCategoryLabel on IngredientCategory {
  String get label => switch (this) {
        IngredientCategory.vegetable => 'Sebze',
        IngredientCategory.fruit => 'Meyve',
        IngredientCategory.meat => 'Et & Tavuk',
        IngredientCategory.seafood => 'Deniz Ürünleri',
        IngredientCategory.dairy => 'Süt Ürünleri',
        IngredientCategory.grain => 'Tahıl & Bakliyat',
        IngredientCategory.spice => 'Baharat',
        IngredientCategory.oil => 'Yağ & Sos',
        IngredientCategory.nut => 'Kuruyemiş',
        IngredientCategory.egg => 'Yumurta',
        IngredientCategory.other => 'Diğer',
      };

  String get emoji => switch (this) {
        IngredientCategory.vegetable => '🥦',
        IngredientCategory.fruit => '🍎',
        IngredientCategory.meat => '🥩',
        IngredientCategory.seafood => '🐟',
        IngredientCategory.dairy => '🧀',
        IngredientCategory.grain => '🌾',
        IngredientCategory.spice => '🌶️',
        IngredientCategory.oil => '🫙',
        IngredientCategory.nut => '🥜',
        IngredientCategory.egg => '🥚',
        IngredientCategory.other => '🍽️',
      };
}

@HiveType(typeId: 3)
class Ingredient {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String emoji;
  @HiveField(3)
  final String imageUrl;
  @HiveField(4)
  final IngredientCategory category;

  const Ingredient({
    required this.id,
    required this.name,
    required this.emoji,
    this.imageUrl = '',
    required this.category,
  });

  factory Ingredient.fromFirestore(Map<String, dynamic> data, String id) {
    return Ingredient(
      id: id,
      name: data['name'] as String,
      emoji: data['emoji'] as String,
      imageUrl: data['imageUrl'] as String? ?? '',
      category: parseCategory(data['category'] as String?),
    );
  }

  /// Kategori değerini enum'a çevirir. Önce doğrudan enum adı (vegetable, meat…),
  /// tutmazsa Türkçe serbest metin karşılıkları (baharat, et, sos…) denenir.
  /// Böylece eski/elle yazılmış Türkçe kategoriler "Diğer"e düşmez.
  static IngredientCategory parseCategory(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (key.isEmpty) return IngredientCategory.other;
    for (final e in IngredientCategory.values) {
      if (e.name == key) return e;
    }
    return _trMap[key] ?? IngredientCategory.other;
  }

  static const Map<String, IngredientCategory> _trMap = {
    'sebze': IngredientCategory.vegetable,
    'yeşillik': IngredientCategory.vegetable,
    'yesillik': IngredientCategory.vegetable,
    'meyve': IngredientCategory.fruit,
    'et': IngredientCategory.meat,
    'tavuk': IngredientCategory.meat,
    'kırmızı et': IngredientCategory.meat,
    'kirmizi et': IngredientCategory.meat,
    'deniz': IngredientCategory.seafood,
    'deniz ürünleri': IngredientCategory.seafood,
    'deniz urunleri': IngredientCategory.seafood,
    'balık': IngredientCategory.seafood,
    'balik': IngredientCategory.seafood,
    'süt': IngredientCategory.dairy,
    'sut': IngredientCategory.dairy,
    'süt ürünleri': IngredientCategory.dairy,
    'sut urunleri': IngredientCategory.dairy,
    'peynir': IngredientCategory.dairy,
    'tahıl': IngredientCategory.grain,
    'tahil': IngredientCategory.grain,
    'bakliyat': IngredientCategory.grain,
    'baklagil': IngredientCategory.grain,
    'un': IngredientCategory.grain,
    'ekmek': IngredientCategory.grain,
    'yufka': IngredientCategory.grain,
    'hamur işi': IngredientCategory.grain,
    'hamur isi': IngredientCategory.grain,
    'baharat': IngredientCategory.spice,
    'ot': IngredientCategory.spice,
    'taze ot': IngredientCategory.spice,
    'yağ': IngredientCategory.oil,
    'yag': IngredientCategory.oil,
    'sos': IngredientCategory.oil,
    'kuruyemiş': IngredientCategory.nut,
    'kuruyemis': IngredientCategory.nut,
    'yumurta': IngredientCategory.egg,
    'sıvı': IngredientCategory.other,
    'sivi': IngredientCategory.other,
    'tatlandırıcı': IngredientCategory.other,
    'tatlandirici': IngredientCategory.other,
    'diğer': IngredientCategory.other,
    'diger': IngredientCategory.other,
  };

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'category': category.name,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ...toFirestore(),
      };
}
