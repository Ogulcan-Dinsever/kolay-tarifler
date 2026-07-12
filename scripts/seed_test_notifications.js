/**
 * TEST: e-postası verilen kullanıcıya 3 tip örnek bildirim yazar.
 *   node seed_test_notifications.js <email>
 * Bildirim ekranı/rozet emülatör doğrulaması için. Test sonrası ekrandan silinir.
 */
const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

(async () => {
  const email = process.argv[2];
  if (!email) { console.error('e-posta ver'); process.exit(1); }

  const user = await admin.auth().getUserByEmail(email);
  const col = db.collection('users').doc(user.uid).collection('notifications');

  const now = Date.now();
  const items = [
    {
      title: '❤️ Yeni Beğeni',
      body: 'Ayşe, "Menemen" tarifini beğendi.',
      type: 'recipe_liked',
      targetId: 'recipe_1',
      read: false,
      createdAt: admin.firestore.Timestamp.fromMillis(now - 2 * 60 * 1000),
    },
    {
      title: '💬 Yeni Yorum',
      body: 'Mehmet: "Elime sağlık dedirten cinsten, süper oldu!"',
      type: 'comment',
      targetId: 'recipe_1',
      read: false,
      createdAt: admin.firestore.Timestamp.fromMillis(now - 3 * 60 * 60 * 1000),
    },
    {
      title: '🎉 Tarifin Onaylandı!',
      body: '"Fırında Karnabahar" tarifi yayına alındı.',
      type: 'pending_recipe',
      targetId: 'pending_abc',
      read: true,
      createdAt: admin.firestore.Timestamp.fromMillis(now - 26 * 60 * 60 * 1000),
    },
  ];

  for (const it of items) await col.add(it);
  console.log('✅ 3 bildirim yazıldı →', user.uid);
  process.exit(0);
})().catch((e) => { console.error('❌', e.message); process.exit(1); });
