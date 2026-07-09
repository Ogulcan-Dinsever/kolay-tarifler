// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 4;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      cuisine: fields[3] as String,
      type: fields[4] as String,
      duration: fields[5] as String,
      emoji: fields[6] as String,
      imageUrls: (fields[7] as List).cast<String>(),
      ingredients: (fields[8] as List).cast<RecipeIngredient>(),
      steps: (fields[9] as List).cast<RecipeStep>(),
      tags: (fields[10] as List).cast<String>(),
      officialLikeCount: fields[11] as int,
      communityLikeCount: fields[12] as int,
      likeCount: fields[13] as int,
      authorId: fields[14] as String,
      authorName: fields[15] as String,
      isOfficial: fields[16] as bool,
      parentRecipeId: fields[17] as String?,
      commentCount: fields[18] as int,
      createdAt: fields[19] as DateTime,
      modifiedAt: fields[20] as DateTime?,
      servings: fields[21] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.cuisine)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.emoji)
      ..writeByte(7)
      ..write(obj.imageUrls)
      ..writeByte(8)
      ..write(obj.ingredients)
      ..writeByte(9)
      ..write(obj.steps)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.officialLikeCount)
      ..writeByte(12)
      ..write(obj.communityLikeCount)
      ..writeByte(13)
      ..write(obj.likeCount)
      ..writeByte(14)
      ..write(obj.authorId)
      ..writeByte(15)
      ..write(obj.authorName)
      ..writeByte(16)
      ..write(obj.isOfficial)
      ..writeByte(17)
      ..write(obj.parentRecipeId)
      ..writeByte(18)
      ..write(obj.commentCount)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.modifiedAt)
      ..writeByte(21)
      ..write(obj.servings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
