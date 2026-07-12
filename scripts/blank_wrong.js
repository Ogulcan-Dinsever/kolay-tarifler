// Görsel denetimde yanlış çıkan tarifleri resimsiz bırakır (imageUrls/imageSources boş).
// node blank_wrong.js "Ad1" "Ad2" ...
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
const WRONG = process.argv.slice(2);
(async () => {
  if (!WRONG.length) { console.error('isim ver'); process.exit(1); }
  let n = 0;
  for (const name of WRONG) {
    const s = await db.collection('recipes').where('name', '==', name).get();
    if (s.empty) { console.log('BULUNAMADI:', name); continue; }
    for (const d of s.docs) {
      await d.ref.update({ imageUrls: [], imageSources: [], modifiedAt: admin.firestore.Timestamp.now() });
      n++;
      console.log('blank:', name);
    }
  }
  console.log(`\n${n} tarif resimsiz bırakıldı.`);
  process.exit(0);
})().catch(e => { console.error('❌', e.message); process.exit(1); });
