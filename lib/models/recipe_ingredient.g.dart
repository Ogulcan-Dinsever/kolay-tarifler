// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_ingredient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeIngredientAdapter extends TypeAdapter<RecipeIngredient> {
  @override
  final int typeId = 1;

  @override
  RecipeIngredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredient(
      ingredientId: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as String,
      emoji: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredient obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.ingredientId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.emoji);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
