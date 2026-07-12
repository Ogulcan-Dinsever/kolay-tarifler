/**
 * E2E bildirim testi artıklarını üretimden siler:
 * test tarifi (+likes/comments), pending belge, qa2'nin test bildirimleri.
 */
const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const OWNER_EMAIL = 'qatest2.claude.20260712@gmail.com';
const SUB_RECIPE_ID = 'qa_e2e_sub_recipe';
const PENDING_ID = 'qa_e2e_pending';

async function deleteCollection(ref) {
  const snap = await ref.get();
  for (const d of snap.docs) await d.ref.delete();
  return snap.size;
}

(async () => {
  const recipeRef = db.collection('recipes').doc(SUB_RECIPE_ID);
  const likes = await deleteCollection(recipeRef.collection('likes'));
  const comments = await deleteCollection(recipeRef.collection('comments'));
  await recipeRef.delete();
  console.log(`✅ tarif silindi (beğeni:${likes} yorum:${comments})`);

  await db.collection('pending_recipes').doc(PENDING_ID).delete();
  console.log('✅ pending silindi');

  const owner = await admin.auth().getUserByEmail(OWNER_EMAIL);
  const n = await deleteCollection(
    db.collection('users').doc(owner.uid).collection('notifications'));
  console.log(`✅ qa2 bildirimleri silindi (${n})`);
  process.exit(0);
})().catch((e) => { console.error('❌', e.message); process.exit(1); });
