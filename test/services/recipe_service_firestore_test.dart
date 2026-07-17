import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolay_tarifler/models/comment.dart';
import 'package:kolay_tarifler/models/pending_recipe.dart';
import 'package:kolay_tarifler/models/recipe.dart';
import 'package:kolay_tarifler/services/pending_recipe_service.dart';
import 'package:kolay_tarifler/services/recipe_service.dart';

Recipe _recipe({
  required String id,
  String? parentRecipeId,
  int commentCount = 0,
}) {
  return Recipe(
    id: id,
    name: 'Tarif $id',
    description: 'Açıklama',
    cuisine: 'Türk',
    type: 'Ana Yemek',
    duration: '30 dk',
    emoji: '🍲',
    authorId: 'author-1',
    authorName: 'Test Kullanıcısı',
    isOfficial: parentRecipeId == null,
    parentRecipeId: parentRecipeId,
    commentCount: commentCount,
    createdAt: DateTime.utc(2026, 7, 17),
  );
}

Future<void> _saveRecipe(FakeFirebaseFirestore firestore, Recipe recipe) {
  return firestore
      .collection(
        recipe.isVariation ? RecipeService.variationsCollection : 'recipes',
      )
      .doc(recipe.id)
      .set(recipe.toFirestore());
}

void main() {
  group('RecipeService Firestore flows', () {
    late FakeFirebaseFirestore firestore;
    late RecipeService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = RecipeService(firestore: firestore);
    });

    test('creates only a first-level variation under a main recipe', () async {
      await _saveRecipe(firestore, _recipe(id: 'main'));

      final variationId = await service.createSubRecipe(
        parentRecipeId: 'main',
        authorId: 'user-2',
        authorName: 'Ayşe',
        name: 'Acılı yorum',
        description: 'Açıklama',
        emoji: '🌶️',
        duration: '20 dk',
        cuisine: 'Türk',
        ingredients: const [],
        steps: const [],
      );

      final created = await service.fetchById(variationId);
      expect(created, isNotNull);
      expect(created!.parentRecipeId, 'main');
      expect(created.isVariation, isTrue);
      expect(
        (await firestore.collection('recipes').doc(variationId).get()).exists,
        isFalse,
      );
      expect(
        (await firestore
                .collection(RecipeService.variationsCollection)
                .doc(variationId)
                .get())
            .exists,
        isTrue,
      );
      expect(created.authorName, 'Ayşe');

      await expectLater(
        service.createSubRecipe(
          parentRecipeId: variationId,
          authorId: 'user-3',
          authorName: 'Mehmet',
          name: 'İç içe varyasyon',
          description: 'Reddedilmeli',
          emoji: '🍲',
          duration: '25 dk',
          cuisine: 'Türk',
          ingredients: const [],
          steps: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a variation when the parent recipe is missing', () async {
      await expectLater(
        service.createSubRecipe(
          parentRecipeId: 'missing',
          authorId: 'user-2',
          authorName: 'Ayşe',
          name: 'Yetim varyasyon',
          description: 'Reddedilmeli',
          emoji: '🍲',
          duration: '20 dk',
          cuisine: 'Türk',
          ingredients: const [],
          steps: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('leaves a legacy comment counter to Cloud Functions', () async {
      await _saveRecipe(firestore, _recipe(id: 'main', commentCount: 1));
      final comment = Comment(
        id: 'comment-1',
        recipeId: 'main',
        userId: 'user-1',
        userDisplayName: 'Kullanıcı',
        text: 'Çok güzel',
        createdAt: _commentTime,
      );
      final commentRef = firestore
          .collection('recipes')
          .doc('main')
          .collection('comments')
          .doc(comment.id);
      await commentRef.set(comment.toFirestore());

      await service.deleteComment(recipeId: 'main', commentId: comment.id);
      expect((await commentRef.get()).exists, isFalse);
      expect((await service.fetchById('main'))!.commentCount, 1);

      await service.deleteComment(recipeId: 'main', commentId: comment.id);
      expect((await service.fetchById('main'))!.commentCount, 1);
    });

    test(
      'leaves a server-managed comment counter to Cloud Functions',
      () async {
        await _saveRecipe(firestore, _recipe(id: 'main', commentCount: 1));
        final commentRef = firestore
            .collection('recipes')
            .doc('main')
            .collection('comments')
            .doc('comment-1');
        await commentRef.set({
          ...Comment(
            id: 'comment-1',
            recipeId: 'main',
            userId: 'user-1',
            userDisplayName: 'Kullanıcı',
            text: 'Yeni yorum',
            createdAt: _commentTime,
          ).toFirestore(),
          'counterManagedBy': RecipeService.serverCounterMarker,
        });

        await service.deleteComment(recipeId: 'main', commentId: 'comment-1');

        expect((await commentRef.get()).exists, isFalse);
        expect((await service.fetchById('main'))!.commentCount, 1);
      },
    );

    test(
      'marks new likes for server counters and supports legacy unlike',
      () async {
        await _saveRecipe(firestore, _recipe(id: 'main'));
        final likeRef = firestore
            .collection('recipes')
            .doc('main')
            .collection('likes')
            .doc('user-1');

        await service.toggleLike('main', 'user-1');
        expect(
          (await likeRef.get()).data()?['counterManagedBy'],
          RecipeService.serverCounterMarker,
        );
        expect((await service.fetchById('main'))!.likeCount, 0);

        await likeRef.set({
          'userId': 'user-1',
          'createdAt': Timestamp.fromDate(_commentTime),
        });
        await firestore.collection('recipes').doc('main').update({
          'likeCount': 1,
        });
        await service.toggleLike('main', 'user-1');
        expect((await likeRef.get()).exists, isFalse);
        expect((await service.fetchById('main'))!.likeCount, 0);
      },
    );

    test('deletes an orphan comment after its recipe was removed', () async {
      final commentRef = firestore
          .collection('recipes')
          .doc('deleted-recipe')
          .collection('comments')
          .doc('comment-1');
      await commentRef.set(
        Comment(
          id: 'comment-1',
          recipeId: 'deleted-recipe',
          userId: 'user-1',
          userDisplayName: 'Kullanıcı',
          text: 'Eski yorum',
          createdAt: _commentTime,
        ).toFirestore(),
      );

      await service.deleteComment(
        recipeId: 'deleted-recipe',
        commentId: 'comment-1',
      );

      expect((await commentRef.get()).exists, isFalse);
    });

    test('hydrates and orders comment and like activity', () async {
      await _saveRecipe(firestore, _recipe(id: 'older'));
      await _saveRecipe(firestore, _recipe(id: 'newer'));

      await firestore
          .collection('recipes')
          .doc('older')
          .collection('comments')
          .doc('comment-old')
          .set(
            Comment(
              id: 'comment-old',
              recipeId: 'older',
              userId: 'user-1',
              userDisplayName: 'Kullanıcı',
              text: 'Eski yorum',
              createdAt: _commentTime,
            ).toFirestore(),
          );
      await firestore
          .collection('recipes')
          .doc('newer')
          .collection('comments')
          .doc('comment-new')
          .set(
            Comment(
              id: 'comment-new',
              recipeId: 'newer',
              userId: 'user-1',
              userDisplayName: 'Kullanıcı',
              text: 'Yeni yorum',
              createdAt: _newerCommentTime,
            ).toFirestore(),
          );

      await firestore
          .collection('recipes')
          .doc('older')
          .collection('likes')
          .doc('user-1')
          .set({
            'userId': 'user-1',
            'createdAt': Timestamp.fromDate(_commentTime),
          });
      await firestore
          .collection('recipes')
          .doc('newer')
          .collection('likes')
          .doc('user-1')
          .set({
            'userId': 'user-1',
            'createdAt': Timestamp.fromDate(_newerCommentTime),
          });

      final comments = await service
          .userCommentActivitiesStream('user-1')
          .first;
      final likes = await service.userLikeActivitiesStream('user-1').first;

      expect(comments.map((activity) => activity.recipeId), ['newer', 'older']);
      expect(comments.every((activity) => activity.recipe != null), isTrue);
      expect(likes.map((activity) => activity.recipeId), ['newer', 'older']);
      expect(likes.every((activity) => activity.recipe != null), isTrue);
    });

    test('hydrates activity across the 30-document whereIn boundary', () async {
      for (var index = 0; index < 31; index++) {
        final recipeId = 'recipe-$index';
        await _saveRecipe(firestore, _recipe(id: recipeId));
        await firestore
            .collection('recipes')
            .doc(recipeId)
            .collection('likes')
            .doc('user-1')
            .set({
              'userId': 'user-1',
              'createdAt': Timestamp.fromDate(
                DateTime.utc(2026, 7, 17, 12, index),
              ),
            });
      }

      final likes = await service.userLikeActivitiesStream('user-1').first;

      expect(likes, hasLength(31));
      expect(likes.every((activity) => activity.recipe != null), isTrue);
    });

    test(
      'approves a submission once with a deterministic main recipe',
      () async {
        final pending = PendingRecipe(
          id: 'pending-1',
          name: 'Ev Usulü Tarif',
          description: 'Açıklama',
          cuisine: 'Türk',
          type: 'Ana Yemek',
          duration: '35 dk',
          emoji: '🍲',
          imageUrls: const [],
          ingredients: const [],
          steps: const [],
          tags: const [],
          authorId: 'user-1',
          authorName: 'Zeynep',
          status: PendingStatus.pending,
          createdAt: DateTime.utc(2026, 7, 16),
        );
        await firestore
            .collection('pending_recipes')
            .doc(pending.id)
            .set(pending.toFirestore());
        final pendingService = PendingRecipeService(firestore: firestore);

        await pendingService.approveRecipe(pending);
        await pendingService.approveRecipe(pending);

        final recipes = await firestore.collection('recipes').get();
        expect(recipes.docs, hasLength(1));
        expect(recipes.docs.single.id, 'submission_pending-1');
        final approved = Recipe.fromFirestore(recipes.docs.single);
        expect(approved.authorName, 'Zeynep');
        expect(approved.recipeKind, Recipe.mainKind);
        final submission = await firestore
            .collection('pending_recipes')
            .doc(pending.id)
            .get();
        expect(submission.data()?['status'], 'approved');
        expect(submission.data()?['publishedRecipeId'], 'submission_pending-1');
      },
    );

    test('parses legacy malformed pending payloads defensively', () async {
      final ref = firestore.collection('pending_recipes').doc('malformed');
      await ref.set({
        'name': 'KÄ±smi kayÄ±t',
        'imageUrls': [42, 'https://example.com/image.jpg'],
        'ingredients': [
          'invalid',
          {'ingredientId': 'mercimek', 'name': 'Mercimek', 'amount': '1 su'},
        ],
        'steps': [
          null,
          {'order': 1, 'text': 'PiÅŸir'},
        ],
        'tags': ['Ã§orba', 99],
        'status': 42,
      });

      final parsed = PendingRecipe.fromFirestore(await ref.get());

      expect(parsed.imageUrls, ['https://example.com/image.jpg']);
      expect(parsed.ingredients, hasLength(1));
      expect(parsed.steps, hasLength(1));
      expect(parsed.tags, ['Ã§orba']);
      expect(parsed.status, PendingStatus.pending);
    });
  });

  test('approved profile submission maps to a named main recipe', () {
    final pending = PendingRecipe(
      id: 'pending-1',
      name: 'Ev Usulü Tarif',
      description: 'Açıklama',
      cuisine: 'Türk',
      type: 'Ana Yemek',
      duration: '35 dk',
      emoji: '🍲',
      imageUrls: const [],
      ingredients: const [],
      steps: const [],
      tags: const ['ev yapımı'],
      authorId: 'user-1',
      authorName: 'Zeynep',
      status: PendingStatus.pending,
      createdAt: DateTime.utc(2026, 7, 16),
    );

    final recipe = PendingRecipeService.recipeFromApprovedSubmission(
      pending,
      recipeId: 'recipe-1',
      approvedAt: DateTime.utc(2026, 7, 17),
    );

    expect(recipe.authorId, 'user-1');
    expect(recipe.authorName, 'Zeynep');
    expect(recipe.isOfficial, isFalse);
    expect(recipe.isMainRecipe, isTrue);
    expect(recipe.parentRecipeId, isNull);
    expect(recipe.toFirestore().containsKey('parentRecipeId'), isFalse);
  });
}

final _commentTime = DateTime.utc(2026, 7, 17, 10);
final _newerCommentTime = DateTime.utc(2026, 7, 17, 11);
