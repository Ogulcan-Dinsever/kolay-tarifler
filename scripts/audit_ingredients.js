// Malzeme denetimi: çiftlenmiş adaylar + görselsizler + kullanım sayıları.
// Kullanım: node audit_ingredients.js
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});
const db = admin.firestore();

// Türkçe katlama: karşılaştırma anahtarı
function fold(s) {
  return (s || '')
    .replace(/I/g, 'ı').replace(/İ/g, 'i')
    .toLowerCase()
    .replace(/ç/g, 'c').replace(/ğ/g, 'g').replace(/ı/g, 'i')
    .replace(/ö/g, 'o').replace(/ş/g, 's').replace(/ü/g, 'u')
    .replace(/\([^)]*\)/g, '') // parantez içini at
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

(async () => {
  const [ingSnap, recSnap] = await Promise.all([
    db.collection('ingredients').get(),
    db.collection('recipes').get(),
  ]);

  const usage = {};
  for (const d of recSnap.docs) {
    for (const i of d.data().ingredients || []) {
      if (i && i.ingredientId) usage[i.ingredientId] = (usage[i.ingredientId] || 0) + 1;
    }
  }

  const items = ingSnap.docs.map((d) => ({
    id: d.id,
    name: d.data().name || '',
    imageUrl: d.data().imageUrl || '',
    category: d.data().category || '',
    use: usage[d.id] || 0,
  }));

  // 1) Aynı katlanmış ada sahip gruplar
  const byKey = {};
  for (const it of items) {
    const k = fold(it.name);
    (byKey[k] = byKey[k] || []).push(it);
  }
  console.log('══ ÇİFT ADAYLARI (aynı katlanmış ad) ══');
  for (const [k, group] of Object.entries(byKey)) {
    if (group.length > 1) {
      console.log(`\n[${k}]`);
      for (const g of group) {
        console.log(`  ${g.id} | "${g.name}" | ${g.category} | kullanım:${g.use} | img:${g.imageUrl ? 'VAR' : 'YOK'}`);
      }
    }
  }

  // 2) Görselsizler
  const noImg = items.filter((i) => !i.imageUrl).sort((a, b) => b.use - a.use);
  console.log(`\n══ GÖRSELSİZ: ${noImg.length}/${items.length} ══`);
  for (const i of noImg) {
    console.log(`  ${i.id} | ${i.name} | ${i.category} | kullanım:${i.use}`);
  }

  // 3) Hiç kullanılmayanlar (bilgi)
  const unused = items.filter((i) => i.use === 0);
  console.log(`\n══ HİÇ KULLANILMAYAN: ${unused.length} ══`);
  for (const i of unused) console.log(`  ${i.id} | ${i.name}`);
})().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
