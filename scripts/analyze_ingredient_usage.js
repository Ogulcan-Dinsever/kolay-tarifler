// Tariflerdeki malzeme kullanımını analiz eder:
// kategori bazında toplam geçiş sayısı + en çok kullanılan malzemeler.
// Kullanım: node analyze_ingredient_usage.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// lib/models/ingredient.dart parseCategory ile aynı eşleme
const TR_MAP = {
  sebze: 'vegetable', 'yeşillik': 'vegetable', yesillik: 'vegetable',
  meyve: 'fruit',
  et: 'meat', tavuk: 'meat', 'kırmızı et': 'meat', 'kirmizi et': 'meat',
  deniz: 'seafood', 'deniz ürünleri': 'seafood', 'deniz urunleri': 'seafood',
  'balık': 'seafood', balik: 'seafood',
  'süt': 'dairy', sut: 'dairy', 'süt ürünleri': 'dairy', 'sut urunleri': 'dairy', peynir: 'dairy',
  'tahıl': 'grain', tahil: 'grain', bakliyat: 'grain', baklagil: 'grain',
  un: 'grain', ekmek: 'grain', yufka: 'grain', 'hamur işi': 'grain', 'hamur isi': 'grain',
  baharat: 'spice', ot: 'spice', 'taze ot': 'spice',
  'yağ': 'oil', yag: 'oil', sos: 'oil',
  'kuruyemiş': 'nut', kuruyemis: 'nut',
  yumurta: 'egg',
  'sıvı': 'other', sivi: 'other', 'tatlandırıcı': 'other', tatlandirici: 'other',
  'diğer': 'other', diger: 'other',
};
const ENUM_NAMES = ['vegetable','fruit','meat','seafood','dairy','grain','spice','oil','nut','egg','other'];

function parseCategory(raw) {
  const key = (raw || '').trim().toLowerCase();
  if (!key) return 'other';
  if (ENUM_NAMES.includes(key)) return key;
  return TR_MAP[key] || 'other';
}

async function main() {
  const [ingSnap, recSnap] = await Promise.all([
    db.collection('ingredients').get(),
    db.collection('recipes').get(),
  ]);

  const ingCategory = {}; // id -> category
  const ingName = {};     // id -> name
  for (const doc of ingSnap.docs) {
    ingCategory[doc.id] = parseCategory(doc.data().category);
    ingName[doc.id] = doc.data().name || doc.id;
  }

  const catCount = {};    // category -> toplam geçiş
  const ingCount = {};    // ingredientId -> geçiş
  let recipeCount = 0;
  for (const doc of recSnap.docs) {
    const list = doc.data().ingredients;
    if (!Array.isArray(list)) continue;
    recipeCount++;
    for (const item of list) {
      const id = item && item.ingredientId;
      if (!id) continue;
      ingCount[id] = (ingCount[id] || 0) + 1;
      const cat = ingCategory[id] || 'other';
      catCount[cat] = (catCount[cat] || 0) + 1;
    }
  }

  console.log(`Tarif: ${recipeCount}, Malzeme: ${ingSnap.size}\n`);
  console.log('── Kategori kullanım sırası (çoktan aza) ──');
  const sorted = Object.entries(catCount).sort((a, b) => b[1] - a[1]);
  for (const [cat, n] of sorted) console.log(`${cat.padEnd(10)} ${n}`);

  console.log('\n── En çok kullanılan 25 malzeme ──');
  const topIng = Object.entries(ingCount).sort((a, b) => b[1] - a[1]).slice(0, 25);
  for (const [id, n] of topIng) {
    console.log(`${String(n).padStart(4)}  ${ingName[id]} (${ingCategory[id]})`);
  }
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
