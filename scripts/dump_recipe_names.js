const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
(async () => {
  const snap = await db.collection('recipes').get();
  const rows = [];
  snap.forEach(d => {
    const r = d.data();
    rows.push({ name: r.name || '', cuisine: r.cuisine || '', type: r.type || '', official: r.isOfficial !== false });
  });
  rows.sort((a, b) => a.name.localeCompare(b.name, 'tr'));
  console.log('TOPLAM:', rows.length);
  const byCuisine = {};
  rows.forEach(r => byCuisine[r.cuisine] = (byCuisine[r.cuisine] || 0) + 1);
  console.log('CUISINE:', JSON.stringify(byCuisine));
  console.log('\n=== TÜM İSİMLER ===');
  rows.forEach(r => console.log(r.name));
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
