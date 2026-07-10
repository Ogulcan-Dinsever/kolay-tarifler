// Malzeme kategorilerini enum adlarına normalize eder.
// Sorun: Firestore'da kategori değerleri Türkçe serbest metin (baharat, et, diger...)
// ama Ingredient.fromFirestore düz enum-adı eşleşmesi yapıyor; eşleşmeyen -> other.
// Bu script tüm docları geçerli 11 enum adından birine getirir.
//
// Kullanım:  node recategorize_ingredients.js          (dry-run)
//            node recategorize_ingredients.js --commit  (Firestore'a yaz)

const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();

const COMMIT = process.argv.includes('--commit');
const ENUM = ['vegetable','fruit','meat','seafood','dairy','grain','spice','oil','nut','egg','other'];

// Depolanan kategori (küçük harf) -> enum adı
const CAT_MAP = {
  sebze:'vegetable', yesillik:'vegetable', 'yeşillik':'vegetable',
  meyve:'fruit',
  et:'meat', tavuk:'meat',
  deniz:'seafood', 'deniz ürünleri':'seafood', 'deniz urunleri':'seafood', balik:'seafood', 'balık':'seafood',
  sut:'dairy', 'süt':'dairy', 'süt ürünleri':'dairy', 'sut urunleri':'dairy', peynir:'dairy',
  tahil:'grain', 'tahıl':'grain', bakliyat:'grain', baklagil:'grain', un:'grain', ekmek:'grain', yufka:'grain', 'hamur işi':'grain', 'hamur isi':'grain',
  baharat:'spice',
  yag:'oil', 'yağ':'oil', sos:'oil',
  kuruyemis:'nut', 'kuruyemiş':'nut',
  yumurta:'egg',
  sivi:'other', 'sıvı':'other', tatlandirici:'other', 'tatlandırıcı':'other', diger:'other', 'diğer':'other',
  // enum adları kendine
  vegetable:'vegetable', fruit:'fruit', meat:'meat', seafood:'seafood', dairy:'dairy',
  grain:'grain', spice:'spice', oil:'oil', nut:'nut', egg:'egg', other:'other',
};

// İsim bazlı kurtarma (diger/other kovasından). İsim eşleşmesi CAT_MAP'i ezer.
const NAME_OVERRIDE = {
  // seafood
  'Balık (Uskumru)':'seafood', 'Midye':'seafood',
  // meat
  'Dana Bonfile':'meat', 'Tavuk Eti':'meat', 'Paça':'meat', 'Mumbar (Bağırsak)':'meat',
  // vegetable
  'Semizotu':'vegetable', 'Kabak Çiçeği':'vegetable', 'Turşu':'vegetable',
  'Ispanak':'vegetable', 'Su Ispanağı':'vegetable',
  // nut
  'Fıstık Ezmesi':'nut',
  // dairy
  'Taze Peynir':'dairy', 'Vanilyalı Dondurma':'dairy',
  // grain
  'Bayat Ekmek':'grain', 'Dövme Buğday':'grain', 'Ekmek İçi':'grain', 'Kedi Dili Bisküvi':'grain',
  'Mochi (Pirinç Keki)':'grain', 'Mısır Nişastası':'grain', 'Tteok (Kore Pirinç Keki)':'grain',
  'Taze Bakla':'grain', 'Ekmek':'grain', 'Tam Buğday Unu':'grain', 'Kadayıf':'grain',
  // oil
  'Kızartmalık Yağ':'oil', 'Kuzu İç Yağı':'oil',
  // aromatic leaf -> other (açık tutulsun)
  'Pandan Yaprağı':'other',
};

(async () => {
  const snap = await db.collection('ingredients').get();
  const changes = [];
  const finalCat = {};
  const otherList = [];
  const unmapped = [];

  snap.forEach(d => {
    const data = d.data();
    const name = data.name || '';
    const cur = data.category || '';
    let next = NAME_OVERRIDE[name] || CAT_MAP[cur.toLowerCase().trim()];
    if (!next) { unmapped.push(`${d.id}\t${cur}\t${name}`); next = 'other'; }
    if (!ENUM.includes(next)) next = 'other';

    finalCat[next] = (finalCat[next] || 0) + 1;
    if (next === 'other') otherList.push(`${d.id}\t${name}`);
    if (next !== cur) changes.push({ id: d.id, name, from: cur, to: next });
  });

  console.log(`TOPLAM: ${snap.size}   DEĞİŞECEK: ${changes.length}`);
  console.log('\n=== YENİ DAĞILIM ===');
  for (const c of ENUM) console.log(`  ${c}: ${finalCat[c] || 0}`);
  if (unmapped.length) { console.log('\n=== HARİTASIZ (->other) ==='); unmapped.forEach(u => console.log(u)); }
  console.log(`\n=== KALAN OTHER (${otherList.length}) ===`);
  otherList.forEach(o => console.log(o));

  if (!COMMIT) {
    console.log('\n[DRY-RUN] Yazmak icin: node recategorize_ingredients.js --commit');
    process.exit(0);
  }

  let batch = db.batch(), n = 0, written = 0;
  for (const ch of changes) {
    batch.update(db.collection('ingredients').doc(ch.id), { category: ch.to });
    if (++n === 400) { await batch.commit(); written += n; batch = db.batch(); n = 0; }
  }
  if (n) { await batch.commit(); written += n; }
  console.log(`\n✅ ${written} malzeme guncellendi.`);
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
