const functions = require('firebase-functions/v1');
const {
  onDocumentCreated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getDownloadURL, getStorage } = require('firebase-admin/storage');
const {
  normalizeTokens,
  stringifyData,
  invalidTokensFromResponses,
} = require('./notification_helpers');
const {
  createRecipeCounterReconciler,
  recipeKindFor,
} = require('./counter_helpers');
const {
  findContentViolation,
  recipeTextValues,
} = require('./content_moderation');

initializeApp();
const db = getFirestore();
const reconcileRecipeCounters = createRecipeCounterReconciler({ db });

// ── Yardımcı: FCM gönder ────────────────────────────────────────────────────

async function sendToUser(userId, { title, body }, data = {}) {
  const snap = await db.collection('users').doc(userId).get();
  const userData = snap.data() || {};
  const tokens = normalizeTokens(userData);
  if (tokens.length === 0) {
    console.info('FCM atlandı: kayıtlı cihaz tokenı yok', { userId });
    return null;
  }

  try {
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      android: {
        notification: { channelId: 'kt_main', sound: 'default' },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
      data: stringifyData(data),
    });

    console.info('FCM gönderim sonucu', {
      userId,
      deviceCount: tokens.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
    });

    const invalidTokens = invalidTokensFromResponses(tokens, result.responses);
    if (invalidTokens.length > 0) {
      const update = {
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      };
      if (invalidTokens.includes(userData.fcmToken)) {
        update.fcmToken = FieldValue.delete();
      }
      await snap.ref.update(update).catch((err) => {
        console.error('Geçersiz FCM tokenları temizlenemedi', {
          userId,
          errorCode: err.code,
          errorMessage: err.message,
        });
      });
    }

    for (const response of result.responses) {
      if (!response.success) {
        console.error('FCM cihaz gönderimi başarısız', {
          userId,
          errorCode: response.error?.code,
          errorMessage: response.error?.message,
        });
      }
    }
    return result;
  } catch (err) {
    console.error('FCM toplu gönderimi başarısız', {
      userId,
      deviceCount: tokens.length,
      errorCode: err.code,
      errorMessage: err.message,
    });
    return null;
  }
}

// Uygulama içi bildirim: users/{uid}/notifications altına kayıt.
// Zil ekranı bu koleksiyonu dinler; FCM gitmese bile (token yok/izin kapalı)
// bildirim uygulama içinde görünür.
async function addInApp(userId, { title, body }, data = {}) {
  try {
    await db.collection('users').doc(userId).collection('notifications').add({
      title,
      body,
      type: data.type || null,
      targetId: data.recipeId || data.id || null,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error('Uygulama içi bildirim yazılamadı', {
      userId,
      errorCode: err.code,
      errorMessage: err.message,
    });
    throw err;
  }
}

// Hem uygulama içi kayıt hem FCM push — tüm event'ler bunu kullanır.
async function notifyUser(userId, message, data = {}) {
  await addInApp(userId, message, data);
  return sendToUser(userId, message, data);
}

async function removeFilteredContent(event, { targetType, targetUserId, values, recipeId }) {
  const violation = findContentViolation(values);
  if (!violation) return false;

  const snap = event.data;
  const targetId = event.params.commentId || event.params.recipeId || snap.id;
  const reportRef = db.collection('reports').doc(`automatic_${event.id}`);
  const batch = db.batch();
  batch.delete(snap.ref);
  batch.set(reportRef, {
    reporterId: 'automatic-content-filter',
    targetType,
    targetId,
    targetUserId: targetUserId || '',
    reason: `Otomatik içerik filtresi: ${violation}`,
    ...(recipeId ? { recipeId } : {}),
    status: 'open',
    automatic: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.warn('Uygunsuz kullanıcı içeriği otomatik olarak kaldırıldı', {
    targetType,
    targetId,
    targetUserId,
    violation,
  });
  return true;
}

// ── 1. Tarif onay / red bildirimi ────────────────────────────────────────────

exports.onPendingRecipeStatusChange = functions
  .region('europe-west1')
  .firestore.document('pending_recipes/{docId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    if (before.status === after.status) return null;

    let title, body;
    if (after.status === 'approved') {
      title = '🎉 Tarifin Onaylandı!';
      body  = `"${after.name}" tarifi yayına alındı.`;
    } else if (after.status === 'rejected') {
      const reason = after.rejectionComment
        ? ` Sebep: ${after.rejectionComment}`
        : '';
      title = '😔 Tarifin Reddedildi';
      body  = `"${after.name}" tarifi kabul edilmedi.${reason}`;
    } else {
      return null;
    }

    return notifyUser(
      after.authorId,
      { title, body },
      { type: 'pending_recipe', id: context.params.docId },
    );
  });

// ── 2. Tarif beğeni bildirimi ────────────────────────────────────────────────

// Eski istemciler recipeKind göndermez. Sunucu filtreli yeni sorgularda bu
// tariflerin kaybolmaması için alanı oluşturma sonrasında tamamla.
exports.onRecipeCreatedV2 = onDocumentCreated(
  {
    document: 'recipes/{recipeId}',
    region: 'europe-west1',
    retry: true,
  },
  (event) => {
    const snap = event.data;
    const recipe = snap.data() || {};
    if (recipe.recipeKind === 'main' || recipe.recipeKind === 'variation') {
      return null;
    }
    return snap.ref.update({ recipeKind: recipeKindFor(recipe) });
  },
);

exports.onVariationCreatedModerationV2 = onDocumentCreated(
  {
    document: 'recipe_variations/{recipeId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const recipe = event.data.data() || {};
    await removeFilteredContent(event, {
      targetType: 'recipe',
      targetUserId: recipe.authorId,
      values: recipeTextValues(recipe),
      recipeId: event.params.recipeId,
    });
  },
);

exports.onPendingRecipeCreatedModerationV2 = onDocumentCreated(
  {
    document: 'pending_recipes/{recipeId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const recipe = event.data.data() || {};
    const violation = findContentViolation(recipeTextValues(recipe));
    if (!violation) return null;

    await event.data.ref.update({
      status: 'rejected',
      rejectionComment: `Otomatik içerik filtresi: ${violation}`,
      reviewedAt: FieldValue.serverTimestamp(),
    });
    await db.collection('reports').doc(`automatic_${event.id}`).set({
      reporterId: 'automatic-content-filter',
      targetType: 'recipe',
      targetId: event.params.recipeId,
      targetUserId: recipe.authorId || '',
      reason: `Otomatik içerik filtresi: ${violation}`,
      recipeId: event.params.recipeId,
      status: 'open',
      automatic: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    return null;
  },
);

// Eski ve yeni istemciler aynı anda kullanılırken veya kötü niyetli bir sayaç
// nudgesi geldiğinde alanları gerçek alt koleksiyon sayılarıyla uzlaştırır.
exports.onRecipeLikedV2 = onDocumentCreated(
  {
    document: 'recipes/{recipeId}/likes/{likerId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const { recipeId, likerId } = event.params;
    await reconcileRecipeCounters(recipeId, ['likeCount']);
    const recipe = (await db.collection('recipes').doc(recipeId).get()).data();

    // Resmi tariflerin veya kendi beğenisinin bildirimi yok
    if (!recipe || recipe.isOfficial || !recipe.authorId || recipe.authorId === likerId) {
      return null;
    }

    const likerSnap = await db.collection('users').doc(likerId).get();
    const likerName = likerSnap.data()?.displayName || 'Biri';

    return notifyUser(
      recipe.authorId,
      {
        title: '❤️ Yeni Beğeni',
        body:  `${likerName}, "${recipe.name}" tarifini beğendi.`,
      },
      { type: 'recipe_liked', recipeId },
    );
  },
);

exports.onRecipeUnlikedV2 = onDocumentDeleted(
  {
    document: 'recipes/{recipeId}/likes/{likerId}',
    region: 'europe-west1',
    retry: true,
  },
  (event) => reconcileRecipeCounters(event.params.recipeId, ['likeCount']),
);

// ── 3. Yorum bildirimi ───────────────────────────────────────────────────────

exports.onCommentAddedV2 = onDocumentCreated(
  {
    document: 'recipes/{recipeId}/comments/{commentId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const snap = event.data;
    const { recipeId } = event.params;
    const comment = snap.data();

    const filtered = await removeFilteredContent(event, {
      targetType: 'comment',
      targetUserId: comment.userId,
      values: [comment.text],
      recipeId,
    });
    if (filtered) return null;

    await reconcileRecipeCounters(recipeId, ['commentCount']);
    const recipe = (await db.collection('recipes').doc(recipeId).get()).data();

    // Resmi tariflerin veya kendi yorumunun bildirimi yok
    if (!recipe || recipe.isOfficial || !recipe.authorId || recipe.authorId === comment.userId) {
      return null;
    }

    const authorName = comment.userDisplayName || 'Biri';
    const preview = comment.text?.length > 60
      ? comment.text.substring(0, 60) + '…'
      : comment.text;

    return notifyUser(
      recipe.authorId,
      {
        title: '💬 Yeni Yorum',
        body:  `${authorName}: "${preview}"`,
      },
      { type: 'comment', recipeId },
    );
  },
);

exports.onCommentDeletedV2 = onDocumentDeleted(
  {
    document: 'recipes/{recipeId}/comments/{commentId}',
    region: 'europe-west1',
    retry: true,
  },
  (event) => reconcileRecipeCounters(event.params.recipeId, ['commentCount']),
);

exports.onVariationLikedV2 = onDocumentCreated(
  {
    document: 'recipe_variations/{recipeId}/likes/{likerId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const { recipeId, likerId } = event.params;
    await reconcileRecipeCounters(
      recipeId,
      ['likeCount'],
      'recipe_variations',
    );
    const recipe = (
      await db.collection('recipe_variations').doc(recipeId).get()
    ).data();
    if (!recipe || !recipe.authorId || recipe.authorId === likerId) return null;

    const likerSnap = await db.collection('users').doc(likerId).get();
    const likerName = likerSnap.data()?.displayName || 'Biri';
    return notifyUser(
      recipe.authorId,
      {
        title: '❤️ Yeni Beğeni',
        body: `${likerName}, "${recipe.name}" tarifini beğendi.`,
      },
      { type: 'recipe_liked', recipeId },
    );
  },
);

exports.onVariationUnlikedV2 = onDocumentDeleted(
  {
    document: 'recipe_variations/{recipeId}/likes/{likerId}',
    region: 'europe-west1',
    retry: true,
  },
  (event) =>
    reconcileRecipeCounters(
      event.params.recipeId,
      ['likeCount'],
      'recipe_variations',
    ),
);

exports.onVariationCommentAddedV2 = onDocumentCreated(
  {
    document: 'recipe_variations/{recipeId}/comments/{commentId}',
    region: 'europe-west1',
    retry: true,
  },
  async (event) => {
    const snap = event.data;
    const { recipeId } = event.params;
    const comment = snap.data();
    const filtered = await removeFilteredContent(event, {
      targetType: 'comment',
      targetUserId: comment.userId,
      values: [comment.text],
      recipeId,
    });
    if (filtered) return null;
    await reconcileRecipeCounters(
      recipeId,
      ['commentCount'],
      'recipe_variations',
    );
    const recipe = (
      await db.collection('recipe_variations').doc(recipeId).get()
    ).data();
    if (!recipe || !recipe.authorId || recipe.authorId === comment.userId) {
      return null;
    }

    const authorName = comment.userDisplayName || 'Biri';
    const preview = comment.text?.length > 60
      ? `${comment.text.substring(0, 60)}…`
      : comment.text;
    return notifyUser(
      recipe.authorId,
      {
        title: '💬 Yeni Yorum',
        body: `${authorName}: "${preview}"`,
      },
      { type: 'comment', recipeId },
    );
  },
);

exports.onVariationCommentDeletedV2 = onDocumentDeleted(
  {
    document: 'recipe_variations/{recipeId}/comments/{commentId}',
    region: 'europe-west1',
    retry: true,
  },
  (event) =>
    reconcileRecipeCounters(
      event.params.recipeId,
      ['commentCount'],
      'recipe_variations',
    ),
);

// Hesap silindiğinde kullanıcıya bağlı Firestore ve Storage verilerini temizle.
// İstemci hesabı sildikten sonra Admin SDK ile çalıştığı için alt koleksiyonlar
// ve kullanıcının doğrudan silemeyeceği yayımlanmış içerikler de kapsanır.
async function deleteQuery(query) {
  while (true) {
    const snapshot = await query.limit(400).get();
    if (snapshot.empty) return;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    if (snapshot.size < 400) return;
  }
}

function storageObjectName(downloadUrl) {
  if (typeof downloadUrl !== 'string' || !downloadUrl) return null;
  if (downloadUrl.startsWith('gs://')) {
    const firstSlash = downloadUrl.indexOf('/', 5);
    return firstSlash < 0 ? null : downloadUrl.substring(firstSlash + 1);
  }
  try {
    const url = new URL(downloadUrl);
    const marker = '/o/';
    const markerIndex = url.pathname.indexOf(marker);
    if (markerIndex < 0) return null;
    return decodeURIComponent(url.pathname.substring(markerIndex + marker.length));
  } catch (_) {
    return null;
  }
}

async function promotePendingImages(bucket, uid, recipe) {
  const imageUrls = Array.isArray(recipe.data().imageUrls)
    ? recipe.data().imageUrls
    : [];
  return Promise.all(
    imageUrls.map(async (imageUrl) => {
      const objectName = storageObjectName(imageUrl);
      const pendingPrefix = `pending_recipes/${uid}/`;
      if (!objectName?.startsWith(pendingPrefix)) return imageUrl;

      const fileName = objectName.substring(pendingPrefix.length);
      const destination = bucket.file(
        `recipes/submissions/${recipe.id}/${fileName}`,
      );
      await bucket.file(objectName).copy(destination);
      return getDownloadURL(destination);
    }),
  );
}

exports.onAuthUserDeleted = functions
  .runWith({ failurePolicy: true, timeoutSeconds: 540, memory: '1GB' })
  .region('europe-west1')
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const bucket = getStorage().bucket();

    await deleteQuery(db.collectionGroup('likes').where('userId', '==', uid));
    await deleteQuery(
      db.collectionGroup('comments').where('userId', '==', uid),
    );

    const authoredRecipes = await db
      .collection('recipes')
      .where('authorId', '==', uid)
      .get();
    for (const recipe of authoredRecipes.docs) {
      const imageUrls = await promotePendingImages(bucket, uid, recipe);
      // Moderasyondan geçmiş ana tarif keşifte kalır; kişisel atıf silinir.
      await recipe.ref.update({
        authorId: 'deleted-user',
        imageUrls,
        authorName: 'Silinmiş kullanıcı',
      });
    }

    const authoredVariations = await db
      .collection('recipe_variations')
      .where('authorId', '==', uid)
      .get();
    for (const variation of authoredVariations.docs) {
      await db.recursiveDelete(variation.ref);
    }

    await deleteQuery(
      db.collection('pending_recipes').where('authorId', '==', uid),
    );
    await deleteQuery(db.collection('reports').where('reporterId', '==', uid));
    await deleteQuery(db.collection('reports').where('targetUserId', '==', uid));

    await db.recursiveDelete(db.collection('users').doc(uid));

    const storageCleanup = [
      bucket.deleteFiles({ prefix: `avatars/${uid}/` }),
      bucket.deleteFiles({ prefix: `recipe_images/${uid}/` }),
      bucket.deleteFiles({ prefix: `pending_recipes/${uid}/` }),
    ];
    await Promise.all(storageCleanup);

    console.log(`Kullanıcı verileri temizlendi: ${uid}`);
  });
