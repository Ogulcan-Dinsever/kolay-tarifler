// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngredientAdapter extends TypeAdapter<Ingredient> {
  @override
  final int typeId = 3;

  @override
  Ingredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ingredient(
      id: fields[0] as String,
      name: fields[1] as String,
      emoji: fields[2] as String,
      imageUrl: fields[3] as String,
      category: fields[4] as IngredientCategory,
    );
  }

  @override
  void write(BinaryWriter writer, Ingredient obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IngredientCategoryAdapter extends TypeAdapter<IngredientCategory> {
  @override
  final int typeId = 0;

  @override
  IngredientCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IngredientCategory.vegetable;
      case 1:
        return IngredientCategory.fruit;
      case 2:
        return IngredientCategory.meat;
      case 3:
        return IngredientCategory.seafood;
      case 4:
        return IngredientCategory.dairy;
      case 5:
        return IngredientCategory.grain;
      case 6:
        return IngredientCategory.spice;
      case 7:
        return IngredientCategory.oil;
      case 8:
        return IngredientCategory.nut;
      case 9:
        return IngredientCategory.egg;
      case 10:
        return IngredientCategory.other;
      default:
        return IngredientCategory.vegetable;
    }
  }

  @override
  void write(BinaryWriter writer, IngredientCategory obj) {
    switch (obj) {
      case IngredientCategory.vegetable:
        writer.writeByte(0);
        break;
      case IngredientCategory.fruit:
        writer.writeByte(1);
        break;
      case IngredientCategory.meat:
        writer.writeByte(2);
        break;
      case IngredientCategory.seafood:
        writer.writeByte(3);
        break;
      case IngredientCategory.dairy:
        writer.writeByte(4);
        break;
      case IngredientCategory.grain:
        writer.writeByte(5);
        break;
      case IngredientCategory.spice:
        writer.writeByte(6);
        break;
      case IngredientCategory.oil:
        writer.writeByte(7);
        break;
      case IngredientCategory.nut:
        writer.writeByte(8);
        break;
      case IngredientCategory.egg:
        writer.writeByte(9);
        break;
      case IngredientCategory.other:
        writer.writeByte(10);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
