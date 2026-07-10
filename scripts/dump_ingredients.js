const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
(async () => {
  const snap = await db.collection('ingredients').orderBy('name').get();
  const byCat = {};
  snap.forEach(d => {
    const c = d.data().category || 'MISSING';
    (byCat[c] = byCat[c] || []).push({ id: d.id, name: d.data().name });
  });
  const dump = ['diger', 'other', 'sivi', 'tatlandirici', 'baklagil', 'bakliyat', 'ekmek', 'un', 'hamur işi', 'yesillik'];
  for (const c of dump) {
    console.log(`\n=== ${c} (${(byCat[c]||[]).length}) ===`);
    for (const it of (byCat[c] || [])) console.log(`${it.id}\t${it.name}`);
  }
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
