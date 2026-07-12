const admin = require('firebase-admin');
const fs = require('fs');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
(async () => {
  const snap = await db.collection('recipes').get();
  const out = [];
  snap.forEach(d => {
    const r = d.data();
    const has = (r.imageUrls || []).some(u => u && u.trim());
    if (!has) out.push({ id: d.id, name: r.name, cuisine: r.cuisine || r.category || r.origin || '' });
  });
  out.sort((a,b) => a.name.localeCompare(b.name, 'tr'));
  fs.writeFileSync('_imageless.json', JSON.stringify(out, null, 0));
  console.log(`resimsiz: ${out.length}`);
  out.forEach((x,i) => console.log(String(i).padStart(3), x.name, '|', x.cuisine));
  process.exit(0);
})();
