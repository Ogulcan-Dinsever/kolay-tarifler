const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {
  normalizeTokens,
  stringifyData,
  invalidTokensFromResponses,
} = require('./notification_helpers');

admin.initializeApp();
const db = admin.firestore();

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
    const result = await admin.messaging().sendEachForMulticast({
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
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      };
      if (invalidTokens.includes(userData.fcmToken)) {
        update.fcmToken = admin.firestore.FieldValue.delete();
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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

exports.onRecipeLiked = functions
  .region('europe-west1')
  .firestore.document('recipes/{recipeId}/likes/{likerId}')
  .onCreate(async (_, context) => {
    const { recipeId, likerId } = context.params;

    const recipeSnap = await db.collection('recipes').doc(recipeId).get();
    const recipe = recipeSnap.data();

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
  });

// ── 3. Yorum bildirimi ───────────────────────────────────────────────────────

exports.onCommentAdded = functions
  .region('europe-west1')
  .firestore.document('recipes/{recipeId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { recipeId } = context.params;
    const comment = snap.data();

    const recipeSnap = await db.collection('recipes').doc(recipeId).get();
    const recipe = recipeSnap.data();

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
  });

// Hesap silindiğinde kullanıcıya bağlı Firestore ve Storage verilerini temizle.
// İstemci hesabı sildikten sonra Admin SDK ile çalıştığı için alt koleksiyonlar
// ve kullanıcının doğrudan silemeyeceği yayımlanmış içerikler de kapsanır.
async function deleteQuery(query, beforeDelete) {
  while (true) {
    const snapshot = await query.limit(300).get();
    if (snapshot.empty) return;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      if (beforeDelete) await beforeDelete(doc, batch);
      batch.delete(doc.ref);
    }
    await batch.commit();
    if (snapshot.size < 300) return;
  }
}

exports.onAuthUserDeleted = functions
  .region('europe-west1')
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;

    await deleteQuery(
      db.collectionGroup('likes').where('userId', '==', uid),
      async (doc, batch) => {
        const recipeRef = doc.ref.parent.parent;
        if (recipeRef) {
          batch.update(recipeRef, {
            likeCount: admin.firestore.FieldValue.increment(-1),
          });
        }
      },
    );

    await deleteQuery(
      db.collectionGroup('comments').where('userId', '==', uid),
      async (doc, batch) => {
        const recipeRef = doc.ref.parent.parent;
        if (recipeRef) {
          batch.update(recipeRef, {
            commentCount: admin.firestore.FieldValue.increment(-1),
          });
        }
      },
    );

    const authoredRecipes = await db
      .collection('recipes')
      .where('authorId', '==', uid)
      .get();
    for (const recipe of authoredRecipes.docs) {
      await db.recursiveDelete(recipe.ref);
    }

    await deleteQuery(
      db.collection('pending_recipes').where('authorId', '==', uid),
    );
    await deleteQuery(db.collection('reports').where('reporterId', '==', uid));
    await deleteQuery(db.collection('reports').where('targetUserId', '==', uid));

    await db.recursiveDelete(db.collection('users').doc(uid));

    const bucket = admin.storage().bucket();
    await Promise.all([
      bucket.deleteFiles({ prefix: `recipe_images/${uid}/` }),
      bucket.deleteFiles({ prefix: `pending_recipes/${uid}/` }),
      bucket.deleteFiles({ prefix: `avatars/${uid}/` }),
    ]);

    console.log(`Kullanıcı verileri temizlendi: ${uid}`);
  });
