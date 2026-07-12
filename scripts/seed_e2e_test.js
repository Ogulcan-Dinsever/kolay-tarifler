/**
 * E2E bildirim testi hazırlığı / tetikleme.
 *   node seed_e2e_test.js setup   → qa2'ye topluluk tarifi + pending başvuru oluştur
 *   node seed_e2e_test.js approve → pending başvuruyu onayla (trigger gerçek bildirimi yazar)
 *   node seed_e2e_test.js status  → qa2'nin bildirimlerini listele
 */
const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const OWNER_EMAIL = 'qatest2.claude.20260712@gmail.com';
const SUB_RECIPE_ID = 'qa_e2e_sub_recipe';
const PENDING_ID = 'qa_e2e_pending';

(async () => {
  const mode = process.argv[2];
  const owner = await admin.auth().getUserByEmail(OWNER_EMAIL);

  if (mode === 'setup') {
    // Topluluk tarifi — Mercimek Çorbası'nın (recipe_1) altına sürüm
    await db.collection('recipes').doc(SUB_RECIPE_ID).set({
      name: 'QA Sürümü: Bol Kimyonlu Mercimek',
      description: 'E2E bildirim testi için topluluk sürümü.',
      cuisine: 'Türk',
      type: 'Çorba',
      duration: '30 dk',
      emoji: '🍲',
      imageUrls: [],
      tags: ['Test'],
      ingredients: [
        { ingredientId: '', name: 'Kırmızı mercimek', amount: '1 su bardağı', emoji: '🥣' },
        { ingredientId: '', name: 'Kimyon', amount: '1 tatlı kaşığı', emoji: '🌿' },
      ],
      steps: [{ order: 1, text: 'Hepsini kaynatıp blenderdan geçir.' }],
      authorId: owner.uid,
      authorName: 'QA',
      isOfficial: false,
      parentRecipeId: 'recipe_1',
      likeCount: 0,
      commentCount: 0,
      communityLikeCount: 0,
      createdAt: admin.firestore.Timestamp.now(),
      modifiedAt: admin.firestore.Timestamp.now(),
    });
    // Bekleyen başvuru — approve trigger'ı için
    await db.collection('pending_recipes').doc(PENDING_ID).set({
      name: 'QA E2E Fırında Karnabahar',
      description: 'E2E onay bildirimi testi.',
      status: 'pending',
      authorId: owner.uid,
      authorName: 'QA',
      createdAt: admin.firestore.Timestamp.now(),
    });
    console.log('✅ setup tamam — sub:', SUB_RECIPE_ID, '| pending:', PENDING_ID);
  } else if (mode === 'approve') {
    await db.collection('pending_recipes').doc(PENDING_ID).update({ status: 'approved' });
    console.log('✅ onaylandı → onPendingRecipeStatusChange tetiklenecek');
  } else if (mode === 'status') {
    const snap = await db.collection('users').doc(owner.uid)
      .collection('notifications').orderBy('createdAt', 'desc').get();
    for (const d of snap.docs) {
      const x = d.data();
      console.log(`- [${x.read ? 'okundu' : 'YENİ'}] ${x.title} | ${x.body} | type=${x.type}`);
    }
    console.log(`toplam: ${snap.size}`);
  } else {
    console.error('mod: setup | approve | status');
    process.exit(1);
  }
  process.exit(0);
})().catch((e) => { console.error('❌', e.message); process.exit(1); });
